local function is_finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function require_nonnegative(value)
    return is_finite(value) and value >= 0
end

local function active_corridor(input)
    local required = {
        input.critical_power_w,
        input.outage_duration_hours_quantile,
        input.available_energy_wh,
        input.essential_water_l_per_hour,
        input.thermal_support_water_l_per_hour,
        input.available_water_l,
        input.heat_risk,
        input.maximum_heat_risk,
        input.compound_event_confidence,
        input.minimum_confidence
    }

    for _, value in ipairs(required) do
        if not require_nonnegative(value) then
            return "INDETERMINATE", "invalid_or_missing_input"
        end
    end

    if input.maximum_heat_risk > 1
        or input.heat_risk > 1
        or input.compound_event_confidence > 1
        or input.minimum_confidence > 1 then
        return "INDETERMINATE", "probability_or_risk_out_of_range"
    end

    if input.ecological_floor_met ~= true
        or input.accessibility_floor_met ~= true then
        return "HALT", "noncompensable_floor_not_met"
    end

    local required_energy_wh =
        input.critical_power_w * input.outage_duration_hours_quantile

    local required_water_l =
        (input.essential_water_l_per_hour
            + input.thermal_support_water_l_per_hour)
        * input.outage_duration_hours_quantile

    if input.compound_event_confidence < input.minimum_confidence then
        return "INDETERMINATE", "compound_tail_confidence_insufficient"
    end

    if input.heat_risk > input.maximum_heat_risk then
        return "DERATE", "thermal_corridor_exceeded"
    end

    if input.available_energy_wh < required_energy_wh then
        return "DERATE", "energy_resilience_buffer_insufficient"
    end

    if input.available_water_l < required_water_l then
        return "DERATE", "water_resilience_buffer_insufficient"
    end

    return "ACTIVE", "compound_resilience_buffers_met"
end

return {
    active_corridor = active_corridor
}
