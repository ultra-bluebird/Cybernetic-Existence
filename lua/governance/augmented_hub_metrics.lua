local Metrics = {}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function in_unit_interval(value)
    return finite_number(value) and value >= 0.0 and value <= 1.0
end

local function nonnegative(value)
    return finite_number(value) and value >= 0.0
end

local function positive(value)
    return finite_number(value) and value > 0.0
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function result(output_class, reason_codes, values)
    return {
        output_class = output_class,
        reason_codes = reason_codes or {},
        values = values or {},
        advisory_only = true,
        automated_action_authorized = false,
        person_assessment_performed = false,
        identity_resolution_performed = false,
        biometric_identification_performed = false,
        cybernetic_status_assessment_performed = false
    }
end

local function insufficient(reason_code, values)
    return result("insufficient_evidence", { reason_code }, values)
end

local function needs_review(reason_code, values)
    return result("needs_review", { reason_code }, values)
end

local function blocked(reason_code, values)
    return result("blocked_by_policy", { reason_code }, values)
end

local function product_of_complements(values)
    local product = 1.0

    for _, value in ipairs(values) do
        if not in_unit_interval(value) then
            return nil
        end
        product = product * (1.0 - value)
    end

    return 1.0 - product
end

local function geometric_mean(values, weights)
    if #values == 0 or #values ~= #weights then
        return nil
    end

    local total_weight = 0.0
    local log_sum = 0.0

    for index, value in ipairs(values) do
        local weight = weights[index]

        if not in_unit_interval(value) or not nonnegative(weight) then
            return nil
        end

        if value == 0.0 and weight > 0.0 then
            return 0.0
        end

        if weight > 0.0 then
            log_sum = log_sum + weight * math.log(value)
        end

        total_weight = total_weight + weight
    end

    if math.abs(total_weight - 1.0) > 0.000001 then
        return nil
    end

    return math.exp(log_sum)
end

function Metrics.validate_metric_governance(metric)
    if type(metric) ~= "table" then
        return blocked("metric_definition_missing")
    end

    local governance = metric.governance
    local review = metric.review

    if type(governance) ~= "table" or type(review) ~= "table" then
        return blocked("metric_governance_or_review_missing")
    end

    if governance.advisory_only ~= true then
        return blocked("metric_must_be_advisory_only")
    end

    if governance.automated_actuation_permitted ~= false then
        return blocked("automated_actuation_not_permitted")
    end

    if governance.automated_service_denial_permitted ~= false then
        return blocked("automated_service_denial_not_permitted")
    end

    if governance.biometric_identification_permitted ~= false then
        return blocked("biometric_identification_not_permitted")
    end

    if governance.cybernetic_status_penalty_permitted ~= false then
        return blocked("cybernetic_status_penalty_not_permitted")
    end

    if governance.individual_profiling_permitted ~= false then
        return blocked("individual_profiling_not_permitted")
    end

    if review.accessible_explanation_required ~= true then
        return blocked("accessible_explanation_required")
    end

    if review.human_review_required ~= true then
        return blocked("human_review_required")
    end

    if review.appeal_path_required ~= true then
        return blocked("appeal_path_required")
    end

    if review.non_digital_escalation_required ~= true then
        return blocked("non_digital_escalation_required")
    end

    return result("advisory_only", { "metric_governance_conformant" })
end

