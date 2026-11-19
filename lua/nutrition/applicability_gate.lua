-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Proposed Lua 5.4 applicability-contract evaluator.
-- No I/O, dynamic code loading, identity inference, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local function plain(value, label)
    assert(type(value) == "table"
        and getmetatable(value) == nil,
        label .. " must be a plain table")
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 256
end

local function scalar(value)
    return type(value) == "boolean"
        or text(value)
        or finite(value)
end

local function array(value, label)
    plain(value, label)
    local count = 0
    for key in pairs(value) do
        assert(type(key) == "number" and key % 1 == 0
            and key >= 1 and key <= 128,
            label .. " must be a bounded sequence")
        count = count + 1
    end
    for index = 1, count do
        assert(rawget(value, index) ~= nil,
            label .. " must be contiguous")
    end
    return count
end

local function validate_rule(rule)
    plain(rule, "rule")
    assert(text(rule.field), "rule requires a field")
    assert(text(rule.basis), "rule requires a review basis")
    assert(rule.kind == "numeric" or rule.kind == "equals",
        "unsupported rule kind")

    if rule.kind == "numeric" then
        assert(text(rule.unit), "numeric rule requires a unit")
        assert(finite(rule.minimum) and finite(rule.maximum)
            and rule.minimum <= rule.maximum,
            "numeric rule requires ordered finite bounds")
    else
        assert(scalar(rule.expected), "invalid expected value")
    end
end

local function evaluate_rule(rule, values)
    local observed = rawget(values, rule.field)
    if observed == nil then
        return "unknown", "missing_input"
    end

    if rule.kind == "equals" then
        if not scalar(observed) then
            return "unknown", "invalid_input"
        end
        if type(observed) ~= type(rule.expected) then
            return "unknown", "type_mismatch"
        end
        if observed == rule.expected then
            return "satisfied", "matched"
        end
        return "violated", "mismatch"
    end

    if type(observed) ~= "table"
        or getmetatable(observed) ~= nil
        or not finite(rawget(observed, "value")) then
        return "unknown", "invalid_numeric_input"
    end
    if rawget(observed, "unit") ~= rule.unit then
        return "unknown", "unit_mismatch"
    end

    local value = rawget(observed, "value")
    if value < rule.minimum or value > rule.maximum then
        return "violated", "outside_contract_bounds"
    end
    return "satisfied", "within_contract_bounds"
end

local function evaluate_group(rules, values)
    local count = array(rules, "rules")
    assert(count > 0, "empty rule group is not admitted")

    local outcomes = {}
    local violated, unknown = false, false

    for index = 1, count do
        local rule = rules[index]
        validate_rule(rule)
        local state, reason = evaluate_rule(rule, values)
        outcomes[index] = {
            field = rule.field,
            basis = rule.basis,
            state = state,
            reason = reason
        }
        if state == "violated" then violated = true end
        if state == "unknown" then unknown = true end
    end

    if violated then return "violated", outcomes end
    if unknown then return "unknown", outcomes end
    return "satisfied", outcomes
end

function M.evaluate(manifest, inputs, context)
    plain(manifest, "manifest")
    plain(inputs, "inputs")
    plain(context, "context")

    assert(manifest.schema == "energy-gate-v1",
        "unsupported manifest schema")
    assert(text(manifest.source) and text(manifest.revision),
        "manifest requires source and revision")

    local computation, computation_checks =
        evaluate_group(manifest.computation, inputs)
    local population, population_checks =
        evaluate_group(manifest.population, inputs)
    local use, use_checks =
        evaluate_group(manifest.use, context)

    local applicability
    if population == "violated" or use == "violated" then
        applicability = "not_applicable"
    elseif population == "unknown" or use == "unknown" then
        applicability = "unresolved"
    else
        applicability = "applicable"
    end

    local computability
    if computation == "satisfied" then
        computability = "computable"
    else
        computability = "unavailable"
    end

    return {
        source = manifest.source,
        revision = manifest.revision,
        computability = computability,
        applicability = applicability,
        candidate_for_verified_evaluation =
            computability == "computable"
            and applicability == "applicable",
        computation_checks = computation_checks,
        population_checks = population_checks,
        use_checks = use_checks,
        estimate_status = "not_computed",
        personal_estimate_release = "not_assessed",
        evidence_origin = "supplied_inputs_and_contract",
        external_action_authorized = false,
        essential_service_access_affected = false
    }
end

return M
