-- Lua 5.4.
-- Pure local analysis of supplied procedural records.
-- No I/O, case storage, publication, identity inference, or external actions.
-- Import: local outcomes = require("cybermind.feedback_outcomes")
-- Tests: assert(outcomes.self_test())
--
-- All timestamps use one caller-defined integer time unit.
-- The caller must supply a deduplicated, consistently scoped cohort.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local VERIFICATION = {
    confirmed = true,
    not_confirmed = true,
    unknown = true
}
local BENEFIT = {
    supports_benefit = true,
    does_not_support_benefit = true,
    uncertain = true,
    not_assessed = true
}
local TRI = {
    yes = true,
    no = true,
    unknown = true
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

local function time(value, path, maximum)
    if type(value) ~= "number" or math.type(value) ~= "integer"
        or value < 0 or value > maximum then
        fail("INVALID_TIME", path, "Expected nonnegative bounded integer")
    end
    return value
end

local function choice(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Unknown vocabulary value")
    end
    return value
end

local function array_length(value, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_ARRAY", path, "Expected a plain array")
    end
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number" or math.type(key) ~= "integer"
            or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        fail("SPARSE_ARRAY", path, "Array contains missing positions")
    end
    if count > 100000 then
        fail("LIMIT_EXCEEDED", path, "Cohort exceeds configured limit")
    end
    return count
end

local function ratio(numerator, denominator)
    local result = {
        numerator = numerator,
        denominator = denominator,
        status = denominator > 0 and "descriptive" or "not_estimable"
    }
    if denominator > 0 then
        result.value = numerator / denominator
    end
    return result
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
        attribution_scope =
            "Credit and workstream metadata only; not identity, consent, "
            .. "authorization, execution evidence, or authority."
    }
end

function M.dashboard(feedback, actions, cutoff)
    return protect(function()
        time(cutoff, "cutoff", math.maxinteger)
        local feedback_count = array_length(feedback, "feedback")
        local action_count = array_length(actions, "actions")

        local acknowledgements_due, on_time = 0, 0
        local disclosure_reviewed, unnecessary = 0, 0

        for position = 1, feedback_count do
            local row = feedback[position]
            local path = "feedback[" .. position .. "]"
            fields(row, {
                received_at = true,
                acknowledgement_due_at = true,
                acknowledged_at = true,
                disclosure_review = true
            }, path)

            local received = time(row.received_at,
                path .. ".received_at", cutoff)
            local due = time(row.acknowledgement_due_at,
                path .. ".acknowledgement_due_at", math.maxinteger)
            if due < received then
                fail("INVALID_ORDER", path,
                    "Acknowledgement deadline precedes receipt")
            end

            local acknowledged = row.acknowledged_at
            if acknowledged ~= nil then
                time(acknowledged, path .. ".acknowledged_at", cutoff)
                if acknowledged < received then
                    fail("INVALID_ORDER", path,
                        "Acknowledgement precedes receipt")
                end
            end

            if due <= cutoff then
                acknowledgements_due = acknowledgements_due + 1
                if acknowledged ~= nil and acknowledged <= due then
                    on_time = on_time + 1
                end
            end

            local review = choice(row.disclosure_review, {
                not_reviewed = true,
                no_unnecessary_request_found = true,
                unnecessary_request_found = true
            }, path .. ".disclosure_review")

            if review ~= "not_reviewed" then
                disclosure_reviewed = disclosure_reviewed + 1
            end
            if review == "unnecessary_request_found" then
                unnecessary = unnecessary + 1
            end
        end

        local due_actions, verified_due = 0, 0
        local completed, assessed_benefit, supported_benefit = 0, 0, 0

        for position = 1, action_count do
            local row = actions[position]
            local path = "actions[" .. position .. "]"
            fields(row, {
                accepted_at = true,
                original_due_at = true,
                completed_at = true,
                verification = true,
                benefit = true
            }, path)

            local accepted = time(row.accepted_at,
                path .. ".accepted_at", cutoff)
            local due = time(row.original_due_at,
                path .. ".original_due_at", math.maxinteger)
            if due < accepted then
                fail("INVALID_ORDER", path,
                    "Action deadline precedes acceptance")
            end

            local verification = choice(
                row.verification, VERIFICATION, path .. ".verification"
            )
            local benefit = choice(row.benefit, BENEFIT, path .. ".benefit")
            local finished = row.completed_at

            if finished ~= nil then
                time(finished, path .. ".completed_at", cutoff)
                if finished < accepted then
                    fail("INVALID_ORDER", path,
                        "Completion precedes acceptance")
                end
                completed = completed + 1
                if benefit ~= "not_assessed" then
                    assessed_benefit = assessed_benefit + 1
                end
                if benefit == "supports_benefit" then
                    supported_benefit = supported_benefit + 1
                end
            elseif verification ~= "unknown" or benefit ~= "not_assessed" then
                fail("INCONSISTENT_ACTION", path,
                    "Uncompleted action cannot carry completion verification "
                    .. "or completed-action benefit assessment")
            end

            if due <= cutoff then
                due_actions = due_actions + 1
                if finished ~= nil and verification == "confirmed" then
                    verified_due = verified_due + 1
                end
            end
        end

        local result = M.metadata()
        result.cutoff = cutoff
        result.acknowledgement_on_time = ratio(on_time, acknowledgements_due)
        result.verified_completion_of_due_actions =
            ratio(verified_due, due_actions)
        result.disclosure_review_coverage =
            ratio(disclosure_reviewed, feedback_count)
        result.unnecessary_disclosure_incidence_among_reviewed =
            ratio(unnecessary, disclosure_reviewed)
        result.benefit_assessment_coverage =
            ratio(assessed_benefit, completed)
        result.benefit_support_among_assessed =
            ratio(supported_benefit, assessed_benefit)
        result.scope =
            "Descriptive supplied-cohort counts only; no causal, trust, "
            .. "legal-compliance, deduplication, or population finding."
        return result
    end)
end

function M.retaliation_review(input)
    return protect(function()
        fields(input, {
            participant_report = true,
            access_change = true,
            decision_maker_awareness = true,
            procedural_departure = true,
            pressure_to_withdraw = true,
            independent_reviewer_available = true
        }, "review")

        local report = choice(input.participant_report, {
            concern = true,
            no_concern_reported = true,
            not_provided = true
        }, "participant_report")

        local access = choice(input.access_change, TRI, "access_change")
        local awareness = choice(input.decision_maker_awareness,
            TRI, "decision_maker_awareness")
        local departure = choice(input.procedural_departure,
            TRI, "procedural_departure")
        local pressure = choice(input.pressure_to_withdraw,
            TRI, "pressure_to_withdraw")

        if type(input.independent_reviewer_available) ~= "boolean" then
            fail("INVALID_BOOLEAN", "independent_reviewer_available",
                "Expected boolean")
        end

        local reasons = {}
        if report == "concern" then
            reasons[#reasons + 1] = "affirmative_participant_report"
        end
        if pressure == "yes" then
            reasons[#reasons + 1] = "reported_pressure_to_withdraw"
        end
        if access == "yes" and
            (awareness == "yes" or departure == "yes") then
            reasons[#reasons + 1] =
                "access_change_with_additional_review_indicator"
        end

        local result = M.metadata()
        result.review_recommended = #reasons > 0
        result.reasons = reasons
        result.finding = "not_determined"
        result.additional_private_disclosure_required = false

        if not result.review_recommended then
            result.route = "no_new_review_trigger_established"
        elseif input.independent_reviewer_available then
            result.route = "independent_review"
        else
            result.route = "independent_review_capacity_gap"
        end

        result.scope =
            "Review routing from supplied reports and assertions only; "
            .. "not a finding of retaliation or a legal burden-of-proof test."
        return result
    end)
end

function M.self_test()
    local feedback = {
        {
            received_at = 0,
            acknowledgement_due_at = 5,
            acknowledged_at = 4,
            disclosure_review = "no_unnecessary_request_found"
        },
        {
            received_at = 1,
            acknowledgement_due_at = 6,
            disclosure_review = "not_reviewed"
        }
    }
    local actions = {
        {
            accepted_at = 1,
            original_due_at = 7,
            completed_at = 6,
            verification = "confirmed",
            benefit = "supports_benefit"
        },
        {
            accepted_at = 2,
            original_due_at = 8,
            verification = "unknown",
            benefit = "not_assessed"
        }
    }

    local result = assert(M.dashboard(feedback, actions, 10))
    assert(result.acknowledgement_on_time.value == 0.5)
    assert(result.verified_completion_of_due_actions.value == 0.5)
    assert(result.disclosure_review_coverage.value == 0.5)
    assert(result.benefit_support_among_assessed.value == 1)

    local empty = assert(M.dashboard({}, {}, 0))
    assert(empty.acknowledgement_on_time.status == "not_estimable")
    assert(empty.acknowledgement_on_time.value == nil)

    local input = {
        participant_report = "not_provided",
        access_change = "unknown",
        decision_maker_awareness = "unknown",
        procedural_departure = "unknown",
        pressure_to_withdraw = "unknown",
        independent_reviewer_available = false
    }
    assert(not assert(M.retaliation_review(input)).review_recommended)

    input.participant_report = "concern"
    local routed = assert(M.retaliation_review(input))
    assert(routed.review_recommended)
    assert(routed.route == "independent_review_capacity_gap")
    assert(routed.finding == "not_determined")

    result.acknowledgement_on_time.value = 0
    assert(assert(M.dashboard(feedback, actions, 10))
        .acknowledgement_on_time.value == 0.5)

    return true
end

return M