function Metrics.calculate_maintenance_condition(input)
    if type(input) ~= "table" then
        return insufficient("maintenance_input_missing")
    end

    local c0 = input.baseline_condition
    local lambda_base = input.base_degradation_rate_per_day
    local phi = input.post_expiry_priority_rate_per_day
    local lambda_fresh = input.freshness_decay_rate_per_day
    local age_since_baseline = input.age_since_baseline_days
    local inspection_age = input.inspection_age_days
    local inspection_validity = input.inspection_validity_days
    local calibration_quality = input.calibration_quality
    local coverage_quality = input.coverage_quality

    if not in_unit_interval(c0)
        or not nonnegative(lambda_base)
        or not nonnegative(phi)
        or not nonnegative(lambda_fresh)
        or not nonnegative(age_since_baseline)
        or not nonnegative(inspection_age)
        or not positive(inspection_validity)
        or not in_unit_interval(calibration_quality)
        or not in_unit_interval(coverage_quality) then
        return insufficient("maintenance_input_invalid")
    end

    if calibration_quality == 0.0 or coverage_quality == 0.0 then
        return insufficient("maintenance_input_zero_quality")
    end

    local overdue_days = math.max(
        0.0,
        inspection_age - inspection_validity
    )

    local estimated_condition = clamp(
        c0
            * math.exp(-lambda_base * age_since_baseline)
            * math.max(0.0, 1.0 - phi * overdue_days),
        0.0,
        1.0
    )

    local inspection_freshness = 1.0
    if overdue_days > 0.0 then
        inspection_freshness = math.exp(-lambda_fresh * overdue_days)
    end

    local composite_quality = estimated_condition
        * inspection_freshness
        * calibration_quality
        * coverage_quality

    local values = {
        estimated_condition = estimated_condition,
        inspection_freshness = inspection_freshness,
        composite_quality = composite_quality,
        inspection_age_days = inspection_age,
        inspection_validity_days = inspection_validity,
        overdue_days = overdue_days
    }

    if inspection_age > 2.0 * inspection_validity then
        return insufficient("inspection_expired_beyond_evidence_limit", values)
    end

    if inspection_age > inspection_validity or input.event_triggered_review == true then
        return needs_review("maintenance_inspection_requires_review", values)
    end

    return result("advisory_only", {
        "maintenance_condition_estimate_available"
    }, values)
end

function Metrics.calculate_provenance_completeness(input)
    if type(input) ~= "table"
        or type(input.components) ~= "table"
        or type(input.weights) ~= "table" then
        return insufficient("provenance_input_missing")
    end

    local required_components = {
        "creator_identity_or_role",
        "collection_method",
        "collection_time",
        "transformation_history",
        "validation_status",
        "policy_version",
        "source_license_or_authority"
    }

    local values = {}
    local weights = {}
    local component_values = {}

    for _, name in ipairs(required_components) do
        local component = input.components[name]
        local weight = input.weights[name]

        if not in_unit_interval(component) or not nonnegative(weight) then
            return insufficient("provenance_component_or_weight_invalid")
        end

        component_values[name] = component
        table.insert(values, component)
        table.insert(weights, weight)
    end

    local pcc = geometric_mean(values, weights)
    if pcc == nil then
        return insufficient("provenance_weights_must_sum_to_one")
    end

    local critical = input.critical_components or {}
    for _, name in ipairs(critical) do
        local value = component_values[name]
        if value == nil or value <= 0.0 then
            return insufficient("critical_provenance_component_missing", {
                provenance_completeness = pcc,
                critical_component = name
            })
        end
    end

    local output_values = {
        provenance_completeness = pcc,
        component_values = component_values
    }

    if pcc < 0.2 then
        return insufficient("provenance_completeness_below_minimum", output_values)
    end

    if pcc < 0.5 then
        return needs_review("provenance_completeness_requires_review", output_values)
    end

    return result("advisory_only", {
        "provenance_sufficient_for_declared_purpose",
        "provenance_is_not_truth_verification"
    }, output_values)
end

function Metrics.calculate_sensor_alignment_quality(input)
    if type(input) ~= "table" then
        return insufficient("sensor_alignment_input_missing")
    end

    local required = {
        input.relative_offset_m,
        input.absolute_time_offset_ms,
        input.absolute_calibration_residual,
        input.absolute_feature_residual,
        input.sigma_position_m,
        input.sigma_time_ms,
        input.sigma_calibration,
        input.sigma_feature
    }

    for _, value in ipairs(required) do
        if not nonnegative(value) then
            return insufficient("sensor_alignment_input_invalid")
        end
    end

    if not positive(input.sigma_position_m)
        or not positive(input.sigma_time_ms)
        or not positive(input.sigma_calibration)
        or not positive(input.sigma_feature) then
        return insufficient("sensor_alignment_tolerance_invalid")
    end

    if type(input.alignment_method_version) ~= "string"
        or input.alignment_method_version == "" then
        return insufficient("alignment_method_version_missing")
    end

    local exponent = -(
        input.relative_offset_m / input.sigma_position_m
        + input.absolute_time_offset_ms / input.sigma_time_ms
        + input.absolute_calibration_residual / input.sigma_calibration
        + input.absolute_feature_residual / input.sigma_feature
    )

    local score = math.exp(exponent)

    local values = {
        sensor_alignment_quality_score = score,
        relative_offset_x_m = input.relative_offset_x_m,
        relative_offset_y_m = input.relative_offset_y_m,
        relative_offset_z_m = input.relative_offset_z_m,
        relative_offset_m = input.relative_offset_m,
        signed_time_offset_ms = input.signed_time_offset_ms,
        absolute_time_offset_ms = input.absolute_time_offset_ms,
        signed_calibration_residual = input.signed_calibration_residual,
        absolute_calibration_residual = input.absolute_calibration_residual,
        signed_feature_residual = input.signed_feature_residual,
        absolute_feature_residual = input.absolute_feature_residual,
        alignment_method_version = input.alignment_method_version
    }

    if score < 0.2 then
        return insufficient("sensor_alignment_below_evidence_threshold", values)
    end

    if score < 0.5 then
        return needs_review("sensor_alignment_needs_calibration", values)
    end

    return result("advisory_only", {
        "sensor_alignment_usable_with_uncertainty"
    }, values)
