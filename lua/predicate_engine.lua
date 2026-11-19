local PredicateEngine = {}

local OUTCOME = {
    PERMITTED = "permitted",
    DENIED = "denied",
    REVIEW = "review",
}

local function result(outcome, explanation_code, details)
    return {
        outcome = outcome,
        explanation_code = explanation_code,
        details = details or {},
    }
end

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function in_range(value, minimum, maximum)
    return is_finite_number(value)
        and value >= minimum
        and value <= maximum
end

local function boolean_or_nil(value)
    return value == nil or type(value) == "boolean"
end

local function all_permitted(predicate_results)
    for _, predicate_result in ipairs(predicate_results) do
        if predicate_result.outcome ~= OUTCOME.PERMITTED then
            return false
        end
    end

    return true
end

local function has_review(predicate_results)
    for _, predicate_result in ipairs(predicate_results) do
        if predicate_result.outcome == OUTCOME.REVIEW then
            return true
        end
    end

    return false
end

function PredicateEngine.thermalContainment(input, policy)
    local temperature = input.surface_temperature_c

    if temperature == nil then
        return result(
            OUTCOME.REVIEW,
            "THERMAL_SENSOR_MISSING",
            { metric = "surface_temperature_c" }
        )
    end

    if not in_range(temperature, -20.0, 200.0) then
        return result(
            OUTCOME.DENIED,
            "THERMAL_SENSOR_OUT_OF_RANGE",
            { metric = "surface_temperature_c", measured = temperature }
        )
    end

    if temperature > policy.maximum_surface_temperature_c then
        return result(
            OUTCOME.DENIED,
            "THERMAL_CONTAINMENT_THRESHOLD_EXCEEDED",
            {
                metric = "surface_temperature_c",
                measured = temperature,
                threshold = policy.maximum_surface_temperature_c,
            }
        )
    end

    return result(
        OUTCOME.PERMITTED,
        "THERMAL_CONTAINMENT_OK",
        { measured = temperature }
    )
end

function PredicateEngine.airQuality(input, policy)
    local air_quality_ok = input.air_quality_ok

    if air_quality_ok == nil then
        return result(
            OUTCOME.REVIEW,
            "AIR_QUALITY_STATUS_MISSING",
            { metric = "air_quality_ok" }
        )
    end

    if type(air_quality_ok) ~= "boolean" then
        return result(
            OUTCOME.DENIED,
            "AIR_QUALITY_STATUS_INVALID",
            { metric = "air_quality_ok" }
        )
    end

    if air_quality_ok == false then
        return result(
            OUTCOME.DENIED,
            "AIR_QUALITY_NOT_ACCEPTABLE",
            { metric = "air_quality_ok" }
        )
    end

    return result(
        OUTCOME.PERMITTED,
        "AIR_QUALITY_OK",
        { metric = "air_quality_ok" }
    )
end

function PredicateEngine.waterStress(input, policy)
    local stage = input.water_stress_stage

    if stage == nil then
        return result(
            OUTCOME.REVIEW,
            "WATER_STRESS_STAGE_MISSING",
            { metric = "water_stress_stage" }
        )
    end

    if not is_finite_number(stage) or stage % 1 ~= 0 or stage < 0 or stage > 5 then
        return result(
            OUTCOME.DENIED,
            "WATER_STRESS_STAGE_INVALID",
            { metric = "water_stress_stage", measured = stage }
        )
    end

    if stage > policy.maximum_water_stress_stage then
        return result(
            OUTCOME.DENIED,
            "WATER_STRESS_STAGE_EXCEEDED",
            {
                metric = "water_stress_stage",
                measured = stage,
                threshold = policy.maximum_water_stress_stage,
            }
        )
    end

    return result(
        OUTCOME.PERMITTED,
        "WATER_STRESS_STAGE_OK",
        { measured = stage }
    )
end

