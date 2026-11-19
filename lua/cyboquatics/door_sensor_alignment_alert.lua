local door_sensor_alignment_alert = {}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function door_sensor_alignment_alert.evaluate(input)
    if type(input) ~= "table"
        or not finite(input.expected_crossing_duration_s)
        or input.expected_crossing_duration_s <= 0.0
        or not finite(input.observed_crossing_duration_s)
        or input.observed_crossing_duration_s < 0.0
        or not finite(input.allowed_duration_deviation_s)
        or input.allowed_duration_deviation_s <= 0.0
        or type(input.sensor_health_flag) ~= "boolean"
        or type(input.inconsistent_sample_count) ~= "number"
        or input.inconsistent_sample_count < 0
        or input.inconsistent_sample_count % 1 ~= 0
        or type(input.inconsistency_count_threshold) ~= "number"
        or input.inconsistency_count_threshold < 1
        or input.inconsistency_count_threshold % 1 ~= 0 then
        return {
            decision = "REJECTED_INPUT",
            physical_door_control_authorized = false,
            reasons = { "invalid_timing_or_sensor_input" }
        }
    end

    local residual = math.abs(
        input.observed_crossing_duration_s - input.expected_crossing_duration_s
    ) / input.allowed_duration_deviation_s

    local reasons = {}

    if residual > 1.0 then
        table.insert(reasons, "timing_residual_exceeds_1_0")
    end
    if not input.sensor_health_flag then
        table.insert(reasons, "sensor_health_flag_false")
    end
    if input.inconsistent_sample_count >= input.inconsistency_count_threshold then
        table.insert(reasons, "repeated_samples_inconsistent")
    end

    if #reasons > 0 then
        return {
            decision = "ALIGNMENT_ALERT",
            timing_residual = residual,
            physical_door_control_authorized = false,
            reasons = reasons
        }
    end

    return {
        decision = "WITHIN_CONFIGURED_TIMING_BAND",
        timing_residual = residual,
        physical_door_control_authorized = false,
        reasons = { "non_actuating_inspection_result_only" }
    }
end

return door_sensor_alignment_alert
