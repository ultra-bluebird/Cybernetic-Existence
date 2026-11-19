local MaintenanceBotSafety = {}

local unsafe_sensor_states = {
    unavailable = true,
    conflicted = true,
    unknown = true
}

local unsafe_alignment_states = {
    insufficient_evidence = true,
    unknown = true
}

local unsafe_surface_states = {
    wet_or_slippery = true,
    damaged_or_obstructed = true,
    slope_or_terrain_review = true,
    unknown = true
}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function nonnegative(value)
    return finite_number(value) and value >= 0.0
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
        behavioral_profiling_performed = false,
        assistive_technology_inference_performed = false,
        augmentation_or_cybernetic_status_assessment_performed = false
    }
end

local function sensor_stack_is_sufficient(sensor_layers)
    if type(sensor_layers) ~= "table" or #sensor_layers < 3 then
        return false
    end

    local has_range_layer = false
    local has_close_range_layer = false
    local has_contact_layer = false
    local has_emergency_stop = false

    for _, sensor in ipairs(sensor_layers) do
        if type(sensor) ~= "table"
            or sensor.non_identifying_operation ~= true then
            return false
        end

        if unsafe_sensor_states[sensor.health_state]
            or unsafe_sensor_states[sensor.calibration_state]
            or unsafe_alignment_states[sensor.alignment_state] then
            return false
        end

        if sensor.sensor_class == "lidar_or_radar" then
            has_range_layer = true
        elseif sensor.sensor_class == "ultrasonic" then
            has_close_range_layer = true
        elseif sensor.sensor_class == "pressure_sensitive_bumper" then
            has_contact_layer = true
        elseif sensor.sensor_class == "emergency_stop" then
            has_emergency_stop = true
        end
    end

    return has_range_layer
        and has_close_range_layer
        and has_contact_layer
        and has_emergency_stop
end

function MaintenanceBotSafety.required_stopping_distance(
    speed_meters_per_second,
    latency_seconds,
    braking_deceleration_meters_per_second_squared,
    uncertainty_buffer_meters,
    surface_buffer_meters,
    fixed_buffer_meters
)
    if not nonnegative(speed_meters_per_second)
        or not nonnegative(latency_seconds)
        or not positive(braking_deceleration_meters_per_second_squared)
        or not nonnegative(uncertainty_buffer_meters)
        or not nonnegative(surface_buffer_meters)
        or not nonnegative(fixed_buffer_meters) then
        return nil
    end

    return speed_meters_per_second * latency_seconds
        + (
            speed_meters_per_second * speed_meters_per_second
            / (2.0 * braking_deceleration_meters_per_second_squared)
        )
        + uncertainty_buffer_meters
        + surface_buffer_meters
        + fixed_buffer_meters
end

function MaintenanceBotSafety.evaluate(input)
    if type(input) ~= "table" then
        return result(
            "insufficient_evidence",
            { "maintenance_bot_assessment_missing" }
        )
    end

    if input.requests_identity_collection == true
        or input.requests_biometric_processing == true
        or input.requests_behavioral_profiling == true
        or input.requests_assistive_technology_inference == true
        or input.requests_augmentation_or_cybernetic_status_assessment == true
        or input.requests_surveillance == true
        or input.requests_autonomous_public_space_operation == true then
        return result(
            "blocked_by_policy",
            { "identity_surveillance_or_unbounded_autonomy_not_permitted" }
        )
    end

    if input.safety_signage_state ~= "present_and_accessible" then
        return result(
            "do_not_operate",
            { "accessible_safety_signage_required" }
        )
    end

    if input.emergency_stop_state ~= "accessible_and_tested" then
        return result(
            "do_not_operate",
            { "accessible_tested_emergency_stop_required" }
        )
    end

    if input.accessible_path_continuity_state == "not_preserved"
        or input.accessible_path_continuity_state == "unknown" then
        return result(
            "do_not_operate",
            { "accessible_path_continuity_not_preserved" }
        )
    end

    if not sensor_stack_is_sufficient(input.sensor_layers) then
        return result(
            "insufficient_evidence",
            { "maintenance_bot_sensor_stack_not_sufficient_for_protective_operation" }
        )
    end

    if input.person_presence_state == "within_critical_radius"
        or input.person_presence_state == "unknown" then
        return result(
            "emergency_stop_recommended",
            { "person_in_critical_radius_or_presence_unknown" }
        )
    end

    if input.person_presence_state == "within_protective_radius" then
        return result(
            "protective_stop_recommended",
            { "person_in_protective_radius" }
        )
    end

    if input.animal_presence_state == "detected"
        or input.animal_presence_state == "unknown" then
        return result(
            "protective_stop_recommended",
            { "animal_presence_requires_human_guidance" }
        )
    end

    if unsafe_surface_states[input.surface_safety_state] then
        return result(
            "surface_review_required",
            { "surface_condition_requires_review_or_route_avoidance" }
        )
    end

    local stopping_distance = MaintenanceBotSafety.required_stopping_distance(
        input.current_speed_meters_per_second,
        input.worst_case_latency_seconds,
        input.maximum_verified_braking_deceleration_meters_per_second_squared,
        input.uncertainty_buffer_meters or 0.0,
        input.surface_buffer_meters or 0.0,
        input.fixed_buffer_meters or 0.0
    )

    if stopping_distance == nil
        or not nonnegative(input.protective_radius_meters)
        or stopping_distance > input.protective_radius_meters then
        return result(
            "do_not_operate",
            { "protective_radius_does_not_cover_required_stopping_distance" }
        )
    end

    return result(
        "supervised_low_speed_only",
        {
            "non_identifying_protective_sensing_confirmed",
            "accessible_path_continuity_preserved",
            "human_supervision_required"
        },
        {
            required_stopping_distance_meters = stopping_distance,
            protective_radius_meters = input.protective_radius_meters,
            operating_context = input.operating_context
        }
    )
end

return MaintenanceBotSafety
