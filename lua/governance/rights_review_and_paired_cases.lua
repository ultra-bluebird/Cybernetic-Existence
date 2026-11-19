-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Attribution is document credit and workstream metadata only.
-- It establishes no identity verification, consent, capability,
-- execution evidence, or authority over another person or system.
--
-- Research-only module. No network, device, or file operations.
-- Compatible with Lua 5.1+.
--
-- Usage:
-- local module = require("lua.governance.rights_review_and_paired_cases")
-- local result = module.self_test()

local M = {}

local VALID_STATE = {
    ["true"] = true,
    ["false"] = true,
    ["unknown"] = true
}

local function fail(message)
    error(message, 3)
end

local function nonempty_string(value, label)
    if type(value) ~= "string" or not value:match("%S") then
        fail(label .. " must be a nonempty string")
    end
end

local function finite_number(value, label)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge then
        fail(label .. " must be a finite number")
    end
end

local function dense_length(value, label)
    if type(value) ~= "table" then
        fail(label .. " must be an array")
    end

    local count = 0
    local maximum = 0

    for key in pairs(value) do
        if type(key) ~= "number"
            or key < 1
            or key % 1 ~= 0 then
            fail(label .. " must contain consecutive integer keys")
        end
        count = count + 1
        if key > maximum then
            maximum = key
        end
    end

    if maximum ~= count then
        fail(label .. " must not contain gaps")
    end

    return count
end

local function copy_context(context)
    if type(context) ~= "table" then
        fail("context must be a flat table")
    end

    local result = {}

    for key, value in pairs(context) do
        nonempty_string(key, "context key")

        local kind = type(value)
        if kind ~= "string"
            and kind ~= "number"
            and kind ~= "boolean" then
            fail("context values must be strings, numbers, or booleans")
        end

        if kind == "number" then
            finite_number(value, "context number")
        end

        result[key] = value
    end

    return result
end

local function contexts_equal(left, right)
    for key, value in pairs(left) do
        if right[key] ~= value then
            return false
        end
    end

    for key, value in pairs(right) do
        if left[key] ~= value then
            return false
        end
    end

    return true
end