function PredicateEngine.heatAlert(input, policy)
    local heat_alert = input.heat_alert

    if heat_alert == nil then
        return result(
            OUTCOME.REVIEW,
            "HEAT_ALERT_STATUS_MISSING",
            { metric = "heat_alert" }
        )
    end

    if type(heat_alert) ~= "boolean" then
        return result(
            OUTCOME.DENIED,
            "HEAT_ALERT_STATUS_INVALID",
            { metric = "heat_alert" }
        )
    end

    if heat_alert == true and policy.heat_alert_blocks_nonessential_workloads then
        return result(
            OUTCOME.DENIED,
            "HEAT_ALERT_NONESSENTIAL_WORKLOAD_BLOCKED",
            { metric = "heat_alert" }
        )
    end

    return result(
        OUTCOME.PERMITTED,
        "HEAT_ALERT_POLICY_OK",
        { metric = "heat_alert" }
    )
end

function PredicateEngine.identityAccess(input, policy)
    local access_request = input.access_request

    if access_request == nil then
        return result(
            OUTCOME.REVIEW,
            "ACCESS_REQUEST_STATUS_MISSING",
            { metric = "access_request" }
        )
    end

    if type(access_request) ~= "boolean" then
        return result(
            OUTCOME.DENIED,
            "ACCESS_REQUEST_STATUS_INVALID",
            { metric = "access_request" }
        )
    end

    if access_request == false then
        return result(
            OUTCOME.PERMITTED,
            "NO_ACCESS_REQUEST_PRESENT",
            { metric = "access_request" }
        )
    end

    if policy.identity_verification_required == true then
        return result(
            OUTCOME.DENIED,
            "IDENTITY_VERIFICATION_POLICY_INVALID",
            { policy_violation = "identity_verification_required" }
        )
    end

    return result(
        OUTCOME.PERMITTED,
        "ACCESS_REQUEST_ACCEPTED_WITHOUT_IDENTITY_GATE",
        { metric = "access_request" }
    )
end

function PredicateEngine.evaluate(input, policy)
    assert(type(input) == "table", "input must be a table")
    assert(type(policy) == "table", "policy must be a table")

    if not in_range(policy.maximum_surface_temperature_c, 0.0, 200.0) then
        return result(
            OUTCOME.DENIED,
            "POLICY_MAXIMUM_SURFACE_TEMPERATURE_INVALID"
        )
    end

    if not is_finite_number(policy.maximum_water_stress_stage)
        or policy.maximum_water_stress_stage % 1 ~= 0
        or policy.maximum_water_stress_stage < 0
        or policy.maximum_water_stress_stage > 5 then
        return result(
            OUTCOME.DENIED,
            "POLICY_MAXIMUM_WATER_STRESS_STAGE_INVALID"
        )
    end

    if not boolean_or_nil(policy.heat_alert_blocks_nonessential_workloads)
        or not boolean_or_nil(policy.identity_verification_required) then
        return result(
            OUTCOME.DENIED,
            "POLICY_BOOLEAN_FIELD_INVALID"
        )
    end

    local predicates = {
        PredicateEngine.thermalContainment(input, policy),
        PredicateEngine.airQuality(input, policy),
        PredicateEngine.waterStress(input, policy),
        PredicateEngine.heatAlert(input, policy),
        PredicateEngine.identityAccess(input, policy),
    }

    if all_permitted(predicates) then
        return result(
            OUTCOME.PERMITTED,
            "ALL_LOCAL_PREDICATES_PERMITTED",
            { predicates = predicates }
        )
    end

    if has_review(predicates) then
        return result(
            OUTCOME.REVIEW,
            "LOCAL_PREDICATE_DATA_INCOMPLETE_OR_REQUIRES_HUMAN_REVIEW",
            { predicates = predicates }
        )
    end

    return result(
        OUTCOME.DENIED,
        "LOCAL_PREDICATE_DENIAL",
        { predicates = predicates }
    )
end

return PredicateEngine
