-- Lua 5.4.
-- Pure local descriptive assessment.
-- No neural processing, message inspection, identity inference, or actions.
-- Import: local assessment = require("cybermind.transition_fidelity")
-- Tests: assert(assessment.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local TRI = {
    satisfied = true,
    not_satisfied = true,
    unknown = true
}
local ACCEPTABILITY = {
    acceptable = true,
    concern = true,
    not_provided = true,
    unknown = true
}
local DIRECTIONS = {higher = true, lower = true}

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

local function numeric(value, path, minimum, maximum, whole)
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
        fail("INVALID_ENUM", path, "Value outside declared vocabulary")
    end
    return value
end

local function length(value, path)
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
    if count > 256 then
        fail("LIMIT_EXCEEDED", path, "Too many criteria")
    end
    return count
end

local function ratio(numerator, denominator)
    local result = {
        numerator = numerator,
        denominator = denominator,
        status = denominator > 0 and "descriptive" or "not_estimable"
    }
    if denominator > 0 then result.value = numerator / denominator end
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

function M.transition(input)
    return protect(function()
        fields(input, {
            capability = true,
            protocol_note = true,
            agreement_status = true,
            participant_acceptability = true,
            safeguards = true,
            criteria = true
        }, "transition")

        text(input.capability, "capability")
        text(input.protocol_note, "protocol_note")
        local agreement = choice(input.agreement_status, {
            agreed = true, disputed = true,
            withdrawn = true, unknown = true
        }, "agreement_status")
        local acceptance = choice(input.participant_acceptability,
            ACCEPTABILITY, "participant_acceptability")

        fields(input.safeguards, {
            privacy = true,
            control = true,
            preservation = true,
            applicable_safety = true
        }, "safeguards")

        local result = M.metadata()
        result.safeguard_issues = {}
        result.criteria = {}
        result.measured_subset = "scope_not_established"
        result.participant_acceptability = acceptance
        result.participant_concern_reported = acceptance == "concern"
        result.additional_private_disclosure_required = false

        for _, name in ipairs({
            "privacy", "control", "preservation", "applicable_safety"
        }) do
            local value = choice(input.safeguards[name],
                TRI, "safeguards." .. name)
            if value ~= "satisfied" then
                result.safeguard_issues[#result.safeguard_issues + 1] = {
                    safeguard = name,
                    value = value
                }
            end
        end

        local count = length(input.criteria, "criteria")
        local seen, missing, exceeded = {}, false, false

        for position = 1, count do
            local source = input.criteria[position]
            local path = "criteria[" .. position .. "]"
            fields(source, {
                name = true, units = true, scale_note = true,
                direction = true, baseline = true, candidate = true,
                allowed_deterioration = true
            }, path)

            local name = text(source.name, path .. ".name")
            if seen[name] then
                fail("DUPLICATE_CRITERION", path, "Criterion name repeated")
            end
            seen[name] = true
            local units = text(source.units, path .. ".units")
            text(source.scale_note, path .. ".scale_note")
            local direction = choice(source.direction,
                DIRECTIONS, path .. ".direction")
            local margin = numeric(source.allowed_deterioration,
                path .. ".allowed_deterioration", 0, 1000000000000, false)

            if source.baseline ~= nil then
                numeric(source.baseline, path .. ".baseline",
                    -1000000000000, 1000000000000, false)
            end
            if source.candidate ~= nil then
                numeric(source.candidate, path .. ".candidate",
                    -1000000000000, 1000000000000, false)
            end

            local item = {name = name, units = units, status = "missing"}
            if source.baseline ~= nil and source.candidate ~= nil then
                item.change = source.candidate - source.baseline
                item.deterioration = direction == "higher"
                    and -item.change or item.change
                if agreement == "agreed" then
                    item.status = item.deterioration > margin
                        and "outside_margin" or "within_margin"
                    exceeded = exceeded or item.status == "outside_margin"
                else
                    item.status = "descriptive_only"
                end
            else
                missing = true
            end
            result.criteria[#result.criteria + 1] = item
        end

        if count > 0 then
            if agreement ~= "agreed" then
                result.measured_subset = "descriptive_only"
            elseif exceeded then
                result.measured_subset = "recorded_margin_exceedance"
            elseif missing then
                result.measured_subset = "incomplete_measurement"
            else
                result.measured_subset = "recorded_criteria_within_margins"
            end
        end

        result.transition_authorization = "not_provided"
        result.scope =
            "Declared criteria and supplied safeguard assertions only; "
            .. "not equivalence, consent, clinical safety, or authority."
        return result
    end)
end

function M.fidelity(input)
    return protect(function()
        fields(input, {
            protocol_note = true,
            attempted_message_episodes = true,
            candidate_message_episodes = true,
            approved_message_episodes = true,
            fidelity_reviewed_candidates = true,
            meaning_preserved_candidates = true,
            correction_actions_all_attempts = true
        }, "fidelity")

        text(input.protocol_note, "protocol_note")
        local attempted = numeric(input.attempted_message_episodes,
            "attempted_message_episodes", 0, 1000000000, true)
        local candidates = numeric(input.candidate_message_episodes,
            "candidate_message_episodes", 0, attempted, true)
        local approved = numeric(input.approved_message_episodes,
            "approved_message_episodes", 0, candidates, true)
        local reviewed = numeric(input.fidelity_reviewed_candidates,
            "fidelity_reviewed_candidates", 0, candidates, true)
        local preserved = numeric(input.meaning_preserved_candidates,
            "meaning_preserved_candidates", 0, reviewed, true)
        local corrections = numeric(input.correction_actions_all_attempts,
            "correction_actions_all_attempts", 0, 1000000000000, true)

        if attempted == 0 and corrections ~= 0 then
            fail("INCONSISTENT_TOTAL", "correction_actions_all_attempts",
                "Correction actions require attempted message episodes")
        end

        local result = M.metadata()
        result.preservation_among_reviewed = ratio(preserved, reviewed)
        result.fidelity_review_coverage = ratio(reviewed, candidates)
        result.approval_fraction = ratio(approved, candidates)
        result.corrections_per_attempt = ratio(corrections, attempted)
        result.scope =
            "Aggregate declared message-episode observations only; "
            .. "no private-intent inference, voluntariness finding, "
            .. "calibration, causal claim, or communication authorization."
        return result
    end)
end

function M.self_test()
    local input = {
        capability = "Written communication",
        protocol_note = "Synthetic matched-task fixture",
        agreement_status = "agreed",
        participant_acceptability = "not_provided",
        safeguards = {
            privacy = "satisfied",
            control = "satisfied",
            preservation = "satisfied",
            applicable_safety = "satisfied"
        },
        criteria = {
            {
                name = "Correction effort",
                units = "actions per attempted message",
                scale_note = "Synthetic action-count protocol",
                direction = "lower",
                baseline = 2,
                candidate = 4,
                allowed_deterioration = 1
            }
        }
    }

    local result = assert(M.transition(input))
    assert(result.measured_subset == "recorded_margin_exceedance")
    assert(not result.participant_concern_reported)
    assert(not result.additional_private_disclosure_required)

    input.criteria[1].candidate = 2
    result = assert(M.transition(input))
    assert(result.measured_subset == "recorded_criteria_within_margins")
    assert(result.transition_authorization == "not_provided")

    input.safeguards.privacy = "not_satisfied"
    result = assert(M.transition(input))
    assert(#result.safeguard_issues == 1)
    assert(result.measured_subset == "recorded_criteria_within_margins")

    local fidelity = assert(M.fidelity({
        protocol_note = "One designated reviewed candidate per episode",
        attempted_message_episodes = 10,
        candidate_message_episodes = 8,
        approved_message_episodes = 6,
        fidelity_reviewed_candidates = 4,
        meaning_preserved_candidates = 3,
        correction_actions_all_attempts = 20
    }))
    assert(fidelity.preservation_among_reviewed.value == 0.75)
    assert(fidelity.fidelity_review_coverage.value == 0.5)
    assert(fidelity.corrections_per_attempt.value == 2)

    return true
end

return M