end

function Metrics.calculate_uncertainty_chain(input)
    if type(input) ~= "table"
        or type(input.steps) ~= "table"
        or #input.steps == 0 then
        return insufficient("uncertainty_chain_steps_missing")
    end

    if not in_unit_interval(input.chain_threshold)
        or not in_unit_interval(input.epistemic_threshold) then
        return insufficient("uncertainty_threshold_invalid")
    end

    if input.dependency_declaration ~= "independent" then
        return needs_review("uncertainty_dependency_requires_declared_hybrid_method", {
            dependency_declaration = input.dependency_declaration
        })
    end

    local step_uncertainties = {}
    local epistemic_uncertainties = {}
    local aleatoric_uncertainties = {}

    for _, step in ipairs(input.steps) do
        if step.evidence_state == "conflicted" then
            return result("conflicted", {
                "upstream_step_conflicted",
                "preserve_both_require_review"
            }, {
                metric_name = step.metric_name
            })
        end

        if step.evidence_state == "unknown"
            or step.evidence_state == "unverified"
            or step.evidence_state == "insufficient_evidence" then
            return insufficient("upstream_step_insufficient_evidence", {
                metric_name = step.metric_name
            })
        end

        local components = step.components
        if type(components) ~= "table" then
            return insufficient("uncertainty_components_missing")
        end

        local all = {
            components.measurement or 0.0,
            components.calibration or 0.0,
            components.spatial or 0.0,
            components.temporal or 0.0,
            components.model or 0.0,
            components.parameter or 0.0,
            components.scenario or 0.0,
            components.provenance or 0.0,
            components.coverage or 0.0,
            components.conflict or 0.0,
            components.environmental_variability or 0.0,
            components.process_variability or 0.0
        }

        local epistemic = {
            components.calibration or 0.0,
            components.spatial or 0.0,
            components.temporal or 0.0,
            components.model or 0.0,
            components.parameter or 0.0,
            components.scenario or 0.0,
            components.provenance or 0.0,
            components.coverage or 0.0,
            components.conflict or 0.0
        }

        local aleatoric = {
            components.measurement or 0.0,
            components.environmental_variability or 0.0,
            components.process_variability or 0.0
        }

        local total = product_of_complements(all)
        local epistemic_total = product_of_complements(epistemic)
        local aleatoric_total = product_of_complements(aleatoric)

        if total == nil
            or epistemic_total == nil
            or aleatoric_total == nil then
            return insufficient("uncertainty_component_out_of_range")
        end

        table.insert(step_uncertainties, total)
        table.insert(epistemic_uncertainties, epistemic_total)
        table.insert(aleatoric_uncertainties, aleatoric_total)
    end

    local chain_uncertainty = product_of_complements(step_uncertainties)
    local epistemic_uncertainty = product_of_complements(epistemic_uncertainties)
    local aleatoric_uncertainty = product_of_complements(aleatoric_uncertainties)

    local values = {
        chain_uncertainty = chain_uncertainty,
        epistemic_uncertainty = epistemic_uncertainty,
        aleatoric_uncertainty = aleatoric_uncertainty,
        step_count = #input.steps
    }

    if chain_uncertainty > input.chain_threshold then
        return needs_review("chain_uncertainty_exceeds_threshold", values)
    end

    if epistemic_uncertainty > input.epistemic_threshold then
        return needs_review("epistemic_uncertainty_exceeds_threshold", values)
    end

    return result("advisory_only", {
        "uncertainty_chain_within_declared_thresholds"
    }, values)
