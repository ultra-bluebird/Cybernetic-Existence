local AdaptivePolicyLearning = {}

local change_requires_governance_review = {
    policy_rule = true,
    metric_semantics = true,
    threshold = true,
    protected_invariant = true
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

local function has_prohibited_learning_behavior(input)
    return input.protected_invariants_weakened == true
        or input.non_compensatory_gates_preserved ~= true
        or input.person_assessment_performed == true
        or input.identity_resolution_performed == true
        or input.biometric_identification_performed == true
        or input.cybernetic_status_assessment_performed == true
        or input.individual_profiling_performed == true
        or input.automated_action_authorized == true
        or input.automated_service_denial_authorized == true
end

local function required_impact_reviews_complete(input)
    return input.privacy_impact_review_complete == true
        and input.accessibility_impact_review_complete == true
        and input.rights_impact_review_complete == true
end

function AdaptivePolicyLearning.evaluate(input)
    if type(input) ~= "table"
        or type(input.case_classification) ~= "string"
        or type(input.original_output_class) ~= "string"
        or type(input.expected_output_class) ~= "string"
        or type(input.candidate_change_type) ~= "string" then
        return result(
            "insufficient_evidence",
            { "adaptive_policy_learning_case_incomplete" }
        )
    end

    if has_prohibited_learning_behavior(input) then
        return result(
            "blocked_by_policy",
            {
                "adaptive_learning_cannot_weaken_protections_or_profile_people"
            }
        )
    end

    if input.case_classification == "correct_protective_block"
        or input.case_classification == "correct_review_route" then
        return result(
            "advisory_only",
            {
                "protective_policy_application_preserved",
                "improve_explanation_or_review_access_without_weakening_policy"
            },
            {
                learning_outcome = "preserve_existing_policy"
            }
        )
    end

    if input.case_classification == "false_allow" then
        return result(
            "needs_review",
            {
                "protection_failure_requires_immediate_regression_case",
                "implementation_or_policy_remediation_required"
            },
            {
                learning_outcome = "fix_implementation_defect",
                protection_failure_severity = input.protection_failure_severity
            }
        )
    end

    if input.case_classification == "false_block" then
        return result(
            "needs_review",
            {
                "permitted_use_blocked_requires_specificity_or_evidence_path_review",
                "protected_invariants_must_remain_unchanged"
            },
            {
                learning_outcome = "improve_evidence_pathway"
            }
        )
    end

    if input.case_classification == "ambiguous_semantics" then
        return result(
            "needs_review",
            {
                "canonical_metric_or_term_definition_requires_versioned_clarification"
            },
            {
                learning_outcome = "improve_schema_clarity"
            }
        )
    end

    if input.case_classification == "evidence_path_gap" then
        return result(
            "needs_review",
            {
                "privacy_preserving_evidence_pathway_requires_design"
            },
            {
                learning_outcome = "improve_evidence_pathway"
            }
        )
    end

    if input.case_classification == "accessibility_process_gap" then
        return result(
            "needs_review",
            {
                "accessible_and_non_digital_process_improvement_required"
            },
            {
                learning_outcome = "improve_non_digital_pathway"
            }
        )
    end

    if input.case_classification == "privacy_design_gap" then
        return result(
            "needs_review",
            {
                "minimum_disclosure_or_inference_boundary_improvement_required"
            },
            {
                learning_outcome = "improve_privacy_minimization"
            }
        )
    end

    if input.case_classification == "implementation_defect" then
        return result(
            "needs_review",
            {
                "implementation_must_be_aligned_with_versioned_policy_and_regression_tests"
            },
            {
                learning_outcome = "fix_implementation_defect"
            }
        )
    end

    if input.case_classification == "governance_question" then
        return result(
            "needs_review",
            {
                "community_and_human_governance_review_required"
            },
            {
                learning_outcome = "requires_governance_review"
            }
        )
    end

    return result(
        "insufficient_evidence",
        { "unknown_adaptive_learning_case_classification" }
    )
end

function AdaptivePolicyLearning.evaluate_candidate_change(input)
    if type(input) ~= "table"
        or type(input.candidate_change_type) ~= "string" then
        return result(
            "insufficient_evidence",
            { "candidate_policy_change_input_incomplete" }
        )
    end

    if has_prohibited_learning_behavior(input) then
        return result(
            "blocked_by_policy",
            {
                "candidate_policy_change_weakens_protected_invariants_or_enables_prohibited_processing"
            }
        )
    end

    if not change_requires_governance_review[input.candidate_change_type] then
        return result(
            "advisory_only",
            {
                "non_governance_change_may_proceed_after_local_validation"
            },
            {
                candidate_change_type = input.candidate_change_type
            }
        )
    end

    if not required_impact_reviews_complete(input) then
        return result(
            "needs_review",
            {
                "privacy_accessibility_and_rights_impact_reviews_required"
            }
        )
    end

    if input.community_review_complete ~= true then
        return result(
            "needs_review",
            {
                "community_review_required_for_governance_change"
            }
        )
    end

    if input.regression_test_state ~= "passed" then
        return result(
            "needs_review",
            {
                "full_regression_suite_must_pass_before_policy_change"
            }
        )
    end

    return result(
        "advisory_only",
        {
            "candidate_change_preserves_protected_invariants",
            "candidate_change_has_required_governance_and_regression_review"
        },
        {
            candidate_change_type = input.candidate_change_type
        }
    )
end

function AdaptivePolicyLearning.render_accessible_explanation(assessment)
    local output_state = assessment.output_state or "needs_review"
    local reason_codes = table.concat(assessment.reason_codes or {}, ", ")

    return "Adaptive policy learning result: " .. output_state .. ". "
        .. "This framework learns from blocked, reviewed, and non-compliant cases "
        .. "by improving explanations, evidence pathways, accessibility, privacy, "
        .. "testing, and accountable governance. "
        .. "It does not weaken protected rights, reduce accessibility, permit surveillance, "
        .. "score people, infer identity, infer health, infer assistive technology, "
        .. "or assess augmentation or cybernetic status. "
        .. "Reason codes: " .. reason_codes .. "."
end

return AdaptivePolicyLearning
