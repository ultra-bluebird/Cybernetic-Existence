local cec_trend_indicator = {}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function unit_interval(value)
    return finite(value) and value >= 0.0 and value <= 1.0
end

local function median(values)
    local copy = {}
    for i, value in ipairs(values) do
        copy[i] = value
    end
    table.sort(copy)

    local count = #copy
    local middle = math.floor(count / 2) + 1
    if count % 2 == 1 then
        return copy[middle]
    end
    return (copy[middle - 1] + copy[middle]) / 2.0
end

function cec_trend_indicator.evaluate(input)
    if type(input) ~= "table"
        or not finite(input.current_cec)
        or type(input.prior_valid_cec_values) ~= "table"
        or not unit_interval(input.measurement_quality)
        or not unit_interval(input.minimum_measurement_quality)
        or type(input.minimum_prior_observation_count) ~= "number"
        or input.minimum_prior_observation_count < 1
        or input.minimum_prior_observation_count % 1 ~= 0
        or not finite(input.denominator_floor)
        or input.denominator_floor <= 0.0
        or not finite(input.configured_deviation_threshold)
        or input.configured_deviation_threshold < 0.0
        or type(input.extraction_method) ~= "string"
        or input.extraction_method == ""
        or type(input.unit) ~= "string"
        or input.unit == "" then
        return {
            decision = "REJECTED_INPUT",
            reasons = { "invalid_cec_input_or_configuration" }
        }
    end

    for _, value in ipairs(input.prior_valid_cec_values) do
        if not finite(value) then
            return {
                decision = "REJECTED_INPUT",
                reasons = { "non_finite_prior_cec_value" }
            }
        end
    end

    if #input.prior_valid_cec_values < input.minimum_prior_observation_count
        or input.measurement_quality < input.minimum_measurement_quality
        or input.sampling_depth_declared ~= true
        or input.sample_handling_declared ~= true then
        return {
            decision = "CEC_INSUFFICIENT_EVIDENCE",
            reasons = { "baseline_or_quality_evidence_insufficient" }
        }
    end

    local rolling_median = median(input.prior_valid_cec_values)
    local denominator = math.max(math.abs(rolling_median), input.denominator_floor)
    local relative_deviation = math.abs(input.current_cec - rolling_median) / denominator
    local quality_weighted_deviation = relative_deviation * input.measurement_quality

    if quality_weighted_deviation > input.configured_deviation_threshold then
        return {
            decision = "CEC_TREND_REVIEW_REQUIRED",
            rolling_median = rolling_median,
            relative_deviation = relative_deviation,
            quality_weighted_deviation = quality_weighted_deviation,
            reasons = { "quality_weighted_deviation_exceeds_threshold" }
        }
    end

    return {
        decision = "CEC_WITHIN_CONFIGURED_TREND_BAND",
        rolling_median = rolling_median,
        relative_deviation = relative_deviation,
        quality_weighted_deviation = quality_weighted_deviation,
        reasons = { "within_configured_trend_band" }
    }
end

return cec_trend_indicator
