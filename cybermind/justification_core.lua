-- Lua 5.4. No I/O, external execution, persistence, or dynamic loading.
-- Import: local core = require("cybermind.justification_core")
-- Test explicitly: assert(core.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local SCOPE =
    "Credit and workstream metadata only; not identity, consent, "
    .. "authorization, execution evidence, or authority."

local VALUES = {
    satisfied = true,
    not_satisfied = true,
    unknown = true
}

local FAMILIES = {
    inference = {
        "purpose", "authorization", "minimization", "boundary", "retention"
    },
    restriction = {
        "purpose", "evidence", "necessity",
        "least_harm", "proportionality", "review_remedy"
    },
    emergency = {
        "specific_threat", "urgency", "authorized_role",
        "narrow_scope", "least_harm", "continuity_plan", "review_route"
    }
}

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function fields(value, allowed, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
    for key in next, value do
        if type(key) ~= "string" or not allowed[key] then
            fail("UNKNOWN_FIELD", path, "Unexpected field")
        end
    end
end

local function integer(value, path, minimum, maximum)
    if type(value) ~= "number" or math.type(value) ~= "integer"
        or value < minimum or value > maximum then
        fail("INVALID_INTEGER", path, "Integer outside permitted range")
    end
    return value
end

local function protect(operation)
    local ok, result = pcall(operation)
    if ok then return result end
    if type(result) == "table" and type(result.code) == "string" then
        return nil, result
    end
    return nil, {
        code = "INTERNAL_ERROR",
        path = "module",
        message = "Unexpected internal failure"
    }
end

function M.metadata()
    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope = SCOPE
    }
end

local function evaluate(family, conditions)
    local required = FAMILIES[family]
    if not required then
        fail("UNKNOWN_FAMILY", "family", "Unsupported evaluation family")
    end

    local allowed = {}
    for _, name in ipairs(required) do allowed[name] = true end
    fields(conditions, allowed, "conditions")

    local result = M.metadata()
    result.family = family
    result.unknown_conditions = {}
    result.unmet_conditions = {}
    result.value = "satisfied"

    for _, name in ipairs(required) do
        local value = conditions[name]
        if type(value) ~= "string" or not VALUES[value] then
            fail("INVALID_CONDITION", "conditions." .. name,
                "Expected satisfied, not_satisfied, or unknown")
        end
        if value == "unknown" then
            result.unknown_conditions[#result.unknown_conditions + 1] = name
        elseif value == "not_satisfied" then
            result.unmet_conditions[#result.unmet_conditions + 1] = name
        end
    end

    if #result.unmet_conditions > 0 then
        result.value = "not_satisfied"
    elseif #result.unknown_conditions > 0 then
        result.value = "unknown"
    end

    result.gate_satisfied = result.value == "satisfied"
    result.scope =
        "Evaluation of supplied assertions only; no evidence verification, "
        .. "execution, authentication, or authority conferred."
    return result
end

function M.evaluate(family, conditions)
    return protect(function() return evaluate(family, conditions) end)
end

function M.emergency(record, policy, now)
    return protect(function()
        fields(record, {
            conditions = true,
            start_time = true,
            expiry_time = true,
            review_due_time = true,
            policy_revision = true
        }, "emergency")
        fields(policy, {
            revision = true,
            maximum_duration = true,
            maximum_review_delay = true
        }, "policy")

        local revision = integer(policy.revision,
            "policy.revision", 0, math.maxinteger)
        local recorded_revision = integer(record.policy_revision,
            "emergency.policy_revision", 0, math.maxinteger)
        local duration = integer(policy.maximum_duration,
            "policy.maximum_duration", 1, math.maxinteger)
        local review_delay = integer(policy.maximum_review_delay,
            "policy.maximum_review_delay", 1, math.maxinteger)

        integer(now, "now", 0, math.maxinteger)
        local start = integer(record.start_time,
            "emergency.start_time", 0, math.maxinteger)
        local expiry = integer(record.expiry_time,
            "emergency.expiry_time", 0, math.maxinteger)
        local due = integer(record.review_due_time,
            "emergency.review_due_time", 0, math.maxinteger)

        if expiry <= start or expiry - start > duration then
            fail("INVALID_EXPIRY", "emergency.expiry_time",
                "Expiry must follow start within policy duration")
        end
        if due < start or due > expiry or due - start > review_delay then
            fail("INVALID_REVIEW_DEADLINE", "emergency.review_due_time",
                "Review must fall within the permitted interval")
        end

        local result = evaluate("emergency", record.conditions)
        result.policy_revision_matches = recorded_revision == revision
        result.expired = now >= expiry
        result.not_started = now < start
        result.review_due = now >= due
        result.current_record_eligible =
            result.gate_satisfied
            and result.policy_revision_matches
            and not result.expired
            and not result.not_started

        result.transition_required = result.expired
        result.renewal_automatic = false
        result.scope =
            "Assessment of an emergency record only; no intervention, "
            .. "restoration, renewal, or authority is executed."
        return result
    end)
end

function M.procedural_event(family, conditions, context)
    return protect(function()
        fields(context, {
            policy_revision = true,
            time = true,
            bucket_seconds = true
        }, "context")

        local revision = integer(context.policy_revision,
            "context.policy_revision", 0, math.maxinteger)
        local time = integer(context.time, "context.time", 0, math.maxinteger)
        local bucket = integer(context.bucket_seconds,
            "context.bucket_seconds", 1, 86400)
        local result = evaluate(family, conditions)
        local event = M.metadata()

        event.event_class = "justification_evaluated"
        event.family = family
        event.policy_revision = revision
        event.outcome = result.value
        event.unknown_count = #result.unknown_conditions
        event.unmet_count = #result.unmet_conditions
        event.time_bucket_start = time - (time % bucket)
        event.bucket_seconds = bucket
        event.integrity_status = "not_committed"
        return event
    end)
end

local function all_satisfied(family)
    local conditions = {}
    for _, name in ipairs(FAMILIES[family]) do
        conditions[name] = "satisfied"
    end
    return conditions
end

function M.self_test()
    local values = {"satisfied", "not_satisfied", "unknown"}
    local required = FAMILIES.inference

    -- Exhaust all 3^5 inference assignments without recursion.
    for assignment = 0, 242 do
        local remaining = assignment
        local conditions = {}
        local unmet, unknown = 0, 0

        for _, name in ipairs(required) do
            local value = values[(remaining % 3) + 1]
            remaining = remaining // 3
            conditions[name] = value
            if value == "not_satisfied" then unmet = unmet + 1 end
            if value == "unknown" then unknown = unknown + 1 end
        end

        local result = assert(M.evaluate("inference", conditions))
        local expected = unmet > 0 and "not_satisfied"
            or (unknown > 0 and "unknown" or "satisfied")
        assert(result.value == expected)
        assert(result.gate_satisfied == (expected == "satisfied"))
    end

    local conditions = all_satisfied("restriction")
    conditions.evidence = "unknown"
    assert(assert(M.evaluate("restriction", conditions)).value == "unknown")

    local record = {
        conditions = all_satisfied("emergency"),
        start_time = 10,
        expiry_time = 30,
        review_due_time = 20,
        policy_revision = 1
    }
    local policy = {
        revision = 1,
        maximum_duration = 20,
        maximum_review_delay = 10
    }

    assert(assert(M.emergency(record, policy, 15)).current_record_eligible)
    assert(assert(M.emergency(record, policy, 20)).review_due)
    assert(not assert(M.emergency(record, policy, 30)).current_record_eligible)
    assert(assert(M.emergency(record, policy, 30)).transition_required)

    policy.revision = 2
    assert(not assert(M.emergency(record, policy, 15)).current_record_eligible)

    local original = all_satisfied("inference")
    local event = assert(M.procedural_event("inference", original, {
        policy_revision = 1, time = 125, bucket_seconds = 60
    }))
    assert(event.time_bucket_start == 120)
    assert(event.unknown_conditions == nil)
    assert(event.integrity_status == "not_committed")
    assert(original.purpose == "satisfied")

    local value, err = M.evaluate("inference", {purpose = "satisfied"})
    assert(value == nil and err.code == "INVALID_CONDITION")

    return true
end

return M
