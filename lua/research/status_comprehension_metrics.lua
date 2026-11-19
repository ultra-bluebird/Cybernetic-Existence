-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or authorization.
--
-- Pure aggregate analysis utility.
-- No network, file, device, persistence, or participant inference.
-- Accuracy is not confidence calibration.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"
local MAX_LABELS = 16
local MAX_CELL = 1000000

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function array_length(value, maximum)
    if not plain(value) then return nil end

    local count, largest = 0, 0
    for key in next, value do
        count = count + 1
        if count > maximum
            or type(key) ~= "number"
            or key < 1 or key > maximum
            or key % 1 ~= 0 then
            return nil
        end
        largest = math.max(largest, key)
    end

    if largest ~= count then return nil end
    return count
end

local function labels(value)
    local n = array_length(value, MAX_LABELS)
    if not n or n == 0 then return nil end

    local positions = {}
    for i = 1, n do
        local label = value[i]
        if type(label) ~= "string"
            or #label == 0 or #label > 96
            or not label:match("%S")
            or label:find("[%z\1-\31\127]")
            or positions[label] then
            return nil
        end
        positions[label] = i
    end

    return positions, n
end

local function invalid(reason)
    return {
        status = "validation_error",
        implementation_version = VERSION,
        reason = reason
    }
end

function M.summarize(truth_labels, response_labels, counts)
    local truth_positions, rows = labels(truth_labels)
    local response_positions, columns = labels(response_labels)

    if not truth_positions or not response_positions then
        return invalid("invalid_label_arrays")
    end

    for label in pairs(truth_positions) do
        if not response_positions[label] then
            return invalid("truth_label_missing_from_responses")
        end
    end

    if array_length(counts, MAX_LABELS) ~= rows then
        return invalid("invalid_count_rows")
    end

    local total, correct = 0, 0
    local row_reports = {}
    local macro_sum, assessed_rows = 0, 0

    for i = 1, rows do
        if array_length(counts[i], MAX_LABELS) ~= columns then
            return invalid("invalid_count_columns")
        end

        local row_total = 0
        for j = 1, columns do
            local value = counts[i][j]
            if type(value) ~= "number"
                or value ~= value
                or value < 0 or value > MAX_CELL
                or value % 1 ~= 0 then
                return invalid("invalid_cell_count")
            end
            row_total = row_total + value
        end

        local label = truth_labels[i]
        local row_correct = counts[i][response_positions[label]]
        total = total + row_total
        correct = correct + row_correct

        if row_total == 0 then
            row_reports[label] = {
                status = "not_assessed",
                count = 0
            }
        else
            local probabilities = {}
            for j = 1, columns do
                probabilities[response_labels[j]] =
                    counts[i][j] / row_total
            end

            local recall = row_correct / row_total
            macro_sum = macro_sum + recall
            assessed_rows = assessed_rows + 1

            row_reports[label] = {
                status = "computed",
                count = row_total,
                correct_fraction = recall,
                response_probabilities = probabilities
            }
        end
    end

    local result = {
        status = total == 0 and "not_assessed" or "computed",
        implementation_version = VERSION,
        measure = "comprehension_accuracy",
        count = total,
        correct_count = correct,
        per_truth_state = row_reports,
        balanced_accuracy_status =
            assessed_rows == rows and "computed" or "incomplete",
        confidence_calibration_status = "not_assessed",
        sampling_uncertainty_status = "not_assessed",
        input_provenance_status = "not_verified"
    }

    if total > 0 then
        result.accuracy = correct / total
        result.error_fraction = 1 - result.accuracy
    end

    if assessed_rows == rows then
        result.balanced_accuracy = macro_sum / rows
    end

    return result
end

function M.self_test()
    local truth = {"authorized", "prohibited"}
    local responses = {"authorized", "prohibited", "not_sure"}

    local perfect = M.summarize(truth, responses, {
        {10, 0, 0},
        {0, 10, 0}
    })
    assert(perfect.accuracy == 1)
    assert(perfect.balanced_accuracy == 1)

    local unequal = M.summarize(truth, responses, {
        {9, 1, 0},
        {1, 0, 0}
    })
    assert(math.abs(unequal.accuracy - 9 / 11) < 1e-12)
    assert(math.abs(unequal.balanced_accuracy - 0.45) < 1e-12)
    assert(unequal.per_truth_state.prohibited
        .response_probabilities.authorized == 1)

    local uncertain = M.summarize(truth, responses, {
        {0, 0, 5},
        {0, 0, 5}
    })
    assert(uncertain.accuracy == 0)
    assert(uncertain.per_truth_state.authorized
        .response_probabilities.not_sure == 1)

    local missing_state = M.summarize(truth, responses, {
        {5, 0, 0},
        {0, 0, 0}
    })
    assert(missing_state.balanced_accuracy_status == "incomplete")
    assert(missing_state.balanced_accuracy == nil)

    local malformed = M.summarize(truth, responses, {
        {1, -1, 0},
        {0, 1, 0}
    })
    assert(malformed.status == "validation_error")

    return {
        status = "self_checks_passed",
        implementation_version = VERSION,
        scope = "synthetic_arithmetic_and_shape_cases"
    }
end

return M
