-- Lua 5.4. Pure, local assessment of caller-supplied aggregate records.
-- Import: local c = require("cybermind.continuity_assessment")
-- Test explicitly: assert(c.self_test())
-- No I/O, external actions, dynamic loading, or recursive traversal.

local M = {}

local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

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

local function finite(value, path, minimum, maximum)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge
        or value < minimum
        or (maximum ~= nil and value > maximum) then
        fail("INVALID_NUMBER", path, "Expected a finite number in range")
    end
    return value
end

local function integer(value, path, minimum, maximum)
    finite(value, path, minimum, maximum)
    if value % 1 ~= 0 then
        fail("INVALID_INTEGER", path, "Expected an integer")
    end
    return value
end

local function text(value, path)
    if type(value) ~= "string"
        or #value > 4096
        or not value:match("%S")
        or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function choice(value, values, path)
    if type(value) ~= "string" or not values[value] then
        fail("INVALID_ENUM", path, "Value outside declared vocabulary")
    end
    return value
end

local function boolean(value, path)
    if type(value) ~= "boolean" then
        fail("INVALID_BOOLEAN", path, "Expected boolean")
    end
    return value
end

local function protect(operation)
    local ok, result = pcall(operation)
    if ok then return result end
    if type(result) == "table" and result.code then
        return nil, result
    end
    return nil, {
        code = "INTERNAL_ERROR",
        path = "module",
        message = "Unexpected internal failure"
    }
end

local WINDOW_FIELDS = {
    attempts = true, successes = true,
    timed_successes = true, success_seconds_total = true,
    effort_observations = true, effort_actions_total = true
}

local function window(input, path)
    fields(input, WINDOW_FIELDS, path)
    local result = {}

    result.attempts = integer(input.attempts, path .. ".attempts", 0, 1000000000)
    result.successes = integer(
        input.successes, path .. ".successes", 0, result.attempts
    )
    result.timed_successes = integer(
        input.timed_successes, path .. ".timed_successes",
        0, result.successes
    )
    result.success_seconds_total = finite(
        input.success_seconds_total, path .. ".success_seconds_total", 0
    )
    result.effort_observations = integer(
        input.effort_observations, path .. ".effort_observations",
        0, result.successes
    )
    result.effort_actions_total = integer(
        input.effort_actions_total, path .. ".effort_actions_total",
        0, 1000000000
    )

    if result.timed_successes == 0 and result.success_seconds_total ~= 0 then
        fail("INCONSISTENT_TOTAL", path,
            "Time total requires timed successful tasks")
    end
    if result.effort_observations == 0 and result.effort_actions_total ~= 0 then
        fail("INCONSISTENT_TOTAL", path,
            "Effort total requires observed successful tasks")
    end

    if result.attempts > 0 then
        result.success_rate = result.successes / result.attempts
    end
    if result.timed_successes > 0 then
        result.mean_success_seconds =
            result.success_seconds_total / result.timed_successes
    end
    if result.effort_observations > 0 then
        result.mean_effort_actions =
            result.effort_actions_total / result.effort_observations
    end
    return result
end

local function check(name, baseline, followup, maximum_increase, reverse)
    if baseline == nil or followup == nil then
        return {name = name, status = "insufficient_evidence"}
    end

    local change = followup - baseline
    local burden = reverse and -change or change
    return {
        name = name,
        baseline = baseline,
        followup = followup,
        change = change,
        allowed_deterioration = maximum_increase,
        status = burden <= maximum_increase
            and "within_agreed_limit" or "outside_agreed_limit"
    }
end

