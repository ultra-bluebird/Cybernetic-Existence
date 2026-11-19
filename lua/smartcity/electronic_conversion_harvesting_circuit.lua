local EnergyHarvesting = {}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function nonnegative(value)
    return finite_number(value) and value >= 0.0
end

local function unit_interval(value)
    return finite_number(value) and value >= 0.0 and value <= 1.0
end

local function positive(value)
    return finite_number(value) and value > 0.0
end

local function result(output_state, reason_codes, values)
    return {
        output_state = output_state,
        reason_codes = reason_codes or {},
        values = values or {},
        local_first = true,
        advisory_only = true,
        automated_actuation_authorized = false,
        person_assessment_performed = false,
        identity_resolution_performed = false,
        biometric_identification_performed = false,
        cybernetic_status_assessment_performed = false
    }
end

local function sum_critical_reserve(loads, rail_efficiency, startup_energy, margin_energy)
    if type(loads) ~= "table" or #loads == 0 then
        return nil
    end

    if not unit_interval(rail_efficiency) or rail_efficiency == 0.0 then
        return nil
    end

    if not nonnegative(startup_energy) or not nonnegative(margin_energy) then
        return nil
    end

    local required_energy = 0.0

    for _, load in ipairs(loads) do
        if type(load) ~= "table"
            or load.accessibility_or_safety_critical ~= true
            or not nonnegative(load.power_watts)
            or not nonnegative(load.required_autonomy_seconds) then
            return nil
        end

        required_energy = required_energy
            + load.power_watts * load.required_autonomy_seconds
    end

    return required_energy / rail_efficiency
        + startup_energy
        + margin_energy
end

function EnergyHarvesting.available_power(
    ambient_power_watts,
    harvesting_efficiency,
    degradation_factor
)
    if not nonnegative(ambient_power_watts)
        or not unit_interval(harvesting_efficiency)
        or not unit_interval(degradation_factor) then
        return nil
    end

    return harvesting_efficiency
        * ambient_power_watts
        * (1.0 - degradation_factor)
end

function EnergyHarvesting.supercapacitor_available_energy(
    capacitance_farads,
    voltage_current,
    voltage_minimum
)
    if not positive(capacitance_farads)
        or not nonnegative(voltage_current)
        or not nonnegative(voltage_minimum)
        or voltage_current < voltage_minimum then
        return nil
    end

    return 0.5
        * capacitance_farads
        * (
            voltage_current * voltage_current
            - voltage_minimum * voltage_minimum
        )
end

function EnergyHarvesting.evaluate(input)
    if type(input) ~= "table" then
        return result(
            "insufficient_evidence",
            { "energy_harvesting_input_missing" }
        )
    end

    if input.requests_safety_or_accessibility_reduction == true
        or input.requests_service_denial == true
        or input.requests_person_assessment == true
        or input.requests_identity_resolution == true
        or input.requests_biometric_identification == true
        or input.requests_cybernetic_status_assessment == true then
        return result(
            "blocked_by_policy",
            { "energy_harvesting_must_not_reduce_protected_functions" }
        )
    end

    local available_power = EnergyHarvesting.available_power(
        input.ambient_power_watts,
        input.harvesting_efficiency,
        input.degradation_factor
    )

    local required_reserve = sum_critical_reserve(
        input.critical_loads,
        input.rail_efficiency,
        input.startup_energy_joules,
        input.reserve_margin_joules
    )

    if available_power == nil or required_reserve == nil
        or not nonnegative(input.stored_energy_joules) then
        return result(
            "insufficient_evidence",
            { "energy_harvesting_measurement_or_reserve_inputs_invalid" }
        )
    end

    local values = {
        available_power_watts = available_power,
        stored_energy_joules = input.stored_energy_joules,
        required_reserve_joules = required_reserve,
        reserve_difference_joules = input.stored_energy_joules - required_reserve
    }

    if input.local_energy_status_available ~= true
        or input.accessible_energy_status_available ~= true then
        return result(
            "needs_review",
            {
                "local_accessible_energy_status_required"
            },
            values
        )
    end

    if input.uncertainty_within_declared_bound ~= true then
        return result(
            "needs_review",
            {
                "energy_estimate_uncertainty_requires_review"
            },
            values
        )
    end

    if input.stored_energy_joules < required_reserve then
        return result(
            "defer_noncritical_loads",
            {
                "critical_energy_reserve_below_required_level",
                "preserve_safety_and_accessibility_loads",
                "maintenance_review_required"
            },
            values
        )
    end

    return result(
        "critical_reserve_available",
        {
            "critical_safety_and_accessibility_reserve_available",
            "noncritical_loads_may_remain_deferred_by_local_policy"
        },
        values
    )
end

return EnergyHarvesting
