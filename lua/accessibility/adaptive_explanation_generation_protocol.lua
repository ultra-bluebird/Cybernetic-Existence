local Explanation = {}

local valid_output_classes = {
    informational_only = true,
    advisory_only = true,
    eligible_for_planning_use = true,
    needs_review = true,
    insufficient_evidence = true,
    conflicted = true,
    local_only = true,
    blocked_by_policy = true,
    reduce_automation = true,
    fail_safe_mode = true,
    withdraw_from_active_use = true
}

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

local function valid_text(value)
    return type(value) == "string" and value ~= ""
end

local function has_required_explanation_fields(input)
    return valid_text(input.decision_reference)
        and valid_output_classes[input.output_class] == true
        and valid_text(input.purpose_scope)
        and valid_text(input.policy_version)
        and valid_text(input.registry_version)
        and valid_text(input.semantic_version)
        and valid_text(input.plain_language_summary)
        and valid_text(input.evidence_summary)
        and valid_text(input.uncertainty_statement)
        and valid_text(input.policy_basis)
        and valid_text(input.action_boundary_statement)
        and valid_text(input.privacy_statement)
        and valid_text(input.meaning_digest)
end

local function accessibility_requirements_met(accessibility)
    return type(accessibility) == "table"
        and accessibility.plain_language == true
        and accessibility.non_digital == true
        and accessibility.offline == true
end

local function review_path_requirements_met(review_path)
    return type(review_path) == "table"
        and review_path.human_review_available == true
        and review_path.correction_available == true
        and review_path.appeal_available == true
        and review_path.non_digital_escalation_available == true
        and valid_text(review_path.plain_language_next_step)
end

local function prohibited_content_requested(input)
    return input.includes_raw_evidence == true
        or input.includes_raw_identity == true
        or input.includes_health_data == true
        or input.includes_biometric_data == true
        or input.includes_neural_data == true
        or input.includes_assistive_technology_data == true
        or input.includes_augmentation_status_data == true
        or input.includes_cybernetic_status_data == true
        or input.includes_precise_location == true
        or input.requests_person_assessment == true
        or input.requests_identity_resolution == true
        or input.requests_biometric_identification == true
        or input.requests_cybernetic_status_assessment == true
        or input.requests_automated_action == true
        or input.requests_service_denial == true
end

function Explanation.build(input)
    if type(input) ~= "table" or not has_required_explanation_fields(input) then
        return result(
            "insufficient_evidence",
            { "explanation_input_incomplete" }
        )
    end

    if prohibited_content_requested(input) then
        return result(
            "blocked_by_policy",
            { "explanation_must_not_include_sensitive_content_or_authorize_action" }
        )
    end

    if input.local_first ~= true
        or input.offline_available ~= true
        or input.uncertainty_visible ~= true then
        return result(
            "needs_review",
            { "local_offline_and_uncertainty_requirements_not_met" }
        )
    end

    if not accessibility_requirements_met(input.accessibility_levels) then
        return result(
            "needs_review",
            { "plain_language_offline_and_non_digital_explanation_required" }
        )
    end

    if not review_path_requirements_met(input.review_path) then
        return result(
            "needs_review",
            { "human_review_correction_appeal_and_non_digital_path_required" }
        )
    end

    if input.output_class == "eligible_for_planning_use"
        and input.protected_gates_pass ~= true then
        return result(
            "blocked_by_policy",
            { "eligible_explanation_requires_non_compensatory_gate_pass" }
        )
    end

    return result(
        input.output_class,
        {
            "meaning_equivalent_accessible_explanation_ready",
            "uncertainty_and_action_boundary_preserved",
            "no_person_or_cybernetic_status_assessment_performed"
        },
        {
            decision_reference = input.decision_reference,
            meaning_digest = input.meaning_digest,
            audience_profile = input.audience_profile or "affected_person_or_community_member",
            plain_language_summary = input.plain_language_summary,
            evidence_summary = input.evidence_summary,
            uncertainty_statement = input.uncertainty_statement,
            policy_basis = input.policy_basis,
            action_boundary_statement = input.action_boundary_statement,
            privacy_statement = input.privacy_statement,
            review_next_step = input.review_path.plain_language_next_step
        }
    )
end

function Explanation.verify_equivalence(reference, candidate)
    if type(reference) ~= "table"
        or type(candidate) ~= "table"
        or not valid_text(reference.meaning_digest)
        or not valid_text(candidate.meaning_digest) then
        return result(
            "insufficient_evidence",
            { "meaning_equivalence_input_missing" }
        )
    end

    if reference.meaning_digest ~= candidate.meaning_digest then
        return result(
            "blocked_by_policy",
            { "explanation_meaning_equivalence_failed" }
        )
    end

    if reference.output_class ~= candidate.output_class then
        return result(
            "blocked_by_policy",
            { "explanation_output_class_mismatch" }
        )
    end

    if reference.policy_version ~= candidate.policy_version
        or reference.registry_version ~= candidate.registry_version
        or reference.semantic_version ~= candidate.semantic_version then
        return result(
            "needs_review",
            { "explanation_version_binding_mismatch" }
        )
    end

    return result(
        "advisory_only",
        {
            "explanation_meaning_equivalence_verified"
        },
        {
            meaning_digest = reference.meaning_digest,
            output_class = reference.output_class
        }
    )
end

function Explanation.render_plain_language(assessment)
    local output_state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Explanation status: " .. output_state .. ". "
        .. "This explanation is local-first and advisory only. "
        .. "It describes the decision, the evidence state, what remains uncertain, "
        .. "the governing policy basis, and the next available review or appeal step. "
        .. "It does not assess identity, health, disability, assistive technology, "
        .. "augmentation status, or cybernetic status. "
        .. "It does not authorize automated action or service denial. "
        .. "Reason codes: " .. reasons .. "."
end

return Explanation