function M.assess(input)
    return protect(function()
        fields(input, {
            task = true, comparable = true, agreement_note = true,
            baseline = true, followup = true, limits = true,
            participant_report = true, privacy_condition = true
        }, "assessment")

        local task = text(input.task, "task")
        local comparable = boolean(input.comparable, "comparable")
        local agreement = text(input.agreement_note, "agreement_note")
        local baseline = window(input.baseline, "baseline")
        local followup = window(input.followup, "followup")

        fields(input.limits, {
            max_success_rate_drop = true,
            max_mean_seconds_increase = true,
            max_mean_effort_increase = true
        }, "limits")

        local drop = finite(
            input.limits.max_success_rate_drop,
            "limits.max_success_rate_drop", 0, 1
        )
        local delay = finite(
            input.limits.max_mean_seconds_increase,
            "limits.max_mean_seconds_increase", 0
        )
        local effort = finite(
            input.limits.max_mean_effort_increase,
            "limits.max_mean_effort_increase", 0
        )

        local report = choice(input.participant_report, {
            acceptable = true, concern = true,
            unknown = true, not_provided = true
        }, "participant_report")

        local privacy = choice(input.privacy_condition, {
            unchanged_acceptable = true,
            changed_acceptable = true,
            concern = true,
            unknown = true
        }, "privacy_condition")

        local result = {
            schema_version = "1.0.0",
            attribution = ATTRIBUTION,
            attribution_scope =
                "Credit and workstream metadata only; not identity, consent, "
                .. "authorization, execution evidence, or authority.",
            task = task,
            agreement_note = agreement,
            comparable = comparable,
            participant_report = report,
            privacy_condition = privacy,
            indicators = {},
            observed_performance = "insufficient_comparable_evidence",
            review_required = false,
            authorization = "none",
            eligibility_decision = "not_provided",
            continuity_guarantee = false
        }

        if comparable then
            result.indicators = {
                check("success_rate", baseline.success_rate,
                    followup.success_rate, drop, true),
                check("mean_success_seconds", baseline.mean_success_seconds,
                    followup.mean_success_seconds, delay, false),
                check("mean_effort_actions", baseline.mean_effort_actions,
                    followup.mean_effort_actions, effort, false)
            }

            local missing, outside = false, false
            for _, indicator in ipairs(result.indicators) do
                missing = missing
                    or indicator.status == "insufficient_evidence"
                outside = outside
                    or indicator.status == "outside_agreed_limit"
            end

            if outside then
                result.observed_performance = "outside_agreed_limits"
            elseif not missing then
                result.observed_performance = "within_agreed_limits"
            end
        end

        result.review_required =
            result.observed_performance ~= "within_agreed_limits"
            or report ~= "acceptable"
            or privacy == "concern"
            or privacy == "unknown"

        result.interpretation =
            "Descriptive aggregate comparison only; no causal attribution, "
            .. "statistical confidence, or validated continuity finding."
        return result
    end)
end

function M.dependency_profile(input)
    return protect(function()
        fields(input, {
            capability = true, consequence = true,
            substitutability = true, disruption_scenario = true,
            earliest_impact_hours = true, latest_impact_hours = true,
            disclosure_boundary = true, responsible_role = true
        }, "dependency")

        local result = {
            schema_version = "1.0.0",
            attribution = ATTRIBUTION,
            capability = text(input.capability, "capability"),
            consequence = text(input.consequence, "consequence"),
            disruption_scenario =
                text(input.disruption_scenario, "disruption_scenario"),
            substitutability = choice(input.substitutability, {
                unknown = true, untested = true,
                tested_acceptable = true,
                tested_unacceptable = true,
                unavailable = true
            }, "substitutability"),
            disclosure_boundary = choice(input.disclosure_boundary, {
                functional_only = true,
                limited_confidential = true,
                private_withheld = true
            }, "disclosure_boundary"),
            responsible_role = text(input.responsible_role, "responsible_role"),
            time_to_impact = "unknown",
            risk_score = "not_computed",
            eligibility_decision = "not_provided",
            authorization = "none"
        }

        local earliest = input.earliest_impact_hours
        local latest = input.latest_impact_hours

        if (earliest == nil) ~= (latest == nil) then
            fail("INCOMPLETE_INTERVAL", "time_to_impact",
                "Supply both interval endpoints or neither")
        end
        if earliest ~= nil then
            finite(earliest, "earliest_impact_hours", 0)
            finite(latest, "latest_impact_hours", earliest)
            result.time_to_impact = {
                earliest_hours = earliest,
                latest_hours = latest
            }
        end
        return result
    end)
end

function M.self_test()
    local input = {
        task = "Synthetic messaging task",
        comparable = true,
        agreement_note = "Synthetic fixture; not validated thresholds",
        baseline = {
            attempts = 10, successes = 9,
            timed_successes = 9, success_seconds_total = 90,
            effort_observations = 9, effort_actions_total = 9
        },
        followup = {
            attempts = 10, successes = 6,
            timed_successes = 6, success_seconds_total = 60,
            effort_observations = 6, effort_actions_total = 6
        },
        limits = {
            max_success_rate_drop = 0.1,
            max_mean_seconds_increase = 5,
            max_mean_effort_increase = 1
        },
        participant_report = "acceptable",
        privacy_condition = "unchanged_acceptable"
    }

    local result = assert(M.assess(input))
    assert(result.observed_performance == "outside_agreed_limits")
    assert(result.review_required)
    assert(result.continuity_guarantee == false)

    input.followup = input.baseline
    result = assert(M.assess(input))
    assert(result.observed_performance == "within_agreed_limits")
    assert(not result.review_required)

    input.participant_report = "concern"
    result = assert(M.assess(input))
    assert(result.review_required)

    input.comparable = false
    result = assert(M.assess(input))
    assert(result.observed_performance == "insufficient_comparable_evidence")

    input.baseline.attempts = 0
    local value, err = M.assess(input)
    assert(value == nil and err.code == "INVALID_NUMBER")

    local profile = assert(M.dependency_profile({
        capability = "Written participation",
        consequence = "Delayed participation",
        substitutability = "unknown",
        disruption_scenario = "Loss of remote service",
        disclosure_boundary = "private_withheld",
        responsible_role = "Continuity coordinator"
    }))
    assert(profile.time_to_impact == "unknown")
    assert(profile.risk_score == "not_computed")

    return true
end

return M
