-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or execution authority.
--
-- Schema checker for a restricted prototype event vocabulary.
-- No network, file, device, persistence, or cryptographic operations.
-- Schema-valid records are not automatically safe public releases.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"

local FIELDS = {
    schema_version = true,
    event_type = true,
    process = true,
    actor_role = true,
    source_class = true
}

local ROLES = {
    interpretation_issued = {
        interpretation_owner = true
    },
    review_started = {
        reviewer = true
    },
    review_completed = {
        reviewer = true
    },
    correction_recorded = {
        correction_steward = true
    }
}

local SOURCES = {
    law = true,
    guidance = true,
    contract = true,
    project_policy = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function invalid(reason)
    return {
        status = "validation_error",
        implementation_version = VERSION,
        reason = reason
    }
end

function M.validate(record)
    if not plain(record) then
        return invalid("plain_record_required")
    end

    local count = 0
    for key in next, record do
        count = count + 1
        if count > 5 or not FIELDS[key] then
            return invalid("unknown_field")
        end
    end

    for field in pairs(FIELDS) do
        if rawget(record, field) == nil then
            return invalid("missing_field")
        end
        if type(record[field]) ~= "string" then
            return invalid("string_field_required")
        end
    end

    if record.schema_version ~= VERSION then
        return invalid("schema_version_mismatch")
    end

    local permitted_roles = ROLES[record.event_type]
    if not permitted_roles then
        return invalid("unknown_event_type")
    end

    if record.process ~= "interpretation_inspection" then
        return invalid("unsupported_process")
    end

    if not permitted_roles[record.actor_role] then
        return invalid("event_role_mismatch")
    end

    if not SOURCES[record.source_class] then
        return invalid("unknown_source_class")
    end

    return {
        status = "schema_valid",
        implementation_version = VERSION,
        record = {
            schema_version = record.schema_version,
            event_type = record.event_type,
            process = record.process,
            actor_role = record.actor_role,
            source_class = record.source_class
        }
    }
end

function M.self_test()
    local function fixture()
        return {
            schema_version = VERSION,
            event_type = "review_completed",
            process = "interpretation_inspection",
            actor_role = "reviewer",
            source_class = "project_policy"
        }
    end

    local source = fixture()
    local accepted = M.validate(source)
    assert(accepted.status == "schema_valid")

    accepted.record.actor_role = "changed"
    assert(source.actor_role == "reviewer")

    local private = fixture()
    private.private_description = "not accepted"
    assert(M.validate(private).reason == "unknown_field")

    local mismatch = fixture()
    mismatch.actor_role = "interpretation_owner"
    assert(M.validate(mismatch).reason == "event_role_mismatch")

    local missing = fixture()
    missing.source_class = nil
    assert(M.validate(missing).reason == "missing_field")

    local wrong_version = fixture()
    wrong_version.schema_version = "other"
    assert(M.validate(wrong_version).reason == "schema_version_mismatch")

    local fabricated_label = fixture()
    fabricated_label.source_class = "verified_citizen"
    assert(M.validate(fabricated_label).reason == "unknown_source_class")

    return {
        status = "self_checks_passed",
        scope = "synthetic_schema_and_role_pairing_cases"
    }
end

return M
