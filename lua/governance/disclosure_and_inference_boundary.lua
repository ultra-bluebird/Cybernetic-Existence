-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only: not identity verification, consent,
-- capability authorization, or execution evidence.
--
-- Pure research module. No raw participant content is required.
-- No network, file, device, inference-model, or persistence operations.
-- Risk units are policy-accounting units, not probabilities or DP epsilon.

local M = {}

local MAX_ITEMS = 128
local MAX_TEXT = 96
local MAX_WEIGHT = 1000000

local function plain(value)
    assert(type(value) == "table"
        and getmetatable(value) == nil, "plain table required")
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

local function number(value)
    assert(type(value) == "number"
        and value == value
        and value >= 0
        and value <= MAX_WEIGHT, "invalid nonnegative weight")
    return value
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

local function set(array)
    local result = {}
    for i = 1, length(array) do
        local item = text(array[i])
        assert(not result[item], "duplicate feature")
        result[item] = true
    end
    return result
end

local function enum(value, allowed)
    assert(type(value) == "string" and allowed[value],
        "unrecognized enum")
end

local function model_check(model)
    plain(model)
    plain(model.weights)

    local count = 0
    for feature, weight in next, model.weights do
        count = count + 1
        assert(count <= MAX_ITEMS, "too many weighted features")
        text(feature)
        number(weight)
    end

    for i = 1, length(model.combinations) do
        local combination = model.combinations[i]
        plain(combination)
        assert(length(combination.features) >= 2,
            "combination requires at least two features")
        local members = set(combination.features)
        number(combination.penalty)

        for feature in next, members do
            assert(model.weights[feature] ~= nil,
                "combination contains unknown feature")
        end
    end
end

local function risk(features, model)
    local total = 0

    for feature in next, features do
        assert(model.weights[feature] ~= nil,
            "feature absent from risk model")
        total = total + model.weights[feature]
    end

    for i = 1, #model.combinations do
        local combination = model.combinations[i]
        local complete = true

        for j = 1, #combination.features do
            if not features[combination.features[j]] then
                complete = false
                break
            end
        end

        if complete then
            total = total + combination.penalty
        end
    end

    return total
end

function M.composed_risk(history_features, candidate_features, model)
    model_check(model)

    local history = set(history_features)
    local combined = {}

    for feature in next, history do
        combined[feature] = true
    end

    local candidate = set(candidate_features)
    for feature in next, candidate do
        combined[feature] = true
    end

    local before = risk(history, model)
    local after = risk(combined, model)

    return {
        before = before,
        after = after,
        increment = after - before,
        calibrated_probability = false,
        differential_privacy_guarantee = false
    }
end

local SENSITIVITY = {
    ordinary = true,
    sensitive = true,
    unknown = true
}

local EFFECT = {
    requested_assistance = true,
    adverse_decision = true,
    coercive_manipulation = true,
    unknown = true
}

local PERMISSION = {
    granted = true,
    absent = true,
    unknown = true
}

local EVIDENCE = {
    adequate = true,
    inadequate = true,
    unknown = true
}

function M.inference_decision(spec)
    plain(spec)
    enum(spec.sensitivity, SENSITIVITY)
    enum(spec.effect, EFFECT)
    enum(spec.permission, PERMISSION)
    enum(spec.evidence, EVIDENCE)

    local result = {
        tag = "inference_policy_assessment",
        decision = nil,
        reason = nil,
        automatic_execution_authorized = false,
        legal_validation_claimed = false
    }

    if spec.effect == "coercive_manipulation" then
        result.decision = "prohibited"
        result.reason = "coercive_purpose"
    elseif spec.sensitivity == "sensitive"
        and spec.effect == "adverse_decision" then
        result.decision = "prohibited"
        result.reason = "sensitive_inference_for_adverse_decision"
    elseif spec.permission == "absent" then
        result.decision = "prohibited"
        result.reason = "no_declared_permission"
    elseif spec.sensitivity == "unknown"
        or spec.effect == "unknown"
        or spec.permission == "unknown" then
        result.decision = "requires_review"
        result.reason = "unresolved_policy_fact"
    elseif spec.effect ~= "requested_assistance" then
        result.decision = "requires_review"
        result.reason = "purpose_outside_bounded_assistance_policy"
    elseif spec.evidence ~= "adequate" then
        result.decision = "requires_review"
        result.reason = "inference_adequacy_not_established"
    else
        result.decision = "within_declared_policy"
        result.reason = "bounded_requested_assistance"
    end

    return result
