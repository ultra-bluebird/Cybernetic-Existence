local Anomaly = {}

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

local function sorted_copy(values)
    local copy = {}

    for index, value in ipairs(values) do
        if not finite_number(value) then
            return nil
        end
        copy[index] = value
    end

    table.sort(copy)

    return copy
end

local function median(values)
    local sorted = sorted_copy(values)
    if sorted == nil or #sorted == 0 then
        return nil
    end

    local count = #sorted
    local middle = math.floor((count + 1) / 2)

    if count % 2 == 1 then
        return sorted[middle]
    end

    return (sorted[middle] + sorted[middle + 1]) / 2.0
end

local function mad(values, center)
    if not finite_number(center) then
        return nil
    end

    local deviations = {}

    for index, value in ipairs(values) do
        if not finite_number(value) then
            return nil
        end
        deviations[index] = math.abs(value - center)
    end

    return median(deviations)
end

function Anomaly.robust_score(observed_value, baseline_values, epsilon)
    if not finite_number(observed_value)
        or type(baseline_values) ~= "table"
        or #baseline_values == 0
        or not positive(epsilon) then
        return nil
    end

    local center = median(baseline_values)
    local median_absolute_deviation = mad(baseline_values, center)

    if center == nil or median_absolute_deviation == nil then
        return nil
    end

    local robust_scale = 1.4826 * median_absolute_deviation
    local score = math.abs(
        (observed_value - center)
        / math.max(robust_scale, epsilon)
    )

    return {
        score = score,
        robust_center = center,
        robust_scale = robust_scale,
        median_absolute_deviation = median_absolute_deviation
    }
end

function Anomaly.evaluate(input)
    if type(input) ~= "table"
        or not finite_number(input.observed_value)
        or type(input.baseline_values) ~= "table"
        or #input.baseline_values < (input.minimum_baseline_sample_count or 1)
        or not positive(input.epsilon)
        or not nonnegative(input.anomaly_threshold)
        or not nonnegative(input.priority_review_threshold)
        or not unit_interval(input.evidence_quality) then
        return result(
            "insufficient_evidence",
            { "anomaly_detection_input_incomplete_or_invalid" }
        )
    end

    if input.requests_person_assessment == true
        or input.requests_identity_resolution == true
        or input.requests_biometric_identification == true
        or input.requests_cybernetic_status_assessment == true
        or input.requests_service_eligibility == true
        or input.requests_automated_adverse_action == true
        or input.requests_automated_actuation == true then
        return result(
            "blocked_by_policy",
            { "anomaly_detection_prohibited_for_person_or_adverse_action_use" }
        )
    end

    if input.units_compatible ~= true
        or input.spatial_temporal_scope_compatible ~= true
        or input.calibration_state ~= "current"
        or input.freshness_state ~= "current"
        or input.provenance_state ~= "sufficient_for_declared_purpose" then
        return result(
            "insufficient_evidence",
            {
                "anomaly_not_interpretable_without_compatible_current_calibrated_provenance_sufficient_evidence"
            }
        )
    end

    if input.sensor_alignment_state ~= nil
        and input.sensor_alignment_state ~= "advisory_only" then
        return result(
            "needs_review",
            { "sensor_alignment_requires_review_before_anomaly_interpretation" }
        )
    end

    if input.material_conflict_detected == true then
        return result(
            "conflicted",
            {
                "material_evidence_conflict_preserved",
                "preserve_both_require_review"
            }
        )
    end

    local robust = Anomaly.robust_score(
        input.observed_value,
        input.baseline_values,
        input.epsilon
    )

    if robust == nil then
        return result(
            "insufficient_evidence",
            { "robust_baseline_calculation_failed" }
        )
    end

    local values = {
        statistical_anomaly_score = robust.score,
        robust_center = robust.robust_center,
        robust_scale = robust.robust_scale,
        median_absolute_deviation = robust.median_absolute_deviation,
        evidence_quality = input.evidence_quality,
        evidence_uncertainty = 1.0 - input.evidence_quality,
        anomaly_interpretation = "statistical_difference_from_recent_pattern_not_causation"
    }

    if input.evidence_quality == 0.0 then
        return result(
            "insufficient_evidence",
            { "evidence_quality_zero_anomaly_cannot_be_interpreted" },
            values
        )
    end

    if robust.score >= input.priority_review_threshold
        and input.plausible_public_or_ecological_harm == true then
        return result(
            "needs_review",
            {
                "high_statistical_anomaly_requires_priority_human_review",
                "review_method_weather_flow_instrument_and_context"
            },
            values
        )
    end

    if robust.score >= input.anomaly_threshold then
        return result(
            "needs_review",
            {
                "statistical_anomaly_detected",
                "review_method_weather_flow_instrument_and_context"
            },
            values
        )
    end

    return result(
        "advisory_only",
        {
            "within_declared_recent_pattern",
            "not_a_causation_or_safety_determination"
        },
        values
    )
end

function Anomaly.render_accessible_explanation(assessment)
    local output_state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Anomaly review result: " .. output_state .. ". "
        .. "This assessment compares a value with a declared recent pattern using robust statistics. "
        .. "It does not determine cause, contamination, equipment failure, danger, misconduct, "
        .. "or an individual's condition. "
        .. "Review the method, calibration, alignment, weather, flow, maintenance state, "
        .. "and compatible observations before making a physical conclusion. "
        .. "No automated service decision, physical action, identity assessment, or cybernetic-status assessment is authorized. "
        .. "Reason codes: " .. reasons .. "."
end

return Anomaly
