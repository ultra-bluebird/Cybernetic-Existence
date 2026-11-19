local NonPenalty = {}

local prohibited_inputs = {
    cybernetic_status_used_as_input = true,
    self_asserted_status_used_for_penalty = true,
    external_status_record_used_for_penalty = true,
    device_identifier_used_as_proxy = true,
    assistive_technology_used_as_proxy = true,
    appearance_or_gait_used_as_proxy = true,
    behavior_or_movement_pattern_used_as_proxy = true,
    biometric_data_used_as_proxy = true,
    neural_or_health_data_used_as_proxy = true,
    inference_attempt_performed = true
}

local required_outcomes = {
    "access_non_penalty",
    "service_quality_non_penalty",
    "privacy_non_penalty",
    "timeliness_non_penalty",
    "explanation_non_penalty",
    "appeal_non_penalty",
    "accessibility_non_penalty",
    "non_retaliation_non_penalty",
    "safety_non_penalty",
    "service_continuity_non_penalty"
}

local function result(output_state, reason_codes, values)
    return {
        output_state = output_state,
        reason_codes = reason_codes or {},
        values = values or {},
        local_first = true,
        self_assertion_protective_use_available = true,
        external_certification_required = false,
        biometric_identification_required = false,
        cybernetic_status_penalty_permitted = false,
        automated_service_denial_permitted = false,
        person_assessment_performed = false,
        identity_resolution_performed = false,
        augmentation_or_cybernetic_status_assessment_performed = false
    }
end

local function has_prohibited_input(input_review)
    if type(input_review) ~= "table" then
        return true, "decision_input_review_missing"
    end

    for field_name, _ in pairs(prohibited_inputs) do
        if input_review[field_name] == true then
            return true, field_name
        end
    end

    return false, nil
end

local function all_outcomes_protected(outcome_review)
    if type(outcome_review) ~= "table" then
        return false, "outcome_protection_review_missing"
    end

    for _, field_name in ipairs(required_outcomes) do
        if outcome_review[field_name] ~= true then
            return false, field_name
        end
    end

    return true, nil
end

function NonPenalty.evaluate(input)
    if type(input) ~= "table" then
        return result(
            "insufficient_evidence",
            { "non_penalty_assessment_missing" }
        )
    end

    if input.external_certification_required == true
        or input.biometric_identification_required == true
        or input.cybernetic_status_penalty_permitted == true
        or input.automated_service_denial_permitted == true then
        return result(
            "blocked_by_policy",
            { "status_protection_configuration_violates_non_penalty_invariant" }
        )
    end

    if input.self_assertion_protective_use_available ~= true then
        return result(
            "blocked_by_policy",
            { "self_assertion_for_protective_purposes_required" }
        )
    end

    local prohibited, input_reason = has_prohibited_input(
        input.decision_input_review
    )

    if prohibited then
        return result(
            "blocked_by_policy",
            {
                "cybernetic_status_or_proxy_input_prohibited",
                input_reason
            }
        )
    end

    if type(input.inference_boundary_review) ~= "table" then
        return result(
            "needs_review",
            { "inference_boundary_review_required" }
        )
    end

    if input.inference_boundary_review.person_linked_data_present == true
        or input.inference_boundary_review.precise_mobility_data_present == true
        or input.inference_boundary_review.individual_usage_pattern_present == true then
        return result(
            "local_only",
            {
                "person_linked_or_precise_pattern_data_requires_local_only",
                "privacy_review_required"
            }
        )
    end

    if input.inference_boundary_review.inference_risk_output_state
        ~= "advisory_only" then
        return result(
            "needs_review",
            {
                "incidental_inference_risk_requires_review",
                input.inference_boundary_review.inference_risk_output_state
            }
        )
    end

    local protected, outcome_reason = all_outcomes_protected(
        input.outcome_protection_review
    )

    if not protected then
        return result(
            "blocked_by_policy",
            {
                "protected_outcome_non_penalty_requirement_not_satisfied",
                outcome_reason
            }
        )
    end

    return result(
        "non_penalty_invariant_satisfied",
        {
            "no_cybernetic_status_or_proxy_used",
            "self_assertion_protection_available",
            "all_protected_outcomes_non_penalized"
        }
    )
end

function NonPenalty.render_accessible_explanation(assessment)
    local state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Cybernetic-status non-penalty review: " .. state .. ". "
        .. "Cybernetic status, self-assertion, device signals, movement patterns, "
        .. "appearance, assistive technology, biometrics, neural data, and health data "
        .. "are not permitted as decision inputs or penalty proxies. "
        .. "No external certification or biometric identification is required for "
        .. "protective treatment. "
        .. "Reason codes: " .. reasons .. ". "
        .. "Accessible human review and non-digital escalation remain available."
end

return NonPenalty
