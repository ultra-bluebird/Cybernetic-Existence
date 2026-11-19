-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or authorization.
--
-- Per-dimension arithmetic about supplied aggregate counts.
-- No provenance authentication, confidence calibration, joint-tuple
-- analysis, population inference, or execution authorization.
-- No network, file, device, or persistence operations.
-- Lua 5.1+.

local M = {}
local VERSION = "0.2.0-proposed"
local MAX_LABELS = 16
local MAX_CELL = 1000000

local REASONS = {
    invalid_labels = true,
    invalid_matrix = true,
    invalid_cell = true,
    invalid_critical_definition = true
}

local function plain(x)
    return type(x) == "table" and getmetatable(x) == nil
end

local function length(x, maximum)
    if not plain(x) then return nil end
    local count, largest = 0, 0

    for key in next, x do
        count = count + 1
        if count > maximum
            or type(key) ~= "number"
            or key < 1 or key > maximum
            or key % 1 ~= 0 then
            return nil
        end
        largest = math.max(largest, key)
    end

    if count ~= largest then return nil end
    return count
end

local function valid_text(x)
    return type(x) == "string"
        and #x > 0 and #x <= 96
        and x:match("%S") ~= nil
        and x:find("[%z\1-\31\127]") == nil
end

local function label_map(x)
    local n = length(x, MAX_LABELS)
    if not n or n == 0 then return nil end

    local map = {}
    for i = 1, n do
        local label = x[i]
        if not valid_text(label) or map[label] then return nil end
        map[label] = i
    end

    return map, n
end

local function selected_labels(x, universe)
    local n = length(x, MAX_LABELS)
    if not n or n == 0 then return nil end

    local selected = {}
    for i = 1, n do
        local label = x[i]
        if type(label) ~= "string"
            or not universe[label]
            or selected[label] then
            return nil
        end
        selected[label] = true
    end

    return selected
end

local function invalid(reason)
    assert(REASONS[reason], "programmer error: undeclared reason")
    return {
        status = "validation_error",
        implementation_version = VERSION,
        reason = reason
    }
end

local function ratio(numerator, denominator)
    if denominator == 0 then
        return {status = "not_assessed", denominator = 0}
    end
    return {
        status = "computed",
        numerator = numerator,
        denominator = denominator,
        value = numerator / denominator
    }
end

function M.summarize(truth_labels, response_labels, counts, critical)
    local truth, rows = label_map(truth_labels)
    local response, columns = label_map(response_labels)

    if not truth or not response then
        return invalid("invalid_labels")
    end

    for label in pairs(truth) do
        if not response[label] then
            return invalid("invalid_labels")
        end
    end

    if length(counts, MAX_LABELS) ~= rows then
        return invalid("invalid_matrix")
    end

    local critical_truth, critical_response, critical_reference

    if critical ~= nil then
        if not plain(critical) then
            return invalid("invalid_critical_definition")
        end

        for key in next, critical do
            if key ~= "truth_states"
                and key ~= "response_states"
                and key ~= "definition_reference" then
                return invalid("invalid_critical_definition")
            end
        end

        critical_truth = selected_labels(critical.truth_states, truth)
        critical_response =
            selected_labels(critical.response_states, response)
        critical_reference = critical.definition_reference

        if not critical_truth
            or not critical_response
            or not valid_text(critical_reference) then
            return invalid("invalid_critical_definition")
        end

        for label in pairs(critical_truth) do
            if critical_response[label] then
                return invalid("invalid_critical_definition")
            end
        end
    end

    local total, correct = 0, 0
    local critical_count, critical_denominator = 0, 0
    local assessed_rows, macro_sum = 0, 0
    local per_state = {}

    for i = 1, rows do
        if length(counts[i], MAX_LABELS) ~= columns then
            return invalid("invalid_matrix")
        end

        local row_total = 0
        for j = 1, columns do
            local x = counts[i][j]
            if type(x) ~= "number"
                or x ~= x
                or x < 0 or x > MAX_CELL
                or x % 1 ~= 0 then
                return invalid("invalid_cell")
            end
            row_total = row_total + x
        end

        local label = truth_labels[i]
        local row_correct = counts[i][response[label]]

        total = total + row_total
        correct = correct + row_correct
        per_state[label] = ratio(row_correct, row_total)

        if row_total > 0 then
            assessed_rows = assessed_rows + 1
            macro_sum = macro_sum + row_correct / row_total
        end

        if critical_truth and critical_truth[label] then
            critical_denominator = critical_denominator + row_total
            for j = 1, columns do
                if critical_response[response_labels[j]] then
                    critical_count = critical_count + counts[i][j]
                end
            end
        end
    end

    local balanced
    if assessed_rows == rows then
        balanced = {
            status = "computed",
            value = macro_sum / rows,
            assessed_states = assessed_rows,
            required_states = rows
        }
    else
        balanced = {
            status = "incomplete",
            assessed_states = assessed_rows,
            required_states = rows
        }
    end

    local critical_result = {status = "not_defined"}
    if critical_truth then
        critical_result = ratio(critical_count, critical_denominator)
        critical_result.definition_reference = critical_reference
    end

    return {
        status = total > 0 and "computed" or "not_assessed",
        implementation_version = VERSION,
        scope = "single_dimension_supplied_count_arithmetic",
        accuracy = ratio(correct, total),
        error_fraction = ratio(total - correct, total),
        balanced_accuracy = balanced,
        per_truth_state = per_state,
        critical_error = critical_result,
        evidence_limits = {
            provenance = "not_verified",
            sampling_uncertainty = "excluded",
            confidence_calibration = "not_computed",
            joint_dimension_errors = "not_computed"
        }
    }
end

function M.self_test()
    local truth = {"authorized", "prohibited"}
    local responses = {"authorized", "prohibited", "not_sure"}
    local critical = {
        truth_states = {"prohibited"},
        response_states = {"authorized"},
        definition_reference = "synthetic_false_authorization"
    }

    local r = M.summarize(truth, responses, {
        {9, 1, 0},
        {1, 0, 0}
    }, critical)

    assert(r.accuracy.numerator == 9)
    assert(r.accuracy.denominator == 11)
    assert(r.critical_error.numerator == 1)
    assert(r.critical_error.denominator == 1)

    local empty = M.summarize(truth, responses, {
        {0, 0, 0}, {0, 0, 0}
    }, critical)
    assert(empty.accuracy.status == "not_assessed")
    assert(empty.error_fraction.status == "not_assessed")
    assert(empty.balanced_accuracy.status == "incomplete")

    local duplicate = M.summarize(
        {"authorized", "authorized"}, responses, {{1, 0, 0}, {0, 1, 0}}
    )
    assert(duplicate.reason == "invalid_labels")

    local control = M.summarize(
        {"bad\nlabel"}, {"bad\nlabel"}, {{1}}
    )
    assert(control.reason == "invalid_labels")

    local wrong_shape = M.summarize(truth, responses, {{1}, {0}})
    assert(wrong_shape.reason == "invalid_matrix")

    local singleton = M.summarize({"a"}, {"a"}, {{1000000}})
    assert(singleton.accuracy.numerator == 1000000)
    assert(singleton.accuracy.denominator == 1000000)

    return {
        status = "self_checks_passed",
        implementation_version = VERSION,
        scope = "synthetic_count_and_validation_cases"
    }
end

return M
