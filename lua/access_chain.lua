-- Pure, local access-chain evaluation. No I/O, telemetry, or external actions.
-- Timestamps and maximum ages use the same caller-declared seconds scale.
local M = {}

local SUPPORTED = "supported"
local UNKNOWN = "unknown"
local NOT_SUPPORTED = "not_supported"

M.status = {
    supported = SUPPORTED,
    unknown = UNKNOWN,
    not_supported = NOT_SUPPORTED
}

local valid_status = {
    [SUPPORTED] = true,
    [UNKNOWN] = true,
    [NOT_SUPPORTED] = true
}

local function fail(message)
    error("access_chain: " .. message, 3)
end

local function finite_number(value, name)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge then
        fail(name .. " must be finite")
    end
end

local function nonnegative(value, name)
    finite_number(value, name)
    if value < 0 then
        fail(name .. " must be nonnegative")
    end
end

local function text(value, name)
    if type(value) ~= "string" or not value:match("%S") then
        fail(name .. " must be nonempty text")
    end
end

local function array_length(value, name)
    if type(value) ~= "table" then
        fail(name .. " must be a dense array")
    end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number"
            or key < 1
            or key % 1 ~= 0 then
            fail(name .. " must contain only positive integer keys")
        end
        count = count + 1
    end
    for i = 1, count do
        if rawget(value, i) == nil then
            fail(name .. " must not contain gaps")
        end
    end
    return count
end

function M.conjoin(left, right)
    if not valid_status[left] or not valid_status[right] then
        fail("conjoin requires recognized statuses")
    end
    if left == NOT_SUPPORTED or right == NOT_SUPPORTED then
        return NOT_SUPPORTED
    end
    if left == UNKNOWN or right == UNKNOWN then
        return UNKNOWN
    end
    return SUPPORTED
end

function M.evaluate_requirement(requirement, now)
    if type(requirement) ~= "table" then
        fail("requirement must be a table")
    end

    text(requirement.name, "requirement.name")
    text(requirement.policy_version, "requirement.policy_version")
    nonnegative(now, "now")
    nonnegative(requirement.max_age_seconds, "max_age_seconds")

    local count = array_length(requirement.evidence, "evidence")
    local supporting, opposing = 0, 0
    local stale, future = 0, 0

    for i = 1, count do
        local observation = requirement.evidence[i]
        if type(observation) ~= "table" then
            fail("each evidence entry must be a table")
        end
        if observation.claim ~= SUPPORTED
            and observation.claim ~= NOT_SUPPORTED then
            fail("evidence claim must be supported or not_supported")
        end

        text(observation.source, "evidence.source")
        nonnegative(observation.observed_at, "evidence.observed_at")

        local age = now - observation.observed_at
        if age < 0 then
            future = future + 1
        elseif age > requirement.max_age_seconds then
            stale = stale + 1
        elseif observation.claim == SUPPORTED then
            supporting = supporting + 1
        else
            opposing = opposing + 1
        end
    end

    local status, reason
    if supporting > 0 and opposing > 0 then
        status, reason = UNKNOWN, "conflicting_current_evidence"
    elseif opposing > 0 then
        status, reason = NOT_SUPPORTED, "current_opposing_evidence"
    elseif supporting > 0 then
        status, reason = SUPPORTED, "current_supporting_evidence"
    elseif count == 0 then
        status, reason = UNKNOWN, "missing_evidence"
    else
        status, reason = UNKNOWN, "no_current_evidence"
    end

    return {
        name = requirement.name,
        policy_version = requirement.policy_version,
        status = status,
        reason = reason,
        current_supporting = supporting,
        current_opposing = opposing,
        stale = stale,
        future = future
    }
end

function M.evaluate_journey(requirements, now)
    local count = array_length(requirements, "requirements")
    nonnegative(now, "now")

    local result = {
        status = count == 0 and UNKNOWN or SUPPORTED,
        reason = count == 0 and "empty_requirement_inventory"
            or "essential_requirement_conjunction",
        requirements = {},
        counts = {
            supported = 0,
            unknown = 0,
            not_supported = 0
        }
    }

    for i = 1, count do
        local evaluated = M.evaluate_requirement(requirements[i], now)
        result.requirements[i] = evaluated
        result.counts[evaluated.status] =
            result.counts[evaluated.status] + 1
        result.status = M.conjoin(result.status, evaluated.status)
    end

    return result
end

function M.self_test()
    local checks = 0
    local function check(condition)
        checks = checks + 1
        assert(condition, "access_chain self-test failed at check " .. checks)
    end

    local values = {SUPPORTED, UNKNOWN, NOT_SUPPORTED}
    local rank = {
        [NOT_SUPPORTED] = 1,
        [UNKNOWN] = 2,
        [SUPPORTED] = 3
    }

    for _, a in ipairs(values) do
        check(M.conjoin(a, a) == a)
        for _, b in ipairs(values) do
            local expected = rank[a] < rank[b] and a or b
            check(M.conjoin(a, b) == expected)
            check(M.conjoin(a, b) == M.conjoin(b, a))
            for _, c in ipairs(values) do
                check(
                    M.conjoin(M.conjoin(a, b), c)
                    == M.conjoin(a, M.conjoin(b, c))
                )
            end
        end
    end

    local function evidence(claim, observed_at)
        return {
            claim = claim,
            observed_at = observed_at,
            source = "fictional fixture"
        }
    end

    local function requirement(observations)
        return {
            name = "Fictional crossing requirement",
            policy_version = "research-policy",
            max_age_seconds = 10,
            evidence = observations
        }
    end

    local supported = requirement({evidence(SUPPORTED, 95)})
    local failed = requirement({evidence(NOT_SUPPORTED, 95)})
    local missing = requirement({})

    check(M.evaluate_requirement(supported, 100).status == SUPPORTED)
    check(M.evaluate_requirement(failed, 100).status == NOT_SUPPORTED)
    check(M.evaluate_requirement(missing, 100).status == UNKNOWN)
    check(M.evaluate_requirement(
        requirement({evidence(SUPPORTED, 89)}), 100
    ).status == UNKNOWN)
    check(M.evaluate_requirement(
        requirement({evidence(SUPPORTED, 90)}), 100
    ).status == SUPPORTED)
    check(M.evaluate_requirement(
        requirement({evidence(SUPPORTED, 101)}), 100
    ).status == UNKNOWN)
    check(M.evaluate_requirement(
        requirement({
            evidence(SUPPORTED, 95),
            evidence(NOT_SUPPORTED, 95)
        }), 100
    ).reason == "conflicting_current_evidence")

    check(M.evaluate_journey({}, 100).status == UNKNOWN)
    check(M.evaluate_journey({supported, missing}, 100).status == UNKNOWN)
    check(M.evaluate_journey({missing, failed}, 100).status == NOT_SUPPORTED)
    check(M.evaluate_journey({supported}, 100).status == SUPPORTED)

    local ok = pcall(function()
        M.evaluate_journey({[2] = supported}, 100)
    end)
    check(not ok)

    ok = pcall(function()
        M.evaluate_requirement({
            name = "Malformed fixture",
            policy_version = "research-policy",
            max_age_seconds = -1,
            evidence = {}
        }, 100)
    end)
    check(not ok)

    return {passed = true, checks = checks}
end

return M
