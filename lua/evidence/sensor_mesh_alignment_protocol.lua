local SensorMesh = {}

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

local function result(output_state, reasons, values)
    return {
        output_state = output_state,
        reason_codes = reasons or {},
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

local function invalid_input(input)
    return type(input) ~= "table"
        or not nonnegative(input.relative_position_error_m)
        or not nonnegative(input.absolute_time_offset_ms)
        or not nonnegative(input.calibration_residual)
        or not nonnegative(input.feature_residual)
        or not positive(input.sigma_position_m)
        or not positive(input.sigma_time_ms)
        or not positive(input.sigma_calibration)
        or not positive(input.sigma_feature)
        or type(input.alignment_method_version) ~= "string"
        or input.alignment_method_version == ""
        or type(input.reference_method) ~= "string"
        or input.reference_method == ""
        or type(input.environmental_conditions) ~= "table"
end

local function environment_requires_review(environment)
    return environment.vibration_or_movement_state == "elevated"
        or environment.vibration_or_movement_state == "extreme"
        or environment.vibration_or_movement_state == "unknown"
        or environment.moisture_or_exposure_state == "elevated"
        or environment.moisture_or_exposure_state == "water_exposure"
        or environment.moisture_or_exposure_state == "dust_or_debris"
        or environment.moisture_or_exposure_state == "corrosion_risk"
        or environment.moisture_or_exposure_state == "unknown"
end

function SensorMesh.evaluate(input)
    if invalid_input(input) then
        return result(
            "insufficient_evidence",
            { "sensor_alignment_input_incomplete_or_invalid" }
        )
    end

    local exponent = -(
        input.relative_position_error_m / input.sigma_position_m
        + input.absolute_time_offset_ms / input.sigma_time_ms
        + input.calibration_residual / input.sigma_calibration
        + input.feature_residual / input.sigma_feature
    )

    local saqs = math.exp(exponent)

    local values = {
        sensor_alignment_quality_score = saqs,
        relative_offset_x_m = input.relative_offset_x_m,
        relative_offset_y_m = input.relative_offset_y_m,
        relative_offset_z_m = input.relative_offset_z_m,
        relative_position_error_m = input.relative_position_error_m,
        signed_time_offset_ms = input.signed_time_offset_ms,
        absolute_time_offset_ms = input.absolute_time_offset_ms,
        signed_calibration_residual = input.signed_calibration_residual,
        calibration_residual = input.calibration_residual,
        signed_feature_residual = input.signed_feature_residual,
        feature_residual = input.feature_residual,
        alignment_method_version = input.alignment_method_version,
        reference_method = input.reference_method,
        environmental_conditions = input.environmental_conditions
    }

    if saqs < 0.2 then
        return result(
            "insufficient_evidence",
            {
                "sensor_alignment_below_evidence_threshold",
                "do_not_fuse_for_consequential_planning"
            },
            values
        )
    end

    if saqs < 0.5 then
        return result(
            "needs_calibration",
            {
                "sensor_alignment_requires_calibration",
                "do_not_fuse_for_consequential_planning"
            },
            values
        )
    end

    if environment_requires_review(input.environmental_conditions) then
        return result(
            "needs_review",
            {
                "extreme_or_uncertain_environmental_conditions_require_alignment_review"
            },
            values
        )
    end

    if input.self_check_expired == true
        or input.persistent_directional_drift == true
        or input.mounting_change_detected == true
        or input.time_synchronization_failure == true then
        return result(
            "needs_calibration",
            {
                "alignment_event_triggered_review_required"
            },
            values
        )
    end

    return result(
        "advisory_only",
        {
            "sensor_alignment_usable_with_declared_uncertainty",
            "no_person_tracking_or_identity_assessment_performed"
        },
        values
    )
end

return SensorMesh
