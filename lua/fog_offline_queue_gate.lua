local FogOfflineQueueGate = {}

local allowed_states = {
    RECEIVED = true,
    LOCAL_PENDING = true,
    HUMAN_REVIEW_REQUIRED = true,
    REVIEW_REMINDER_DUE = true,
    ESCALATED_REVIEW_REQUIRED = true,
    REVIEW_OVERDUE_RETAINED = true,
    REVIEW_COMPLETED = true,
    EXPIRED = true,
    SYNC_CONFLICT_REQUIRES_HUMAN_REVIEW = true
}

local function positive_integer(value, field)
    assert(type(value) == "number"
        and value % 1 == 0
        and value > 0,
        field .. " must be a positive integer")
end

function FogOfflineQueueGate.validate_policy(policy)
    assert(type(policy) == "table", "policy must be a table")

    positive_integer(policy.maximum_staleness_seconds,
        "maximum_staleness_seconds")

    assert(policy.advisory_only == true,
        "offline FOG policy must remain advisory_only")

    assert(policy.automatic_clear_allowed == false,
        "offline FOG policy must prohibit automatic clearing")

    assert(policy.delete_after_expiry == true,
        "offline FOG policy must require expiry deletion")

    return true
end

function FogOfflineQueueGate.evaluate(entry, now_utc, policy)
    FogOfflineQueueGate.validate_policy(policy)

    assert(type(entry) == "table", "entry must be a table")
    assert(type(entry.queue_id) == "string" and #entry.queue_id > 0,
        "queue_id is required")
    assert(allowed_states[entry.state] == true,
        "entry.state is invalid")

    positive_integer(entry.event_timestamp_utc,
        "event_timestamp_utc")
    positive_integer(now_utc, "now_utc")

    assert(now_utc >= entry.event_timestamp_utc,
        "now_utc must not precede event_timestamp_utc")

    local staleness = now_utc - entry.event_timestamp_utc
    local retained = staleness <= policy.maximum_staleness_seconds

    if not retained then
        return {
            queue_id = entry.queue_id,
            action = "EXPIRE_AND_DELETE_CONTENT",
            resulting_state = "EXPIRED",
            staleness_seconds = staleness,
            upload_allowed = false,
            automatic_clear_allowed = false,
            reason = "maximum_staleness_exceeded"
        }
    end

    return {
        queue_id = entry.queue_id,
        action = "RETAIN_FOR_POSSIBLE_SYNC",
        resulting_state = entry.state,
        staleness_seconds = staleness,
        upload_allowed = true,
        automatic_clear_allowed = false,
        reason = "within_retention_window"
    }
end

function FogOfflineQueueGate.resolve_conflict(local_entry, remote_entry)
    assert(type(local_entry) == "table", "local_entry must be a table")
    assert(type(remote_entry) == "table", "remote_entry must be a table")

    assert(local_entry.queue_id == remote_entry.queue_id,
        "only matching queue IDs can be compared")

    if local_entry.event_hash == remote_entry.event_hash then
        return {
            conflict = false,
            action = "NO_ACTION",
            resulting_state = local_entry.state
        }
    end

    return {
        conflict = true,
        action = "PRESERVE_BOTH_AND_REQUIRE_HUMAN_REVIEW",
        resulting_state = "SYNC_CONFLICT_REQUIRES_HUMAN_REVIEW"
    }
end

return FogOfflineQueueGate
