local Fusion = {}

local valid_source_classes = {
    community_reported = true,
    calibrated_sensor = true,
    inspection_record = true,
    satellite_or_aerial_data = true,
    laboratory_test = true,
    public_dataset = true,
    validated_model_output = true,
    maintenance_record = true,
    ecological_survey = true
}

local incompatible_states = {
    unknown = true,
    unverified = true,
    insufficient_evidence = true
}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function unit_interval(value)
    return finite_number(value) and value >= 0.0 and value <= 1.0
end

local function nonnegative(value)
    return finite_number(value) and value >= 0.0
end

local function result(output_state, reason_codes, values)
    return {
        output_state = output_state,
        reason_codes = reason_codes or {},
        values = values or {},
        local_first = true,
        advisory_only = true,
        source_classes_preserved = true,
        source_uncertainties_preserved = true,
        source_provenance_preserved = true,
        person_assessment_performed = false,
        identity_resolution_performed = false,
        biometric_identification_performed = false,
        cybernetic_status_assessment_performed = false,
        automated_action_authorized = false
    }
end

local function valid_source(source)
    return type(source) == "table"
        and type(source.source_commitment) == "string"
        and source.source_commitment ~= ""
        and valid_source_classes[source.source_class] == true
        and type(source.declared_variable) == "string"
        and source.declared_variable ~= ""
        and type(source.unit) == "string"
        and source.unit ~= ""
        and unit_interval(source.quality_for_declared_purpose)
        and type(source.value_representation) == "string"
        and type(source.evidence_state) == "string"
        and type(source.uncertainty_method) == "string"
        and type(source.freshness_state) == "string"
        and type(source.provenance_state) == "string"
        and type(source.spatial_compatibility) == "string"
        and type(source.temporal_compatibility) == "string"
        and type(source.release_class) == "string"
end

local function source_requires_review(source)
    return incompatible_states[source.evidence_state] == true
        or source.evidence_state == "conflicted"
        or source.freshness_state == "expired"
        or source.freshness_state == "unknown"
        or source.provenance_state == "insufficient_evidence"
        or source.provenance_state == "conflicted"
        or source.spatial_compatibility == "incompatible"
        or source.spatial_compatibility == "unknown"
        or source.temporal_compatibility == "incompatible"
        or source.temporal_compatibility == "unknown"
end

local function source_is_numerically_fusable(source)
    return source.value_representation == "point_estimate"
        or source.value_representation == "interval"
end

local function independence_factor(source, sources, dependency_state)
    if dependency_state == "unknown" then
        return nil
    end

    if dependency_state == "shared_source"
        or dependency_state == "shared_model"
        or dependency_state == "common_cause_possible" then
        return 0.0
    end

    if dependency_state == "partially_correlated" then
        local correlation = source.maximum_absolute_correlation
        if not unit_interval(correlation) then
            return nil
        end
        return 1.0 - correlation
    end

    return 1.0
end

