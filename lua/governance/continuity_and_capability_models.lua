-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Attribution is credit and metadata only, not identity verification,
-- consent, capability authority, or execution evidence.
--
-- Pure research models. No network, file, device, or persistence access.
-- Returned tables are mutable descriptions, not secure tokens.
-- Lua 5.1+.

local M = {}

local MAX_ITEMS = 1024
local MAX_TEXT = 128
local MAX_TIME = 1000000000000
local MAX_WEIGHT = 1000000

local function plain(value)
    assert(type(value) == "table"
        and getmetatable(value) == nil, "plain table required")
end

local function number(value, lower, upper)
    assert(type(value) == "number"
        and value == value
        and value >= lower
        and value <= upper, "number outside supported range")
    return value
end

local function text(value)
    assert(type(value) == "string"
        and #value > 0
        and #value <= MAX_TEXT
        and value:match("%S")
        and not value:find("[%z\1-\31\127]"),
        "bounded text required")
    return value
end

local function fields(record, allowed)
    plain(record)
    for key in next, record do
        assert(type(key) == "string" and allowed[key],
            "unrecognized field")
    end
end

local function length(array)
    plain(array)
    local count, maximum = 0, 0

    for key in next, array do
        count = count + 1
        assert(count <= MAX_ITEMS
            and type(key) == "number"
            and key >= 1
            and key <= MAX_ITEMS
            and key % 1 == 0, "invalid array")
        maximum = math.max(maximum, key)
    end

    assert(count == maximum, "array gaps prohibited")
    return count
end

local function string_set(array)
    local result = {}
    local n = length(array)
    assert(n > 0, "nonempty set required")

    for i = 1, n do
        local value = text(array[i])
        assert(not result[value], "duplicate set member")
        result[value] = true
    end

    return result
end

local function subset(child, parent)
    for item in next, child do
        if not parent[item] then
            return false
        end
    end
    return true
end

local function boolean(value)
    assert(type(value) == "boolean", "explicit boolean required")
end

local OBSERVATION_FIELDS = {
    start_time = true,
    end_time = true,
    effective = true,
    severity = true,
    substitute = true
}

function M.continuity(observations, weight)
    local n = length(observations)
    assert(n > 0, "observations required")
    number(weight, 0, MAX_WEIGHT)

    local available, unavailable, unknown = 0, 0, 0
    local severity_loss, substitute_seconds = 0, 0
    local outage_run, possible_run = 0, 0
    local maximum_outage, maximum_possible = 0, 0
    local outage_count = 0
    local previous_end, first_start

    for i = 1, n do
        local item = observations[i]
        fields(item, OBSERVATION_FIELDS)

        number(item.start_time, 0, MAX_TIME)
        number(item.end_time, 0, MAX_TIME)
        assert(item.end_time > item.start_time,
            "positive observation duration required")

        if previous_end ~= nil then
            assert(item.start_time == previous_end,
                "observations must be consecutive and gap-free")
        else
            first_start = item.start_time
        end
        previous_end = item.end_time

        assert(item.effective == "available"
            or item.effective == "unavailable"
            or item.effective == "unknown",
            "invalid effective-function state")

        boolean(item.substitute)
        number(item.severity, 0, 1)

        local duration = item.end_time - item.start_time

        if item.effective == "available" then
            available = available + duration
            outage_run, possible_run = 0, 0

            if item.substitute then
                substitute_seconds = substitute_seconds + duration
            end
        elseif item.effective == "unavailable" then
            unavailable = unavailable + duration

            if outage_run == 0 then
                outage_count = outage_count + 1
            end

            outage_run = outage_run + duration
            possible_run = possible_run + duration
            severity_loss = severity_loss
                + weight * item.severity * duration
        else
            unknown = unknown + duration
            outage_run = 0
            possible_run = possible_run + duration
        end

        maximum_outage = math.max(maximum_outage, outage_run)
        maximum_possible = math.max(maximum_possible, possible_run)
    end

    local total = previous_end - first_start

    return {
        tag = "function_continuity_assessment",
        duration_seconds = total,
        confirmed_availability = available / total,
        confirmed_unavailability = unavailable / total,
        unknown_fraction = unknown / total,
        maximum_confirmed_outage_seconds = maximum_outage,
        maximum_possible_outage_seconds = maximum_possible,
        confirmed_outage_runs = outage_count,
        criticality_weight = weight,
        confirmed_weighted_severity_seconds = severity_loss,
        upper_weighted_severity_seconds =
            severity_loss + weight * unknown,
        confirmed_effective_substitute_seconds = substitute_seconds,
        input_effectiveness_assertions_verified = false,
        physiological_safety_established = false
    }
end

local CAPABILITY_FIELDS = {
    purpose = true,
    actions = true,
    scopes = true,
    recipients = true,
    not_before = true,
    expires_at = true,
    delegable = true
}

