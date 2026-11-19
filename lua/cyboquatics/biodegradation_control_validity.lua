local biodegradation_control_validity = {}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function unit_interval(value)
    return finite(value) and value >= 0.0 and value <= 1.0
end

function biodegradation_control_validity.evaluate(input)
    if type(input) ~= "table"
        or type(input.method_name) ~= "string"
        or input.method_name == ""
        or type(input.method_version) ~= "string"
        or input.method_version == ""
        or not finite(input.duration_days)
        or input.duration_days < 0.0
        or not finite(input.minimum_duration_days)
        or input.minimum_duration_days <= 0.0
        or type(input.replicate_count) ~= "number"
        or input.replicate_count < 1
        or input.replicate_count % 1 ~= 0
        or type(input.minimum_replicate_count) ~= "number"
        or input.minimum_replicate_count < 1
        or input.minimum_replicate_count % 1 ~= 0
        or not unit_interval(input.replicate_spread)
        or not unit_interval(input.maximum_replicate_spread)
        or type(input.blank_or_negative_control_valid) ~= "boolean"
        or type(input.positive_control_valid) ~= "boolean"
        or type(input.response_channel) ~= "string" then
        return {
            decision = "REJECTED_INPUT",
            reasons = { "invalid_control_validity_input" }
        }
    end

    local reasons = {}

    if input.duration_days < input.minimum_duration_days then
        table.insert(reasons, "duration_below_configured_method_minimum")
    end
    if input.replicate_count < input.minimum_replicate_count then
        table.insert(reasons, "replicate_count_below_minimum")
    end
    if not input.blank_or_negative_control_valid then
        table.insert(reasons, "blank_or_negative_control_invalid")
    end
    if not input.positive_control_valid then
        table.insert(reasons, "positive_control_invalid")
    end
    if input.replicate_spread > input.maximum_replicate_spread then
        table.insert(reasons, "replicate_spread_exceeds_maximum")
    end
    if input.response_channel == "OXYGEN_DEMAND" and
        (not finite(input.oxygen_demand_value) or input.oxygen_demand_value < 0.0) then
        table.insert(reasons, "oxygen_demand_response_missing_or_invalid")
    end
    if input.response_channel == "CARBON_DIOXIDE_EVOLUTION" and
        (not finite(input.carbon_dioxide_evolution_value) or input.carbon_dioxide_evolution_value < 0.0) then
        table.insert(reasons, "carbon_dioxide_response_missing_or_invalid")
    end
    if input.response_channel ~= "OXYGEN_DEMAND" and
        input.response_channel ~= "CARBON_DIOXIDE_EVOLUTION" then
        table.insert(reasons, "unknown_response_channel")
    end
    if input.temperature_declared ~= true then
        table.insert(reasons, "temperature_missing")
    end
    if input.test_medium_declared ~= true then
        table.insert(reasons, "test_medium_missing")
    end
    if input.inoculum_or_compost_source_declared ~= true then
        table.insert(reasons, "inoculum_or_compost_source_missing")
    end
    if input.units_declared ~= true then
        table.insert(reasons, "units_missing")
    end
    if input.calibration_current ~= true then
        table.insert(reasons, "calibration_missing_or_stale")
    end
    if input.chain_of_custody_complete ~= true then
        table.insert(reasons, "chain_of_custody_incomplete")
    end

    if #reasons > 0 then
        return {
            decision = "INSUFFICIENT_EVIDENCE",
            reasons = reasons
        }
    end

    return {
        decision = "CONTROL_VALIDITY_REVIEW_READY",
        reasons = {
            "method_aligned_controls_and_required_metadata_present",
            "not_a_biodegradability_or_compliance_determination"
        }
    }
end

return biodegradation_control_validity