function Fusion.quality_weighted_independence_adjusted_mean(input)
    if type(input) ~= "table"
        or type(input.sources) ~= "table"
        or #input.sources == 0
        or not nonnegative(input.epsilon)
        or input.epsilon == 0.0 then
        return result(
            "insufficient_evidence",
            { "fusion_input_incomplete" }
        )
    end

    if input.requests_person_assessment == true
        or input.requests_identity_resolution == true
        or input.requests_biometric_identification == true
        or input.requests_cybernetic_status_assessment == true
        or input.requests_surveillance == true
        or input.requests_automated_action == true then
        return result(
            "blocked_by_policy",
            { "fusion_cannot_assess_people_or_authorize_action" }
        )
    end

    if input.dependency_state == "unknown" then
        return result(
            "needs_review",
            { "source_dependency_unknown_no_numeric_fusion" }
        )
    end

    if input.conflict_detected == true then
        return result(
            "conflicted",
            {
                "material_source_disagreement_preserved",
                "preserve_both_require_review"
            },
            {
                fusion_method = "conflict_preserving_no_numeric_fusion"
            }
        )
    end

    local numerator = 0.0
    local denominator = 0.0
    local source_summary = {}

    for _, source in ipairs(input.sources) do
        if not valid_source(source) then
            return result(
                "insufficient_evidence",
                { "source_record_invalid" }
            )
        end

        if source_requires_review(source) then
            return result(
                "needs_review",
                {
                    "source_requires_review_before_numeric_fusion",
                    source.source_class
                }
            )
        end

        if not source_is_numerically_fusable(source) then
            return result(
                "needs_review",
                {
                    "qualitative_or_categorical_source_requires_hybrid_or_lattice_fusion",
                    source.source_class
                }
            )
        end

        if not finite_number(source.value) then
            return result(
                "insufficient_evidence",
                { "numeric_source_value_missing_or_invalid" }
            )
        end

        local class_weight = source.governance_weight
        if not unit_interval(class_weight) then
            return result(
                "insufficient_evidence",
                { "source_governance_weight_invalid" }
            )
        end

        local independence = independence_factor(
            source,
            input.sources,
            input.dependency_state
        )

        if independence == nil then
            return result(
                "needs_review",
                { "source_independence_factor_not_declared" }
            )
        end

        local effective_weight = class_weight
            * source.quality_for_declared_purpose
            * independence

        numerator = numerator + effective_weight * source.value
        denominator = denominator + effective_weight

        table.insert(source_summary, {
            source_class = source.source_class,
            evidence_state = source.evidence_state,
            value_representation = source.value_representation,
            quality_for_declared_purpose = source.quality_for_declared_purpose,
            governance_weight = class_weight,
            independence_factor = independence,
            uncertainty_method = source.uncertainty_method,
            freshness_state = source.freshness_state,
            provenance_state = source.provenance_state
        })
    end

    if denominator <= input.epsilon then
        return result(
            "insufficient_evidence",
            { "fusion_effective_weight_is_zero" }
        )
    end

    local fused_value = numerator / denominator

    return result(
        "advisory_only",
        {
            "quality_weighted_independence_adjusted_fusion_complete",
            "source_classes_uncertainty_and_provenance_preserved"
        },
        {
            fused_value = fused_value,
            fusion_method = "quality_weighted_independence_adjusted_mean",
            source_summary = source_summary
        }
    )
end

function Fusion.evaluate_sensor_community_disagreement(input)
    if type(input) ~= "table"
        or type(input.sensor_source) ~= "table"
        or type(input.community_source) ~= "table" then
        return result(
            "insufficient_evidence",
            { "sensor_community_comparison_input_missing" }
        )
    end

    local sensor = input.sensor_source
    local community = input.community_source

    if not valid_source(sensor) or not valid_source(community) then
        return result(
            "insufficient_evidence",
            { "sensor_or_community_source_invalid" }
        )
    end

    if sensor.source_class ~= "calibrated_sensor"
        or community.source_class ~= "community_reported" then
        return result(
            "needs_review",
            { "comparison_requires_sensor_and_community_evidence_classes" }
        )
    end

    if sensor.declared_variable ~= community.declared_variable
        or sensor.unit ~= community.unit
        or sensor.spatial_compatibility ~= "compatible"
        or community.spatial_compatibility ~= "compatible"
        or sensor.temporal_compatibility ~= "compatible"
        or community.temporal_compatibility ~= "compatible" then
        return result(
            "advisory_only",
            {
                "sensor_and_community_records_are_complementary_not_numerically_comparable",
                "preserve_both_for_distinct_metric_inputs"
            },
            {
                sensor_variable = sensor.declared_variable,
                community_variable = community.declared_variable
            }
        )
    end

    if not finite_number(sensor.value)
        or not finite_number(community.value)
        or not nonnegative(input.conflict_threshold) then
        return result(
            "insufficient_evidence",
            { "comparable_source_value_or_conflict_threshold_missing" }
        )
    end

    local difference = math.abs(sensor.value - community.value)

    if difference > input.conflict_threshold then
        local reasons = {
            "material_sensor_community_disagreement",
            "preserve_both_require_review"
        }

        if community.observation_severity == "high"
            and community.plausible_public_harm == true then
            table.insert(reasons, "priority_review_for_high_severity_community_observation")
        end

        return result(
            "conflicted",
            reasons,
            {
                sensor_value = sensor.value,
                community_value = community.value,
                absolute_difference = difference
            }
        )
    end

    return result(
        "advisory_only",
        {
            "sensor_and_community_evidence_compatible_for_declared_comparison"
        },
        {
            absolute_difference = difference
        }
    )
end

function Fusion.render_accessible_explanation(assessment)
    local state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Evidence fusion result: " .. state .. ". "
        .. "This result preserves the source type, uncertainty, freshness, provenance, "
        .. "and conflict state for each contributing record. "
        .. "Community reports, sensor observations, inspections, and model outputs remain "
        .. "distinct forms of evidence and are not treated as interchangeable. "
        .. "No person, identity, health condition, disability, assistive technology, "
        .. "augmentation status, or cybernetic status is assessed. "
        .. "No automated action or service decision is authorized. "
        .. "Reason codes: " .. reasons .. "."
end

return Fusion