end

function Metrics.calculate_electronic_conversion_efficiency(input)
    if type(input) ~= "table" then
        return insufficient("energy_conversion_input_missing")
    end

    if not nonnegative(input.energy_useful_kwh)
        or not positive(input.energy_available_kwh)
        or not in_unit_interval(input.capture_efficiency)
        or not nonnegative(input.degradation_coefficient)
        or not in_unit_interval(input.condition_degradation)
        or not positive(input.epsilon) then
        return insufficient("energy_conversion_input_invalid")
    end

    if input.measurement_period_matches ~= true
        or input.system_boundary_matches ~= true then
        return insufficient("energy_conversion_boundary_or_period_mismatch")
    end

    local degradation_factor = 1.0 / (
        1.0 + input.degradation_coefficient * input.condition_degradation
    )

    local raw_ratio = (
        input.energy_useful_kwh
        / math.max(input.energy_available_kwh, input.epsilon)
    ) * degradation_factor

    local efficiency = clamp(raw_ratio, 0.0, 1.0)

    local expected_output = input.capture_efficiency
        * input.energy_available_kwh
        * degradation_factor

    local model_residual = math.abs(
        input.energy_useful_kwh - expected_output
    ) / math.max(expected_output, input.epsilon)

    local values = {
        ecer_raw = raw_ratio,
        electronic_conversion_efficiency_ratio = efficiency,
        expected_output_kwh = expected_output,
        conversion_model_residual = model_residual
    }

    if raw_ratio > 1.0 then
        return needs_review("energy_conversion_ratio_above_physical_boundary", values)
    end

    if input.requests_net_positive_ecological_claim == true
        and input.lifecycle_inventory_complete ~= true then
        return blocked("lifecycle_inventory_required_for_ecological_claim", values)
    end

    return result("advisory_only", {
        "energy_conversion_estimate_available",
        "not_a_service_access_or_eligibility_metric"
    }, values)
end

function Metrics.calculate_automation_safety_margin(input)
    if type(input) ~= "table"
        or type(input.conditions) ~= "table"
        or #input.conditions == 0 then
        return insufficient("automation_safety_conditions_missing")
    end

    if input.hazardous_action == true
        and input.human_proximity_state == "unknown" then
        return result("fail_safe_mode", {
            "human_proximity_unknown_for_hazardous_action"
        }, {
            automation_state = "fail_safe_mode"
        })
    end

    if input.human_proximity_state == "protective_zone"
        or input.human_proximity_state == "contact_zone" then
        return result("reduce_automation", {
            "person_in_protective_zone"
        }, {
            automation_state = "reduce_automation"
        })
    end

    local protected_margin = 1.0
    local per_condition = {}

    for _, condition in ipairs(input.conditions) do
        if not nonnegative(condition.distance_to_safe_boundary)
            or not positive(condition.design_distance)
            or not in_unit_interval(condition.uncertainty)
            or not in_unit_interval(condition.severity) then
            return insufficient("automation_safety_condition_invalid")
        end

        local margin = clamp(
            condition.distance_to_safe_boundary
                / math.max(condition.design_distance, input.epsilon or 0.000001),
            0.0,
            1.0
        )

        local protected = margin
            * (1.0 - condition.uncertainty)
            * (1.0 - condition.severity)

        table.insert(per_condition, {
            condition_name = condition.condition_name,
            raw_margin = margin,
            protected_margin = protected,
            uncertainty = condition.uncertainty,
            severity = condition.severity
        })

        if protected < protected_margin then
            protected_margin = protected
        end
    end

    local values = {
        automation_safety_margin_index = protected_margin,
        per_condition = per_condition
    }

    if protected_margin < 0.1 then
        values.automation_state = "fail_safe_mode"
        return result("fail_safe_mode", {
            "automation_safety_margin_below_fail_safe_threshold"
        }, values)
    end

    if protected_margin < 0.3 then
        values.automation_state = "reduce_automation"
        return result("reduce_automation", {
            "automation_safety_margin_below_reduce_automation_threshold"
        }, values)
    end

    if input.accessibility_pass ~= true
        or input.rights_alignment_pass ~= true
        or input.human_review_complete ~= true then
        values.automation_state = "reduce_automation"
        return needs_review("protected_gate_not_complete_for_bounded_automation", values)
    end

    values.automation_state = "bounded_automation_eligible"

    return result("advisory_only", {
        "bounded_automation_eligibility_is_advisory_only",
        "no_physical_action_authorized"
    }, values)