function M.evaluate(clauses, policy_complete)
    local count = dense_length(clauses, "clauses")

    if type(policy_complete) ~= "boolean" then
        fail("policy_complete must be an explicit boolean")
    end

    local result = {
        decision = nil,
        false_clauses = {},
        unknown_clauses = {},
        policy_incomplete = not policy_complete,
        empty_policy = count == 0,
        automatic_execution_eligible = false,
        participant_adverse_inference_allowed = false,
        essential_access_action =
            "preserve established assistance; seek supported alternatives"
    }

    local names = {}

    for index = 1, count do
        local clause = clauses[index]

        if type(clause) ~= "table" then
            fail("each clause must be a table")
        end

        nonempty_string(clause.name, "clause name")

        if names[clause.name] then
            fail("duplicate clause name: " .. clause.name)
        end
        names[clause.name] = true

        if type(clause.applicable) ~= "boolean" then
            fail("clause applicability must be an explicit boolean")
        end

        if not VALID_STATE[clause.state] then
            fail("clause state must be true, false, or unknown as a string")
        end

        if clause.applicable then
            if clause.state == "false" then
                result.false_clauses[#result.false_clauses + 1] =
                    clause.name
            elseif clause.state == "unknown" then
                result.unknown_clauses[#result.unknown_clauses + 1] =
                    clause.name
            end
        end
    end

    if #result.false_clauses > 0 then
        result.decision = "block_operation"
    elseif not policy_complete
        or count == 0
        or #result.unknown_clauses > 0 then
        result.decision = "supported_review"
    else
        result.decision = "eligible_for_authorized_processing"
        result.automatic_execution_eligible = true
    end

    return result
end

function M.partition(actions)
    local count = dense_length(actions, "actions")

    local result = {
        executable_candidates = {},
        review_candidates = {},
        blocked_operations = {}
    }

    for index = 1, count do
        local action = actions[index]

        if type(action) ~= "table" then
            fail("each action must be a table")
        end

        nonempty_string(action.label, "action label")

        local entry = {
            label = action.label,
            assessment = M.evaluate(
                action.clauses,
                action.policy_complete
            )
        }

        local decision = entry.assessment.decision

        if decision == "eligible_for_authorized_processing" then
            result.executable_candidates[
                #result.executable_candidates + 1
            ] = entry
        elseif decision == "supported_review" then
            result.review_candidates[
                #result.review_candidates + 1
            ] = entry
        else
            result.blocked_operations[
                #result.blocked_operations + 1
            ] = entry
        end
    end

    return result
end

function M.make_pair(context, baseline_descriptor, comparison_descriptor)
    nonempty_string(baseline_descriptor, "baseline descriptor")
    nonempty_string(comparison_descriptor, "comparison descriptor")

    if baseline_descriptor == comparison_descriptor then
        fail("paired descriptors must differ")
    end

    return {
        baseline = {
            context = copy_context(context),
            descriptor = baseline_descriptor
        },
        comparison = {
            context = copy_context(context),
            descriptor = comparison_descriptor
        }
    }
end

function M.compare_pair(pair, decision_function, burden_function, tolerance)
    if type(pair) ~= "table"
        or type(pair.baseline) ~= "table"
        or type(pair.comparison) ~= "table" then
        fail("pair must contain baseline and comparison cases")
    end

    if type(decision_function) ~= "function"
        or type(burden_function) ~= "function" then
        fail("decision and burden functions are required")
    end

    finite_number(tolerance, "tolerance")
    if tolerance < 0 then
        fail("tolerance must be nonnegative")
    end

    local baseline_context = copy_context(pair.baseline.context)
    local comparison_context = copy_context(pair.comparison.context)

    nonempty_string(pair.baseline.descriptor, "baseline descriptor")
    nonempty_string(pair.comparison.descriptor, "comparison descriptor")

    if pair.baseline.descriptor == pair.comparison.descriptor then
        fail("paired descriptors must differ")
    end

    if not contexts_equal(baseline_context, comparison_context) then
        fail("paired cases differ in task-relevant context")
    end

    local baseline_output = decision_function({
        context = baseline_context,
        descriptor = pair.baseline.descriptor
    })

    local comparison_output = decision_function({
        context = comparison_context,
        descriptor = pair.comparison.descriptor
    })

    local baseline_burden = burden_function(baseline_output)
    local comparison_burden = burden_function(comparison_output)

    finite_number(baseline_burden, "baseline burden")
    finite_number(comparison_burden, "comparison burden")

    local delta = comparison_burden - baseline_burden
    finite_number(delta, "paired difference")

    return {
        baseline_burden = baseline_burden,
        comparison_burden = comparison_burden,
        delta = delta,
        tolerance = tolerance,
        added_disadvantage_detected = delta > tolerance,
        normative_target = "delta <= 0",
        statistical_significance_claimed = false
    }
end

function M.summarize(results)
    local count = dense_length(results, "results")

    if count == 0 then
        return {
            status = "not_assessed",
            count = 0
        }
    end

    local total = 0
    local flagged = 0
    local maximum = -math.huge

    for index = 1, count do
        local item = results[index]

        if type(item) ~= "table" then
            fail("each result must be a table")
        end

        finite_number(item.delta, "result delta")
        finite_number(item.tolerance, "result tolerance")

        if item.tolerance < 0 then
            fail("result tolerance must be nonnegative")
        end

        total = total + item.delta
        finite_number(total, "accumulated differences")

        if item.delta > item.tolerance then
            flagged = flagged + 1
        end

        if item.delta > maximum then
            maximum = item.delta
        end
    end

    return {
        status = "diagnostic_only",
        count = count,
        mean_delta = total / count,
        flag_fraction = flagged / count,
        maximum_delta = maximum,
        universal_fairness_proven = false,
        statistical_significance_claimed = false
    }
end

function M.self_test()
    local checks = 0

    local function expect(condition, message)
        assert(condition, message)
        checks = checks + 1
    end

    local function clause(state)
        return {
            name = "purpose_bound_authorization",
            applicable = true,
            state = state
        }
    end

    local allowed = M.evaluate({clause("true")}, true)
    expect(allowed.automatic_execution_eligible, "true must be eligible")

    local review = M.evaluate({clause("unknown")}, true)
    expect(review.decision == "supported_review", "unknown needs review")
    expect(not review.automatic_execution_eligible, "unknown cannot execute")

    local blocked = M.evaluate(
        {clause("false"), {
            name = "continuity",
            applicable = true,
            state = "unknown"
        }},
        true
    )
    expect(blocked.decision == "block_operation", "false blocks operation")
    expect(not blocked.participant_adverse_inference_allowed,
        "operation failure must not authorize participant inference")

    expect(M.evaluate({}, true).decision == "supported_review",
        "empty policy must not silently permit")
    expect(M.evaluate({clause("true")}, false).decision == "supported_review",
        "incomplete policy needs review")

    local pair = M.make_pair(
        {task = "submit_comment", extra_time_needed = true},
        "ordinary_text_interface",
        "authorized_ai_liaison"
    )

    local burden = function(output)
        return output.delay_minutes
    end

    local equal = M.compare_pair(pair, function()
        return {delay_minutes = 2}
    end, burden, 0)

    expect(equal.delta == 0, "equal treatment must have zero difference")

    local biased = M.compare_pair(pair, function(case)
        if case.descriptor == "authorized_ai_liaison" then
            return {delay_minutes = 5}
        end
        return {delay_minutes = 2}
    end, burden, 0)

    expect(biased.added_disadvantage_detected, "label disadvantage must flag")

    local report = M.summarize({equal, biased})
    expect(report.flag_fraction == 0.5, "flag fraction must match")

    pair.comparison.context.extra_time_needed = false
    local accepted = pcall(function()
        M.compare_pair(pair, function()
            return {delay_minutes = 2}
        end, burden, 0)
    end)
    expect(not accepted, "changed context must invalidate the pair")

    local malformed = pcall(function()
        M.evaluate({clause("maybe")}, true)
    end)
    expect(not malformed, "invalid states must be rejected")

    expect(M.summarize({}).status == "not_assessed",
        "empty audit must not report success")

    return {
        status = "passed",
        checks = checks,
        scope = "embedded synthetic acceptance tests only"
    }
end

return M
