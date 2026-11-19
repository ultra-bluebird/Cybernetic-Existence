-- Lua 5.4. Pure local processing; no I/O or external actions.
-- Import: local c = require("cybermind.continuity_profile")
-- Tests: assert(c.self_test())
-- Aggregate observations only; never load untrusted input as Lua code.

local M = {}

local VERSION = "2.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local SCOPE =
    "Credit and workstream metadata only; not identity, consent, "
    .. "authorization, execution evidence, or authority over others."

local REPORTS = {
    acceptable = true, concern = true,
    unknown = true, not_provided = true
}
local AGREEMENTS = {
    agreed = true, disputed = true, withdrawn = true, unknown = true
}
local SUBSTITUTES = {
    unknown = true, untested = true, tested_acceptable = true,
    tested_unacceptable = true, unavailable = true
}
local BOUNDARIES = {
    functional_only = true,
    limited_confidential = true,
    private_withheld = true
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

local function text(value, path)
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function number(value, path, minimum, maximum, whole)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < minimum or value > maximum
        or (whole and value % 1 ~= 0) then
        fail("INVALID_NUMBER", path, "Number violates declared bounds")
    end
    return value
end

local function choice(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Unknown vocabulary value")
    end
    return value
end

local function boolean(value, path)
    if type(value) ~= "boolean" then
        fail("INVALID_BOOLEAN", path, "Expected boolean")
    end
    return value
end

local function protected(operation)
    local ok, result = pcall(operation)
    if ok then return result end
    if type(result) == "table" and type(result.code) == "string" then
        return nil, result
    end
    return nil, {
        code = "INTERNAL_ERROR", path = "module",
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

local function window(value, path, maximum_seconds, maximum_actions)
    fields(value, {
        attempts = true, successes = true,
        timed_attempts = true, seconds_total = true,
        effort_attempts = true, actions_total = true
    }, path)

    local attempts = number(value.attempts,
        path .. ".attempts", 0, 1000000000, true)
    local successes = number(value.successes,
        path .. ".successes", 0, attempts, true)
    local timed = number(value.timed_attempts,
        path .. ".timed_attempts", 0, attempts, true)
    local effort = number(value.effort_attempts,
        path .. ".effort_attempts", 0, attempts, true)
    local seconds = number(value.seconds_total,
        path .. ".seconds_total", 0, timed * maximum_seconds, false)
    local actions = number(value.actions_total,
        path .. ".actions_total", 0, effort * maximum_actions, true)

    local result = {
        attempts = attempts,
        successes = successes,
        time_complete = attempts > 0 and timed == attempts,
        effort_complete = attempts > 0 and effort == attempts
    }
    if attempts > 0 then
        result.failure_rate = (attempts - successes) / attempts
    end
    if result.time_complete then
        result.seconds_per_attempt = seconds / attempts
    end
    if result.effort_complete then
        result.actions_per_attempt = actions / attempts
    end
    return result
end

local function indicator(name, before, after, limit)
    local result = {name = name}
    if before == nil or after == nil then
        result.status = "missing"
        return result
    end
    result.baseline = before
    result.followup = after
    result.increase = after - before
    if limit == nil then
        result.status = "descriptive_only"
    else
        result.maximum_increase = limit
        result.status = result.increase > limit
            and "exceeded" or "within"
    end
    return result
end

local function assess(input)
    fields(input, {
        capability = true, comparable = true, protocol_note = true,
        agreement = true, contract = true,
        baseline = true, followup = true,
        participant_report = true, privacy_report = true,
        dependency = true, observation_horizon_hours = true
    }, "profile")

    local capability = text(input.capability, "capability")
    local comparable = boolean(input.comparable, "comparable")
    text(input.protocol_note, "protocol_note")

    fields(input.contract, {
        max_seconds_per_attempt = true,
        max_actions_per_attempt = true
    }, "contract")
    local max_seconds = number(input.contract.max_seconds_per_attempt,
        "contract.max_seconds_per_attempt", 0, 1000000000, false)
    local max_actions = number(input.contract.max_actions_per_attempt,
        "contract.max_actions_per_attempt", 0, 1000000000, true)

    fields(input.agreement, {
        status = true, participant_role = true,
        accountable_role = true, review_route = true,
        withdrawal_terms = true, limits = true
    }, "agreement")
    local agreement_status = choice(
        input.agreement.status, AGREEMENTS, "agreement.status"
    )
    text(input.agreement.participant_role, "agreement.participant_role")
    text(input.agreement.accountable_role, "agreement.accountable_role")
    text(input.agreement.review_route, "agreement.review_route")
    text(input.agreement.withdrawal_terms, "agreement.withdrawal_terms")

    local limits = {}
    if input.agreement.limits ~= nil then
        fields(input.agreement.limits, {
            failure_rate_increase = true,
            seconds_per_attempt_increase = true,
            actions_per_attempt_increase = true
        }, "agreement.limits")
        local source = input.agreement.limits
        limits.failure_rate_increase = number(
            source.failure_rate_increase,
            "agreement.limits.failure_rate_increase", 0, 1, false)
        limits.seconds_per_attempt_increase = number(
            source.seconds_per_attempt_increase,
            "agreement.limits.seconds_per_attempt_increase",
            0, 1000000000, false)
        limits.actions_per_attempt_increase = number(
            source.actions_per_attempt_increase,
            "agreement.limits.actions_per_attempt_increase",
            0, 1000000000, false)
    elseif agreement_status == "agreed" then
        fail("LIMITS_REQUIRED", "agreement.limits",
            "Agreed threshold comparison requires explicit limits")
    end

    local baseline = window(input.baseline, "baseline",
        max_seconds, max_actions)
    local followup = window(input.followup, "followup",
        max_seconds, max_actions)
    local participant = choice(input.participant_report,
        REPORTS, "participant_report")
    local privacy = choice(input.privacy_report,
        REPORTS, "privacy_report")

    fields(input.dependency, {
        capability = true, consequence = true,
        substitutability = true, disruption_scenario = true,
        disclosure_boundary = true, responsible_role = true,
        earliest_impact_hours = true, latest_impact_hours = true,
        estimate_basis = true, observation_note = true
    }, "dependency")
    local dependency = input.dependency
    if text(dependency.capability, "dependency.capability") ~= capability then
        fail("CAPABILITY_MISMATCH", "dependency.capability",
            "Dependency and observation must concern the same capability")
    end
    local consequence = text(dependency.consequence, "dependency.consequence")
    local substitute = choice(dependency.substitutability,
        SUBSTITUTES, "dependency.substitutability")
    local boundary = choice(dependency.disclosure_boundary,
        BOUNDARIES, "dependency.disclosure_boundary")
    local scenario = text(dependency.disruption_scenario,
        "dependency.disruption_scenario")
    local responsible = text(dependency.responsible_role,
        "dependency.responsible_role")
    local observation_note = text(dependency.observation_note,
        "dependency.observation_note")
    local horizon = number(input.observation_horizon_hours,
        "observation_horizon_hours", 0, 1000000000, false)

    local earliest, latest = dependency.earliest_impact_hours,
        dependency.latest_impact_hours
    local timing = "unknown"
    if (earliest == nil) ~= (latest == nil) then
        fail("INCOMPLETE_INTERVAL", "dependency",
            "Both impact interval endpoints are required")
    end
    if earliest ~= nil then
        number(earliest, "dependency.earliest_impact_hours",
            0, 1000000000, false)
        number(latest, "dependency.latest_impact_hours",
            0, 1000000000, false)
        if latest < earliest then
            fail("REVERSED_INTERVAL", "dependency",
                "Latest impact cannot precede earliest impact")
        end
        text(dependency.estimate_basis, "dependency.estimate_basis")
        timing = horizon >= latest
            and "horizon_reaches_latest_estimate"
            or "horizon_shorter_than_latest_estimate"
    elseif dependency.estimate_basis ~= nil then
        text(dependency.estimate_basis, "dependency.estimate_basis")
    end

    local result = M.metadata()
    result.capability = capability
    result.agreement_status = agreement_status
    result.indicators = {}
    result.review_reasons = {}
    result.information_notes = {}
    result.measured_subset = "descriptive_only"
    result.dependency_context = {
        consequence = consequence,
        substitutability = substitute,
        disclosure_boundary = boundary,
        disruption_scenario = scenario,
        responsible_role = responsible,
        observation_note = observation_note,
        timing_comparison = timing
    }

    local active_limits = agreement_status == "agreed" and comparable
    local function selected(value)
        if active_limits then return value end
        return nil
    end

    if comparable then
        result.indicators = {
            indicator("failure_rate",
                baseline.failure_rate, followup.failure_rate,
                selected(limits.failure_rate_increase)),
            indicator("seconds_per_attempt",
                baseline.seconds_per_attempt, followup.seconds_per_attempt,
                selected(limits.seconds_per_attempt_increase)),
            indicator("actions_per_attempt",
                baseline.actions_per_attempt, followup.actions_per_attempt,
                selected(limits.actions_per_attempt_increase))
        }
        if active_limits then
            local missing, exceeded = false, false
            for _, item in ipairs(result.indicators) do
                missing = missing or item.status == "missing"
                if item.status == "exceeded" then
                    exceeded = true
                    result.review_reasons[#result.review_reasons + 1] =
                        "recorded_limit_exceeded:" .. item.name
                end
            end
            result.measured_subset = exceeded and "recorded_limit_exceedance"
                or (missing and "incomplete_measurement"
                    or "recorded_indicators_within_limits")
        end
    else
        result.information_notes[#result.information_notes + 1] =
            "Comparison conditions not established"
    end

    if participant == "concern" then
        result.review_reasons[#result.review_reasons + 1] =
            "affirmative_participant_concern"
    elseif participant == "unknown" or participant == "not_provided" then
        result.information_notes[#result.information_notes + 1] =
            "Optional participant report absent; no additional disclosure duty"
    end

    if privacy == "concern" then
        result.review_reasons[#result.review_reasons + 1] =
            "affirmative_privacy_concern"
    elseif privacy == "unknown" or privacy == "not_provided" then
        result.information_notes[#result.information_notes + 1] =
            "Optional privacy report absent; acceptability not inferred"
    end

    result.review_requested = #result.review_reasons > 0
    result.scope =
        "Descriptive selected indicators plus dependency context; "
        .. "not a continuity guarantee, causal finding, or statistical test"
    result.collection_boundary =
        "Only declared aggregate fields accepted; free text is not "
        .. "automatically checked for sensitive content"
    return result
end

function M.composite_assessment(input)
    return protected(function() return assess(input) end)
end

local function fixture()
    return {
        capability = "Written participation",
        comparable = true,
        protocol_note = "Synthetic all-attempt fixture",
        agreement = {
            status = "agreed",
            participant_role = "Participant",
            accountable_role = "Service coordinator",
            review_route = "Independent written review",
            withdrawal_terms = "Threshold agreement may be withdrawn",
            limits = {
                failure_rate_increase = 0.1,
                seconds_per_attempt_increase = 5,
                actions_per_attempt_increase = 1
            }
        },
        contract = {
            max_seconds_per_attempt = 120,
            max_actions_per_attempt = 100
        },
        baseline = {
            attempts = 10, successes = 9, timed_attempts = 10,
            seconds_total = 200, effort_attempts = 10, actions_total = 20
        },
        followup = {
            attempts = 10, successes = 9, timed_attempts = 10,
            seconds_total = 200, effort_attempts = 10, actions_total = 20
        },
        participant_report = "acceptable",
        privacy_report = "acceptable",
        dependency = {
            capability = "Written participation",
            consequence = "Delayed civic participation",
            substitutability = "untested",
            disruption_scenario = "Loss of remote support",
            disclosure_boundary = "private_withheld",
            responsible_role = "Continuity coordinator",
            earliest_impact_hours = 2,
            latest_impact_hours = 8,
            estimate_basis = "Synthetic scenario assumption",
            observation_note = "Normal-use window, not disruption testing"
        },
        observation_horizon_hours = 4
    }
end

function M.self_test()
    local a = fixture()
    local first = assert(M.composite_assessment(a))
    local second = assert(M.composite_assessment(a))
    assert(first.measured_subset == second.measured_subset)
    assert(a.followup.seconds_total == 200)

    local absent = fixture()
    absent.participant_report = "not_provided"
    absent.privacy_report = "unknown"
    local neutral = assert(M.composite_assessment(absent))
    assert(not neutral.review_requested)

    local concern = fixture()
    concern.participant_report = "concern"
    assert(assert(M.composite_assessment(concern)).review_requested)

    local failure = fixture()
    failure.followup.successes = 6
    local worse = assert(M.composite_assessment(failure))
    assert(worse.review_requested)
    assert(worse.indicators[2].followup == 20)

    local incomplete = fixture()
    incomplete.followup.timed_attempts = 9
    incomplete.followup.seconds_total = 180
    local missing = assert(M.composite_assessment(incomplete))
    assert(missing.measured_subset == "incomplete_measurement")
    assert(not missing.review_requested)

    local disputed = fixture()
    disputed.agreement.status = "disputed"
    disputed.agreement.limits = nil
    assert(assert(M.composite_assessment(disputed)).measured_subset
        == "descriptive_only")

    local reversed = fixture()
    reversed.dependency.earliest_impact_hours = 9
    local value, err = M.composite_assessment(reversed)
    assert(value == nil and err.code == "REVERSED_INTERVAL")

    local partial = fixture()
    partial.dependency.latest_impact_hours = nil
    value, err = M.composite_assessment(partial)
    assert(value == nil and err.code == "INCOMPLETE_INTERVAL")

    local extra = fixture()
    extra.neural_recording = {}
    value, err = M.composite_assessment(extra)
    assert(value == nil and err.code == "UNKNOWN_FIELD")

    local changed = assert(M.composite_assessment(fixture()))
    changed.dependency_context.consequence = "Caller edit"
    assert(assert(M.composite_assessment(fixture()))
        .dependency_context.consequence == "Delayed civic participation")

    return true
end

return M
