local Interpolation = {}

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

local function unit_interval(value)
    return finite_number(value) and value >= 0.0 and value <= 1.0
end

local function result(output_state, reason_codes, values)
    return {
        output_state = output_state,
        reason_codes = reason_codes or {},
        values = values or {},
        evidence_state = "estimated",
        local_first = true,
        advisory_only = true,
        automated_action_authorized = false,
        automated_service_denial_authorized = false,
        person_assessment_performed = false,
        identity_resolution_performed = false,
        biometric_identification_performed = false,
        cybernetic_status_assessment_performed = false,
        individual_profiling_performed = false
    }
end

local function complement_product(values)
    local product = 1.0

    for _, value in ipairs(values) do
        if not unit_interval(value) then
            return nil
        end
        product = product * (1.0 - value)
    end

    return 1.0 - product
end

local function kernel_weight(distance, time_delta, spatial_scale, temporal_scale)
    if not nonnegative(distance)
        or not nonnegative(time_delta)
        or not positive(spatial_scale)
        or not positive(temporal_scale) then
        return nil
    end

    local spatial_weight = math.exp(
        -distance / spatial_scale
    )

    local temporal_weight = math.exp(
        -time_delta / temporal_scale
    )

    return spatial_weight * temporal_weight
end

function Interpolation.evaluate(input)
    if type(input) ~= "table"
        or type(input.measurements) ~= "table"
        or #input.measurements == 0 then
        return result(
            "insufficient_evidence",
            { "interpolation_measurements_missing" }
        )
    end

    if input.critical_safety_input == true
        or input.person_level_use_requested == true
        or input.requests_identity_resolution == true
        or input.requests_biometric_identification == true
        or input.requests_cybernetic_status_assessment == true
        or input.requests_service_eligibility == true
        or input.requests_automated_action == true then
        return result(
            "blocked_by_policy",
            { "interpolation_not_permitted_for_critical_or_person_level_use" }
        )
    end

    if not positive(input.maximum_spatial_support_meters)
        or not positive(input.maximum_temporal_support_seconds)
        or not positive(input.minimum_effective_source_count)
        or not positive(input.spatial_scale_meters)
        or not positive(input.temporal_scale_seconds)
        or not positive(input.epsilon)
        or not unit_interval(input.uncertainty_threshold) then
        return result(
            "insufficient_evidence",
            { "interpolation_profile_invalid" }
        )
    end

    if input.source_quality_state ~= "sufficient_for_declared_purpose"
        or input.source_alignment_state ~= "advisory_only"
        or input.source_freshness_state ~= "current"
        or input.source_provenance_state ~= "sufficient_for_declared_purpose" then
        return result(
            "needs_review",
            { "source_quality_alignment_freshness_or_provenance_requires_review" }
        )
    end

    local weighted_sum = 0.0
    local total_weight = 0.0
    local effective_count_numerator = 0.0
    local effective_count_denominator = 0.0
    local nearest_distance = nil
    local nearest_time = nil
    local uncertainty_values = {}

    for _, measurement in ipairs(input.measurements) do
        if type(measurement) ~= "table"
            or not finite_number(measurement.value)
            or not nonnegative(measurement.distance_meters)
            or not nonnegative(measurement.time_delta_seconds)
            or not unit_interval(measurement.quality)
            or type(measurement.uncertainty_components) ~= "table" then
            return result(
                "insufficient_evidence",
                { "interpolation_measurement_invalid" }
            )
        end

        if measurement.distance_meters > input.maximum_spatial_support_meters
            or measurement.time_delta_seconds > input.maximum_temporal_support_seconds then
            return result(
                "insufficient_evidence",
                { "measurement_outside_declared_interpolation_support" }
            )
        end

        local local_uncertainty = complement_product({
            measurement.uncertainty_components.measurement or 0.0,
            measurement.uncertainty_components.calibration or 0.0,
            measurement.uncertainty_components.alignment or 0.0,
            measurement.uncertainty_components.spatial or 0.0,
            measurement.uncertainty_components.temporal or 0.0,
            measurement.uncertainty_components.provenance or 0.0
        })

        if local_uncertainty == nil then
            return result(
                "insufficient_evidence",
                { "interpolation_uncertainty_component_invalid" }
            )
        end

        local weight = kernel_weight(
            measurement.distance_meters,
            measurement.time_delta_seconds,
            input.spatial_scale_meters,
            input.temporal_scale_seconds
        )

        if weight == nil then
            return result(
                "insufficient_evidence",
                { "interpolation_kernel_input_invalid" }
            )
        end

        local effective_weight = weight
            * measurement.quality
            * (1.0 - local_uncertainty)

        weighted_sum = weighted_sum
            + measurement.value * effective_weight

        total_weight = total_weight + effective_weight
        effective_count_numerator = effective_count_numerator + effective_weight
        effective_count_denominator = effective_count_denominator
            + effective_weight * effective_weight

        if nearest_distance == nil
            or measurement.distance_meters < nearest_distance then
            nearest_distance = measurement.distance_meters
        end

        if nearest_time == nil
            or measurement.time_delta_seconds < nearest_time then
            nearest_time = measurement.time_delta_seconds
        end

        table.insert(uncertainty_values, local_uncertainty)
    end

    if total_weight <= input.epsilon then
        return result(
            "insufficient_evidence",
            { "interpolation_effective_weight_zero" }
        )
    end

    local effective_source_count = 0.0
    if effective_count_denominator > 0.0 then
        effective_source_count = (
            effective_count_numerator * effective_count_numerator
        ) / effective_count_denominator
    end

    if effective_source_count < input.minimum_effective_source_count then
        return result(
            "insufficient_evidence",
            { "interpolation_effective_source_count_below_minimum" },
            {
                effective_source_count = effective_source_count,
                minimum_effective_source_count = input.minimum_effective_source_count
            }
        )
    end

    local interpolated_value = weighted_sum / total_weight
    local interpolation_uncertainty = complement_product(uncertainty_values)

    if interpolation_uncertainty == nil then
        return result(
            "insufficient_evidence",
            { "interpolation_uncertainty_aggregation_invalid" }
        )
    end

    local distance_factor = nearest_distance
        / input.maximum_spatial_support_meters

    local time_factor = nearest_time
        / input.maximum_temporal_support_seconds

    local support_uncertainty = math.max(
        distance_factor,
        time_factor
    )

    local total_uncertainty = complement_product({
        interpolation_uncertainty,
        support_uncertainty
    })

    if total_uncertainty == nil then
        return result(
            "insufficient_evidence",
            { "interpolation_total_uncertainty_invalid" }
        )
    end

    local values = {
        interpolated_value = interpolated_value,
        nearest_spatial_distance_meters = nearest_distance,
        nearest_temporal_distance_seconds = nearest_time,
        effective_source_count = effective_source_count,
        interpolation_uncertainty = interpolation_uncertainty,
        support_uncertainty = support_uncertainty,
        total_uncertainty = total_uncertainty,
        evidence_state = "estimated"
    }

    if total_uncertainty > input.uncertainty_threshold then
        return result(
            "needs_review",
            { "interpolation_uncertainty_exceeds_threshold" },
            values
        )
    end

    return result(
        "advisory_only",
        {
            "interpolated_value_is_estimate_not_measurement",
            "interpolation_within_declared_support_and_uncertainty_threshold"
        },
        values
    )
end

function Interpolation.render_accessible_explanation(assessment)
    local output_state = assessment.output_state or "needs_review"
    local reason_codes = table.concat(assessment.reason_codes or {}, ", ")

    return "Spatial-temporal interpolation result: " .. output_state .. ". "
        .. "The reported value is an estimate generated from nearby and recent "
        .. "measurements under a declared spatial-temporal model. "
        .. "It is not a direct measurement at the target location or time. "
        .. "The assessment retains distance, time support, source quality, "
        .. "calibration, alignment, freshness, provenance, and uncertainty conditions. "
        .. "It must not be used for safety-critical automation, person-level assessment, "
        .. "identity resolution, health inference, service eligibility, or cybernetic-status assessment. "
        .. "Reason codes: " .. reason_codes .. "."
end

return Interpolation
