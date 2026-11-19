-- Lua 5.4. Pure local research and policy evaluation.
-- No network, file, device, persistence, or automatic disclosure operations.
-- Risk units are policy-accounting units, not probabilities or DP epsilon.

local M = {}

local VERSION = "2.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local SCOPE =
    "Credit and workstream metadata only; not identity verification, consent, "
    .. "capability authorization, execution evidence, or authority over others."

local MAX_ITEMS = 128
local MAX_TEXT = 4096
local MAX_FEATURE_TEXT = 96
local MAX_WEIGHT = 1000000
local MAX_GRANTS = 10000

local CATEGORIES = {
    functional_need = true,
    aggregate_performance = true,
    private_expression = true,
    integration_description = true,
    direct_measurement = true,
    derived_representation = true,
    mental_state_inference = true
}

local OPERATIONS = {
    collect = true,
    process = true,
    store = true,
    disclose = true,
    research_use = true
}

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

local POLICY_FIELDS = {
    revision = true,
    denied_categories = true,
    grants = true
}

local REQUEST_FIELDS = {
    expected_revision = true,
    operation = true,
    purpose = true,
    recipient = true,
    categories = true
}

local GRANT_FIELDS = {
    category = true,
    operation = true,
    purpose = true,
    recipient = true,
    valid_from = true,
    valid_until = true
}

local MODEL_FIELDS = {
    weights = true,
    combinations = true
}

local COMBINATION_FIELDS = {
    features = true,
    penalty = true
}

local INFERENCE_FIELDS = {
    sensitivity = true,
    effect = true,
    permission = true,
    evidence = true
}

local CANDIDATE_FIELDS = {
    label = true,
    features = true,
    adequacy = true,
    authorization = true,
    inference = true,
    disclosure_request = true
}

local function fail(code, path, message)
    error({
        code = code,
        path = path,
        message = message
    }, 0)
end