end

function Metrics.select_minimum_disclosure(input)
    if type(input) ~= "table"
        or type(input.task_profile) ~= "string"
        or type(input.requirements) ~= "table"
        or type(input.transformations) ~= "table" then
        return insufficient("minimum_disclosure_input_missing")
    end

    local prohibited = input.requires_person_assessment == true
        or input.requires_identity_resolution == true
        or input.requires_biometric_identification == true
        or input.requires_cybernetic_status_assessment == true
        or input.requires_service_eligibility_decision == true

    if prohibited then
        return blocked("prohibited_sensitive_or_eligibility_use")
    end

    local ordered = {
        "yes_no_advisory",
        "categorical_band",
        "interval_estimate",
        "point_estimate_with_uncertainty",
        "raw_record"
    }

    for _, transformation_name in ipairs(ordered) do
        local transform = input.transformations[transformation_name]

        if type(transform) == "table" then
            local adequate = true

            for requirement_name, requirement_value in pairs(input.requirements) do
                local retained = transform.information_dimensions
                    and transform.information_dimensions[requirement_name]

                if retained == nil or retained < requirement_value then
                    adequate = false
                    break
                end
            end

            if adequate then
                if transformation_name == "raw_record"
                    and (
                        input.local_only ~= true
                        or input.purpose_specific_authorization ~= true
                        or input.human_review_complete ~= true
                    ) then
                    return needs_review(
                        "raw_record_requires_local_purpose_specific_review"
                    )
                end

                return result("advisory_only", {
                    "least_sensitive_adequate_transformation_selected"
                }, {
                    selected_transformation = transformation_name,
                    task_profile = input.task_profile
                })
            end
        end
    end

    return needs_review("no_available_transformation_is_adequate")
end

function Metrics.evaluate_sensitive_inference_boundary(input)
    if type(input) ~= "table" then
        return insufficient("sensitive_inference_input_missing")
    end

    if input.intentional_sensitive_inference == true then
        return blocked("intentional_sensitive_inference_prohibited")
    end

    if input.contains_person_linked_data == true
        or input.contains_precise_mobility_data == true
        or input.contains_individual_usage_patterns == true then
        return result("local_only", {
            "person_linked_or_precise_pattern_data_requires_local_only"
        })
    end

    if input.inference_risk == nil then
        return needs_review("incidental_inference_risk_not_assessed")
    end

    if not in_unit_interval(input.inference_risk)
        or not in_unit_interval(input.inference_threshold) then
        return insufficient("inference_risk_or_threshold_invalid")
    end

    if input.inference_risk > input.inference_threshold then
        return result("local_only", {
            "incidental_sensitive_inference_risk_requires_review"
        }, {
            inference_risk = input.inference_risk,
            inference_threshold = input.inference_threshold
        })
    end

    return result("advisory_only", {
        "no_detected_inference_risk_above_declared_threshold"
    }, {
        inference_risk = input.inference_risk,
        inference_threshold = input.inference_threshold
    })
end

function Metrics.render_accessible_explanation(assessment)
    local output_class = assessment.output_class or "needs_review"
    local reasons = assessment.reason_codes or {}
    local reason_text = table.concat(reasons, ", ")

    return "Result: " .. output_class .. ". "
        .. "This is an advisory, local-first assessment. "
        .. "It does not assess a person, identity, health condition, disability, "
        .. "assistive technology, augmentation status, or cybernetic status. "
        .. "No automated service decision or physical action is authorized. "
        .. "Reason codes: " .. reason_text .. ". "
        .. "Accessible human review and non-digital escalation remain available."
end

return Metrics