local function capability(value)
    fields(value, CAPABILITY_FIELDS)
    text(value.purpose)
    number(value.not_before, 0, MAX_TIME)
    number(value.expires_at, 0, MAX_TIME)
    assert(value.not_before < value.expires_at,
        "nonempty capability interval required")
    boolean(value.delegable)

    return {
        actions = string_set(value.actions),
        scopes = string_set(value.scopes),
        recipients = string_set(value.recipients)
    }
end

function M.attenuation(parent, child)
    local p = capability(parent)
    local c = capability(child)
    local reasons = {}

    local function require_condition(condition, reason)
        if not condition then
            reasons[#reasons + 1] = reason
        end
    end

    require_condition(parent.delegable, "parent_not_delegable")
    require_condition(child.purpose == parent.purpose, "purpose_changed")
    require_condition(subset(c.actions, p.actions), "actions_expanded")
    require_condition(subset(c.scopes, p.scopes), "scope_expanded")
    require_condition(subset(c.recipients, p.recipients),
        "recipients_expanded")
    require_condition(child.not_before >= parent.not_before,
        "start_time_expanded")
    require_condition(child.expires_at <= parent.expires_at,
        "expiry_expanded")

    table.sort(reasons)

    return {
        tag = "attenuation_assessment",
        valid_description_attenuation = #reasons == 0,
        reasons = reasons,
        grant_authenticity_verified = false,
        parent_lineage_verified = false,
        automatic_execution_authorized = false
    }
end

local REQUEST_FIELDS = {
    purpose = true,
    action = true,
    scope = true,
    recipient = true
}

function M.match(cap, request, now, chain_status)
    local sets = capability(cap)
    fields(request, REQUEST_FIELDS)
    text(request.purpose)
    text(request.action)
    text(request.scope)
    text(request.recipient)
    number(now, 0, MAX_TIME)

    assert(chain_status == "active"
        or chain_status == "revoked"
        or chain_status == "unknown",
        "explicit chain status required")

    local matches = request.purpose == cap.purpose
        and sets.actions[request.action] == true
        and sets.scopes[request.scope] == true
        and sets.recipients[request.recipient] == true
        and cap.not_before <= now
        and now < cap.expires_at

    local status
    if chain_status == "revoked" then
        status = "revoked"
    elseif chain_status == "unknown" then
        status = "chain_review_required"
    elseif matches then
        status = "description_matches"
    else
        status = "description_does_not_match"
    end

    return {
        tag = "capability_match_assessment",
        status = status,
        chain_status_supplied_not_verified = true,
        rights_compliance_checked = false,
        prohibited_purpose_checked = false,
        automatic_execution_authorized = false
    }
end

function M.self_test()
    local checks = 0
    local function expect(condition)
        assert(condition, "acceptance test failed")
        checks = checks + 1
    end

    local assessment = M.continuity({
        {
            start_time = 0, end_time = 90,
            effective = "available", severity = 0, substitute = false
        },
        {
            start_time = 90, end_time = 95,
            effective = "unavailable", severity = 1, substitute = false
        },
        {
            start_time = 95, end_time = 100,
            effective = "unknown", severity = 0, substitute = true
        }
    }, 2)

    expect(assessment.confirmed_availability == 0.9)
    expect(assessment.maximum_confirmed_outage_seconds == 5)
    expect(assessment.maximum_possible_outage_seconds == 10)
    expect(assessment.confirmed_weighted_severity_seconds == 10)
    expect(assessment.upper_weighted_severity_seconds == 20)
    expect(assessment.confirmed_effective_substitute_seconds == 0)

    local parent = {
        purpose = "summarize",
        actions = {"read", "summarize"},
        scopes = {"supplied_note"},
        recipients = {"participant"},
        not_before = 0,
        expires_at = 100,
        delegable = true
    }

    local child = {
        purpose = "summarize",
        actions = {"summarize"},
        scopes = {"supplied_note"},
        recipients = {"participant"},
        not_before = 10,
        expires_at = 50,
        delegable = false
    }

    expect(M.attenuation(parent, child).valid_description_attenuation)

    child.purpose = "train_general_model"
    expect(not M.attenuation(parent, child).valid_description_attenuation)
    child.purpose = "summarize"

    local request = {
        purpose = "summarize",
        action = "summarize",
        scope = "supplied_note",
        recipient = "participant"
    }

    expect(M.match(child, request, 20, "active").status
        == "description_matches")
    expect(M.match(child, request, 50, "active").status
        == "description_does_not_match")
    expect(M.match(child, request, 20, "revoked").status == "revoked")
    expect(M.match(child, request, 20, "unknown").status
        == "chain_review_required")

    request.recipient = "employer"
    expect(M.match(child, request, 20, "active").status
        == "description_does_not_match")

    return {
        status = "passed",
        checks = checks,
        scope = "embedded synthetic tests only",
        formal_proof = false
    }
end

return M