local function plain(value, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
end

local function fields(value, allowed, path)
    plain(value, path)
    for key in next, value do
        if type(key) ~= "string" or not allowed[key] then
            fail("UNKNOWN_FIELD", path, "Unexpected field")
        end
    end
end

local function text(value, path, maximum)
    if type(value) ~= "string"
        or #value > (maximum or MAX_TEXT)
        or not value:match("%S")
        or value:find("[%z\1-\31\127]") then
        fail("INVALID_TEXT", path,
            "Expected bounded nonblank text without control characters")
    end
    return value
end

local function nonnegative_integer(value, path)
    if type(value) ~= "number"
        or math.type(value) ~= "integer"
        or value < 0 then
        fail("INVALID_INTEGER", path, "Expected a nonnegative integer")
    end
    return value
end

local function weight(value, path)
    if type(value) ~= "number"
        or value ~= value
        or value < 0
        or value > MAX_WEIGHT then
        fail("INVALID_WEIGHT", path,
            "Expected a finite nonnegative policy weight within bounds")
    end
    return value
end

local function enumeration(value, allowed, path)
    if type(value) ~= "string" or not allowed[value] then
        fail("INVALID_ENUM", path, "Value outside declared vocabulary")
    end
    return value
end

local function array_length(value, path, limit)
    plain(value, path)
    local count, maximum = 0, 0

    for key in next, value do
        if type(key) ~= "number"
            or math.type(key) ~= "integer"
            or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end

        count = count + 1
        if count > limit then
            fail("LIMIT_EXCEEDED", path, "Collection limit exceeded")
        end
        maximum = math.max(maximum, key)
    end

    if count ~= maximum then
        fail("SPARSE_ARRAY", path, "Array contains missing positions")
    end

    return count
end

local function sorted_keys(value)
    local result = {}
    for key in next, value do
        result[#result + 1] = key
    end
    table.sort(result)
    return result
end

local function category_set(value, path)
    local count = array_length(value, path, 32)
    local result = {}

    for position = 1, count do
        local category = enumeration(
            value[position], CATEGORIES, path .. "[" .. position .. "]"
        )
        if result[category] then
            fail("DUPLICATE_CATEGORY", path,
                "Each category may appear only once")
        end
        result[category] = true
    end

    return result
end

local function feature_set(value, path)
    local count = array_length(value, path, MAX_ITEMS)
    local result = {}

    for position = 1, count do
        local feature = text(
            value[position], path .. "[" .. position .. "]", MAX_FEATURE_TEXT
        )
        if result[feature] then
            fail("DUPLICATE_FEATURE", path,
                "Each feature may appear only once")
        end
        result[feature] = true
    end

    return result
end

local function protected(operation)
    local ok, result = pcall(operation)
    if ok then
        return result
    end

    if type(result) == "table"
        and getmetatable(result) == nil
        and type(result.code) == "string"
        and type(result.path) == "string"
        and type(result.message) == "string" then
        return nil, result
    end

    return nil, {
        code = "INTERNAL_ERROR",
        path = "module",
        message = "Unexpected internal failure"
    }
end

local function metadata()
    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope = SCOPE
    }
end

function M.metadata()
    return metadata()
end

function M.parameters()
    return {
        max_items = MAX_ITEMS,
        max_text_bytes = MAX_TEXT,
        max_feature_text_bytes = MAX_FEATURE_TEXT,
        max_weight = MAX_WEIGHT,
        max_grants = MAX_GRANTS,
        categories = sorted_keys(CATEGORIES),
        operations = sorted_keys(OPERATIONS),
        sensitivity = sorted_keys(SENSITIVITY),
        effects = sorted_keys(EFFECT),
        permissions = sorted_keys(PERMISSION),
        evidence = sorted_keys(EVIDENCE),
        time_contract =
            "Nonnegative Lua integers in one shared caller-defined time unit",
        validity_interval = "valid_from <= now < valid_until"
    }
end

local function normalize_policy(policy)
    fields(policy, POLICY_FIELDS, "policy")

    local result = {
        revision = nonnegative_integer(policy.revision, "policy.revision"),
        denied = category_set(
            policy.denied_categories, "policy.denied_categories"
        ),
        grants = {}
    }

    local count = array_length(policy.grants, "policy.grants", MAX_GRANTS)
    for position = 1, count do
        local grant = policy.grants[position]
        local path = "policy.grants[" .. position .. "]"
        fields(grant, GRANT_FIELDS, path)

        local normalized = {
            category = enumeration(
                grant.category, CATEGORIES, path .. ".category"
            ),
            operation = enumeration(
                grant.operation, OPERATIONS, path .. ".operation"
            ),
            purpose = text(grant.purpose, path .. ".purpose"),
            recipient = text(grant.recipient, path .. ".recipient"),
            valid_from = nonnegative_integer(
                grant.valid_from, path .. ".valid_from"
            ),
            valid_until = nonnegative_integer(
                grant.valid_until, path .. ".valid_until"
            )
        }

        if normalized.valid_until <= normalized.valid_from then
            fail("INVALID_INTERVAL", path,
                "Validity interval must have positive duration")
        end

        result.grants[#result.grants + 1] = normalized
    end

    return result
end

local function normalize_request(request, path)
    path = path or "request"
    fields(request, REQUEST_FIELDS, path)

    return {
        expected_revision = nonnegative_integer(
            request.expected_revision, path .. ".expected_revision"
        ),
        operation = enumeration(
            request.operation, OPERATIONS, path .. ".operation"
        ),
        purpose = text(request.purpose, path .. ".purpose"),
        recipient = text(request.recipient, path .. ".recipient"),
        categories = category_set(request.categories, path .. ".categories")
    }
end

local function check_normalized(policy, request, now)
    local permitted = {}

    for _, grant in ipairs(policy.grants) do
        if grant.operation == request.operation
            and grant.purpose == request.purpose
            and grant.recipient == request.recipient
            and now >= grant.valid_from
            and now < grant.valid_until then
            permitted[grant.category] = true
        end
    end

    local result = metadata()
    result.policy_revision = policy.revision
    result.expected_revision = request.expected_revision
    result.operation = request.operation
    result.purpose = request.purpose
    result.recipient = request.recipient
    result.categories = sorted_keys(request.categories)
    result.blocked_categories = {}
    result.checked_at = now
    result.allowed = false
    result.reason = "missing_permission"

    if request.expected_revision ~= policy.revision then
        result.reason = "policy_revision_mismatch"
    elseif #result.categories == 0 then
        result.reason = "empty_category_declaration"
    else
        for _, category in ipairs(result.categories) do
            if policy.denied[category] or not permitted[category] then
                result.blocked_categories[
                    #result.blocked_categories + 1
                ] = category
            end
        end

        if #result.blocked_categories == 0 then
            result.allowed = true
            result.reason = "declared_use_matches_policy"
        end
    end

    result.automatic_execution_authorized = false
    result.scope =
        "Declared use under supplied policy only; no execution, identity "
        .. "authentication, payload classification, policy authenticity, "
        .. "or scientific-validity finding."

    return result
end

function M.check(policy, request, now)
    return protected(function()
        local normalized_policy = normalize_policy(policy)
        local normalized_request = normalize_request(request)
        nonnegative_integer(now, "now")
        return check_normalized(
            normalized_policy, normalized_request, now
        )
    end)
end

local function normalize_model(model)
    fields(model, MODEL_FIELDS, "model")
    plain(model.weights, "model.weights")

    local result = {weights = {}, combinations = {}}
    local count = 0

    for feature, value in next, model.weights do
        count = count + 1
        if count > MAX_ITEMS then
            fail("LIMIT_EXCEEDED", "model.weights",
                "Too many weighted features")
        end
        text(feature, "model.weights", MAX_FEATURE_TEXT)
        result.weights[feature] = weight(value, "model.weights")
    end

    local combinations = array_length(
        model.combinations, "model.combinations", MAX_ITEMS
    )
    local seen = {}

    for position = 1, combinations do
        local combination = model.combinations[position]
        local path = "model.combinations[" .. position .. "]"
        fields(combination, COMBINATION_FIELDS, path)

        local members = feature_set(
            combination.features, path .. ".features"
        )
        local names = sorted_keys(members)
        if #names < 2 then
            fail("INVALID_COMBINATION", path,
                "Combination requires at least two distinct features")
        end

        for _, feature in ipairs(names) do
            if result.weights[feature] == nil then
                fail("UNKNOWN_FEATURE", path .. ".features",
                    "Combination feature is absent from model weights")
            end
        end

        local signature = table.concat(names, "\0")
        if seen[signature] then
            fail("DUPLICATE_COMBINATION", path,
                "Combine repeated feature-set penalties explicitly")
        end
        seen[signature] = true

        result.combinations[#result.combinations + 1] = {
            features = names,
            penalty = weight(combination.penalty, path .. ".penalty"),
            signature = signature
        }
    end

    table.sort(result.combinations, function(left, right)
        return left.signature < right.signature
    end)

    return result
end

local function calculate_risk(features, model)
    local total = 0

    for _, feature in ipairs(sorted_keys(features)) do
        local value = model.weights[feature]
        if value == nil then
            fail("UNKNOWN_FEATURE", "features",
                "Feature is absent from model weights")
        end
        total = total + value
    end

    for _, combination in ipairs(model.combinations) do
        local complete = true
        for _, feature in ipairs(combination.features) do
            if not features[feature] then
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

local function composed_risk(history, candidate, model)
    local combined = {}

    for feature in next, history do
        combined[feature] = true
    end
    for feature in next, candidate do
        combined[feature] = true
    end

    local before = calculate_risk(history, model)
    local after = calculate_risk(combined, model)
    local result = metadata()
    result.before = before
    result.after = after
    result.increment = after - before
    result.calibrated_probability = false
    result.differential_privacy_guarantee = false
    result.scope =
        "Set-based policy accounting; repeated observations of the same "
        .. "feature are not modeled as additional exposure."
    return result
end

function M.composed_risk(history_features, candidate_features, model)
    return protected(function()
        local normalized_model = normalize_model(model)
        local history = feature_set(history_features, "history_features")
        local candidate = feature_set(candidate_features, "candidate_features")
        return composed_risk(history, candidate, normalized_model)
    end)
end

local function inference_decision(spec, path)
    path = path or "inference"
    fields(spec, INFERENCE_FIELDS, path)
    enumeration(spec.sensitivity, SENSITIVITY, path .. ".sensitivity")
    enumeration(spec.effect, EFFECT, path .. ".effect")
    enumeration(spec.permission, PERMISSION, path .. ".permission")
    enumeration(spec.evidence, EVIDENCE, path .. ".evidence")

    local result = metadata()
    result.tag = "inference_policy_assessment"
    result.automatic_execution_authorized = false
    result.legal_validation_claimed = false

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

function M.inference_decision(spec)
    return protected(function()
        return inference_decision(spec)
    end)
end

local function select_candidates(
    history_features, candidates, model, ceiling,
    history_complete, policy, now
)
    local history = feature_set(history_features, "history")
    local normalized_model = normalize_model(model)
    weight(ceiling, "ceiling")

    if type(history_complete) ~= "boolean" then
        fail("INVALID_BOOLEAN", "history_complete",
            "Explicit history completeness is required")
    end

    local count = array_length(candidates, "candidates", MAX_ITEMS)
    local normalized_policy
    if policy ~= nil then
        normalized_policy = normalize_policy(policy)
        nonnegative_integer(now, "now")
    end

    local before = calculate_risk(history, normalized_model)
    local labels, evaluated = {}, {}
    local best, best_risk

    for position = 1, count do
        local candidate = candidates[position]
        local path = "candidates[" .. position .. "]"
        fields(candidate, CANDIDATE_FIELDS, path)

        local label = text(candidate.label, path .. ".label", MAX_FEATURE_TEXT)
        if labels[label] then
            fail("DUPLICATE_LABEL", path .. ".label",
                "Candidate labels must be unique")
        end
        labels[label] = true

        enumeration(candidate.adequacy, EVIDENCE, path .. ".adequacy")
        enumeration(candidate.authorization, PERMISSION,
            path .. ".authorization")

        local inference = inference_decision(
            candidate.inference, path .. ".inference"
        )
        local features = feature_set(candidate.features, path .. ".features")
        local assessment = composed_risk(
            history, features, normalized_model
        )

        local request
        if candidate.disclosure_request ~= nil then
            request = normalize_request(
                candidate.disclosure_request, path .. ".disclosure_request"
            )
        end

        local disclosure
        if normalized_policy and request then
            disclosure = check_normalized(normalized_policy, request, now)
        end

        local reasons = {}
        if candidate.adequacy ~= "adequate" then
            reasons[#reasons + 1] = "adequacy_not_established"
        end
        if candidate.authorization ~= "granted" then
            reasons[#reasons + 1] = "declared_authorization_not_granted"
        end
        if inference.decision ~= "within_declared_policy" then
            reasons[#reasons + 1] = inference.reason
        end
        if assessment.after > ceiling then
            reasons[#reasons + 1] = "risk_ceiling_exceeded"
        end
        if normalized_policy then
            if not request then
                reasons[#reasons + 1] = "disclosure_request_required"
            elseif not disclosure.allowed then
                reasons[#reasons + 1] = disclosure.reason
            end
        elseif request then
            reasons[#reasons + 1] = "disclosure_policy_required"
        end

        local eligible = #reasons == 0
        evaluated[#evaluated + 1] = {
            label = label,
            eligible_under_declared_checks = eligible,
            reasons = reasons,
            risk_after = assessment.after,
            risk_increment = assessment.increment,
            inference_decision = inference.decision,
            disclosure_check = disclosure
        }

        if eligible and (
            best_risk == nil
            or assessment.after < best_risk
            or (assessment.after == best_risk and label < best.label)
        ) then
            best = {
                label = label,
                risk_after = assessment.after,
                risk_increment = assessment.increment
            }
            best_risk = assessment.after
        end
    end

    table.sort(evaluated, function(left, right)
        return left.label < right.label
    end)

    local result = metadata()
    result.automatic_disclosure_authorized = false
    result.alternative_workflow_required_if_access_affected = true
    result.policy_bound = normalized_policy ~= nil
    result.history_risk = before
    result.ceiling = ceiling
    result.evaluations = evaluated

    if not history_complete then
        result.status = "history_review_required"
        result.candidate = nil
    else
        result.status = best and "candidate_selected" or "no_eligible_candidate"
        result.candidate = best
    end

    result.scope =
        "Advisory selection among declared candidates only; authorization "
        .. "assertions, feature labels, adequacy, and history completeness "
        .. "are not independently verified."
    return result
end

function M.select(history, candidates, model, ceiling, history_complete)
    return protected(function()
        return select_candidates(
            history, candidates, model, ceiling, history_complete
        )
    end)
end

function M.select_with_policy(
    history, candidates, model, ceiling, history_complete, policy, now
)
    return protected(function()
        if policy == nil then
            fail("POLICY_REQUIRED", "policy",
                "Policy-bound selection requires an explicit policy")
        end
        return select_candidates(
            history, candidates, model, ceiling,
            history_complete, policy, now
        )
    end)
end

local function policy_fixture()
    return {
        revision = 1,
        denied_categories = {"mental_state_inference"},
        grants = {
            {
                category = "functional_need",
                operation = "process",
                purpose = "communication_access",
                recipient = "local_access_service",
                valid_from = 0,
                valid_until = 100
            }
        }
    }, {
        expected_revision = 1,
        operation = "process",
        purpose = "communication_access",
        recipient = "local_access_service",
        categories = {"functional_need"}
    }
end

local function research_fixture()
    return {
        weights = {
            accommodation = 1,
            provider = 1,
            schedule = 1
        },
        combinations = {
            {
                features = {"provider", "schedule"},
                penalty = 8
            }
        }
    }, {
        {
            label = "minimal_access_statement",
            features = {"accommodation"},
            adequacy = "adequate",
            authorization = "granted",
            inference = {
                sensitivity = "sensitive",
                effect = "requested_assistance",
                permission = "granted",
                evidence = "adequate"
            }
        },
        {
            label = "detailed_schedule_statement",
            features = {"schedule"},
            adequacy = "adequate",
            authorization = "granted",
            inference = {
                sensitivity = "sensitive",
                effect = "requested_assistance",
                permission = "granted",
                evidence = "adequate"
            }
        }
    }
end

function M.self_test()
    local checks = 0
    local function expect(condition)
        if not condition then
            fail("SELF_TEST_FAILURE", "self_test",
                "Embedded acceptance condition failed")
        end
        checks = checks + 1
    end

    local policy, request = policy_fixture()
    expect(assert(M.check(policy, request, 0)).allowed)
    expect(assert(M.check(policy, request, 50)).allowed)
    expect(not assert(M.check(policy, request, 100)).allowed)

    policy, request = policy_fixture()
    request.purpose = "research"
    expect(not assert(M.check(policy, request, 50)).allowed)

    policy, request = policy_fixture()
    request.recipient = "another_service"
    expect(not assert(M.check(policy, request, 50)).allowed)

    policy, request = policy_fixture()
    request.expected_revision = 0
    expect(assert(M.check(policy, request, 50)).reason
        == "policy_revision_mismatch")

    policy, request = policy_fixture()
    request.categories = {}
    expect(assert(M.check(policy, request, 50)).reason
        == "empty_category_declaration")

    policy, request = policy_fixture()
    policy.denied_categories = {"functional_need"}
    expect(not assert(M.check(policy, request, 50)).allowed)

    policy, request = policy_fixture()
    local decision = assert(M.check(policy, request, 50))
    decision.categories[1] = "Caller edit"
    expect(request.categories[1] == "functional_need")
    expect(assert(M.check(policy, request, 50)).allowed)

    policy, request = policy_fixture()
    request.neural_recording = {}
    local value, err = M.check(policy, request, 50)
    expect(value == nil and err.code == "UNKNOWN_FIELD")

    policy, request = policy_fixture()
    policy.grants[1].valid_until = 0
    value, err = M.check(policy, request, 50)
    expect(value == nil and err.code == "INVALID_INTERVAL")

    policy, request = policy_fixture()
    request.categories = {[2] = "functional_need"}
    value, err = M.check(policy, request, 50)
    expect(value == nil and err.code == "SPARSE_ARRAY")

    local model, candidates = research_fixture()
    local risk = assert(M.composed_risk({"provider"}, {"schedule"}, model))
    expect(risk.before == 1)
    expect(risk.after == 10)
    expect(risk.increment == 9)

    risk = assert(M.composed_risk({"provider"}, {"provider"}, model))
    expect(risk.increment == 0)

    local selection = assert(M.select(
        {"provider"}, candidates, model, 5, true
    ))
    expect(selection.status == "candidate_selected")
    expect(selection.candidate.label == "minimal_access_statement")
    expect(not selection.automatic_disclosure_authorized)

    selection = assert(M.select({"provider"}, candidates, model, 5, false))
    expect(selection.status == "history_review_required")
    expect(selection.candidate == nil)

    local inference = {
        sensitivity = "sensitive",
        effect = "adverse_decision",
        permission = "granted",
        evidence = "adequate"
    }
    expect(assert(M.inference_decision(inference)).decision == "prohibited")
    inference.effect = "coercive_manipulation"
    expect(assert(M.inference_decision(inference)).decision == "prohibited")
    inference.effect = "requested_assistance"
    inference.permission = "unknown"
    expect(assert(M.inference_decision(inference)).decision
        == "requires_review")
    inference.permission = "absent"
    expect(assert(M.inference_decision(inference)).decision == "prohibited")

    model, candidates = research_fixture()
    policy, request = policy_fixture()
    candidates[1].disclosure_request = request
    selection = assert(M.select_with_policy(
        {"provider"}, candidates, model, 5, true, policy, 50
    ))
    expect(selection.status == "candidate_selected")
    expect(selection.policy_bound)
    expect(selection.candidate.label == "minimal_access_statement")

    selection = assert(M.select_with_policy(
        {"provider"}, candidates, model, 5, true, policy, 100
    ))
    expect(selection.status == "no_eligible_candidate")

    selection = assert(M.select(
        {"provider"}, candidates, model, 5, true
    ))
    expect(selection.status == "no_eligible_candidate")

    model, candidates = research_fixture()
    candidates[2].label = candidates[1].label
    value, err = M.select({}, candidates, model, 5, true)
    expect(value == nil and err.code == "DUPLICATE_LABEL")

    model = research_fixture()
    model.combinations[2] = {
        features = {"schedule", "provider"},
        penalty = 1
    }
    value, err = M.composed_risk({}, {}, model)
    expect(value == nil and err.code == "DUPLICATE_COMBINATION")

    model = research_fixture()
    value, err = M.composed_risk({}, {"unmodeled"}, model)
    expect(value == nil and err.code == "UNKNOWN_FEATURE")

    model, candidates = research_fixture()
    local first = assert(M.select({}, candidates, model, 5, true))
    local second = assert(M.select({}, candidates, model, 5, true))
    expect(first.candidate.label == second.candidate.label)
    expect(candidates[1].features[1] == "accommodation")

    local parameters = M.parameters()
    parameters.categories[1] = "Caller edit"
    expect(M.parameters().categories[1] ~= "Caller edit")

    return {
        status = "passed",
        checks = checks,
        scope = "Embedded synthetic tests only",
        empirical_privacy_validation = false,
        attribution = ATTRIBUTION,
        attribution_scope = SCOPE,
        schema_version = VERSION
    }
end

return M