end

function M.select(history, candidates, model, ceiling, history_complete)
    set(history)
    model_check(model)
    number(ceiling)
    assert(type(history_complete) == "boolean",
        "explicit history completeness required")

    local n = length(candidates)

    if not history_complete then
        return {
            status = "history_review_required",
            automatic_disclosure_authorized = false
        }
    end

    local best, best_risk
    local labels = {}

    for i = 1, n do
        local candidate = candidates[i]
        plain(candidate)
        text(candidate.label)
        assert(not labels[candidate.label], "duplicate candidate label")
        labels[candidate.label] = true

        enum(candidate.adequacy, {
            adequate = true, inadequate = true, unknown = true
        })
        enum(candidate.authorization, {
            granted = true, absent = true, unknown = true
        })

        local inference = M.inference_decision(candidate.inference)
        local assessment =
            M.composed_risk(history, candidate.features, model)

        local eligible = candidate.adequacy == "adequate"
            and candidate.authorization == "granted"
            and inference.decision == "within_declared_policy"
            and assessment.after <= ceiling

        if eligible and (
            best_risk == nil
            or assessment.after < best_risk
            or (assessment.after == best_risk
                and candidate.label < best.label)
        ) then
            best = {
                label = candidate.label,
                risk_after = assessment.after,
                risk_increment = assessment.increment
            }
            best_risk = assessment.after
        end
    end

    return {
        status = best and "candidate_selected" or "no_eligible_candidate",
        candidate = best,
        automatic_disclosure_authorized = false,
        alternative_workflow_required_if_access_affected = true
    }
end

function M.self_test()
    local checks = 0
    local function expect(condition)
        assert(condition, "acceptance test failed")
        checks = checks + 1
    end

    local model = {
        weights = {
            accommodation = 1,
            provider = 1,
            schedule = 1
        },
        combinations = {{
            features = {"provider", "schedule"},
            penalty = 8
        }}
    }

    local result = M.composed_risk(
        {"provider"}, {"schedule"}, model
    )
    expect(result.before == 1)
    expect(result.after == 10)
    expect(result.increment == 9)

    local repeated = M.composed_risk(
        {"provider"}, {"provider"}, model
    )
    expect(repeated.increment == 0)

    local inference = {
        sensitivity = "sensitive",
        effect = "requested_assistance",
        permission = "granted",
        evidence = "adequate"
    }

    expect(M.inference_decision(inference).decision
        == "within_declared_policy")

    inference.effect = "adverse_decision"
    expect(M.inference_decision(inference).decision == "prohibited")
    inference.effect = "requested_assistance"

    local candidates = {
        {
            label = "minimal_access_statement",
            features = {"accommodation"},
            adequacy = "adequate",
            authorization = "granted",
            inference = inference
        },
        {
            label = "detailed_schedule_statement",
            features = {"schedule"},
            adequacy = "adequate",
            authorization = "granted",
            inference = inference
        }
    }

    local selected = M.select({"provider"}, candidates, model, 5, true)
    expect(selected.status == "candidate_selected")
    expect(selected.candidate.label == "minimal_access_statement")
    expect(not selected.automatic_disclosure_authorized)

    expect(M.select({"provider"}, candidates, model, 5, false).status
        == "history_review_required")

    inference.permission = "absent"
    expect(M.select({"provider"}, candidates, model, 5, true).status
        == "no_eligible_candidate")

    return {
        status = "passed",
        checks = checks,
        scope = "embedded synthetic tests only",
        empirical_privacy_validation = false
    }
end

return M
