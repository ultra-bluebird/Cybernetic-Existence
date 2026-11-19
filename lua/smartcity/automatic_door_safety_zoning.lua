local DoorSafety = {}

local protected_zone_states = {
    obstruction_detected = true,
    protective_zone_occupied = true,
    sensor_unavailable = true,
    sensor_conflict = true,
    unknown = true
}

local function result(output_state, reasons, details)
    return {
        output_state = output_state,
        reason_codes = reasons or {},
        details = details or {},
        local_only = true,
        advisory_only = true,
        automated_actuation_authorized = false,
        person_assessment_performed = false,
        identity_resolution_performed = false,
        biometric_identification_performed = false,
        cybernetic_status_assessment_performed = false
    }
end

local function invalid(input)
    return type(input) ~= "table"
        or type(input.zone_states) ~= "table"
        or type(input.sensor_layers) ~= "table"
        or #input.sensor_layers == 0
end

local function sensor_health_requires_protective_mode(sensor)
    return sensor.health_state == "unavailable"
        or sensor.health_state == "conflicted"
        or sensor.health_state == "unknown"
        or sensor.alignment_state == "insufficient_evidence"
        or sensor.alignment_state == "unknown"
end

local function has_accessible_fallback(input)
    return input.accessible_non_contact_option_available == true
        and input.accessible_manual_fallback_available == true
end

function DoorSafety.evaluate(input)
    if invalid(input) then
        return result(
            "insufficient_evidence",
            { "door_safety_assessment_incomplete" }
        )
    end

    local zones = input.zone_states
    local reasons = {}
    local sensor_protective_mode = false

    for _, sensor in ipairs(input.sensor_layers) do
        if sensor_health_requires_protective_mode(sensor) then
            sensor_protective_mode = true
            table.insert(reasons, "sensor_health_or_alignment_requires_protective_mode")
            break
        end
    end

    if protected_zone_states[zones.zone_a_door_leaf] then
        return result(
            "reversal_recommended",
            {
                "door_leaf_zone_not_clear",
                "closure_not_authorized",
                "human_review_required"
            },
            {
                zone_a_state = zones.zone_a_door_leaf,
                accessible_fallback_available = has_accessible_fallback(input)
            }
        )
    end

    if protected_zone_states[zones.zone_b_near_door] then
        return result(
            "hold_open_recommended",
            {
                "near_door_zone_not_clear",
                "closure_not_authorized",
                "human_review_required"
            },
            {
                zone_b_state = zones.zone_b_near_door,
                accessible_fallback_available = has_accessible_fallback(input)
            }
        )
    end

    if zones.zone_d_environment == "fire_or_emergency_mode"
        or zones.zone_d_environment == "power_review"
        or zones.zone_d_environment == "sensor_unavailable"
        or zones.zone_d_environment == "unknown" then
        return result(
            "human_review_required",
            {
                "environmental_or_emergency_state_requires_safe_mode_review",
                "essential_access_continuity_required"
            },
            {
                zone_d_state = zones.zone_d_environment,
                accessible_fallback_available = has_accessible_fallback(input)
            }
        )
    end

    if sensor_protective_mode then
        return result(
            "fail_safe_open_recommended",
            reasons,
            {
                accessible_fallback_available = has_accessible_fallback(input)
            }
        )
    end

    if input.closure_speed_state == "outside_declared_safe_range"
        or input.closure_speed_state == "unknown" then
        return result(
            "slow_closure_recommended",
            {
                "closure_speed_requires_review",
                "human_review_required"
            },
            {
                closure_speed_state = input.closure_speed_state,
                accessible_fallback_available = has_accessible_fallback(input)
            }
        )
    end

    if not has_accessible_fallback(input) then
        return result(
            "human_review_required",
            {
                "accessible_non_contact_and_manual_fallback_required"
            },
            {
                accessible_fallback_available = false
            }
        )
    end

    if zones.zone_c_approach == "approach_detected" then
        return result(
            "preopen_recommended",
            {
                "approach_detected",
                "advisory_only_no_physical_action_authorized"
            },
            {
                accessible_fallback_available = true
            }
        )
    end

    return result(
        "human_review_required",
        {
            "door_state_clear_but_human_authority_and_local_safety_process_required"
        },
        {
            accessible_fallback_available = true
        }
    )
end

return DoorSafety
