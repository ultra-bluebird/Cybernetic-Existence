local GapRegister = {}

local critical_invariants = {
    non_compensatory_gates = true,
    no_biometric_identification = true,
    no_identity_resolution = true,
    no_person_scoring = true,
    no_cybernetic_status_penalty = true,
    consent_revocation = true,
    protected_record_preservation = true,
    sensitive_inference_prohibition = true,
    accessible_explanation = true,
    appeal_path = true,
    non_digital_escalation = true,
    local_first_continuity = true
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

function GapRegister.evaluate(gap)
    if type(gap) ~= "table"
        or not valid_text(gap.gap_reference)
        or not valid_text(gap.gap_category)
        or not valid_text(gap.affected_invariant)
        or not valid_text(gap.affected_system_area)
        or not valid_text(gap.finding_summary)
        or not valid_text(gap.required_remediation_type) then
        return result(
            "insufficient_evidence",
            { "research_gap_record_incomplete" }
        )
    end

    if gap.local_first ~= true then
        return result(
            "blocked_by_policy",
            { "gap_remediation_must_preserve_local_first_operation" }
        )
    end

    if critical_invariants[gap.affected_invariant] then
        return result(
            "needs_review",
            {
                "critical_rights_or_safety_invariant_has_implementation_gap",
                "promotion_or_expansion_must_remain_blocked_until_remediation"
            },
            {
                affected_invariant = gap.affected_invariant,
                affected_system_area = gap.affected_system_area,
                required_remediation_type = gap.required_remediation_type
            }
        )
    end

    if gap.severity == "critical" or gap.severity == "high" then
        return result(
            "needs_review",
            {
                "high_severity_gap_requires_versioned_remediation_and_regression_test"
            },
            {
                affected_invariant = gap.affected_invariant,
                required_remediation_type = gap.required_remediation_type
            }
        )
    end

    return result(
        "advisory_only",
        {
            "gap_recorded_for_versioned_research_and_remediation"
        },
        {
            affected_invariant = gap.affected_invariant,
            required_remediation_type = gap.required_remediation_type
        }
    )
end

function GapRegister.render_accessible_explanation(assessment)
    local state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Implementation gap review: " .. state .. ". "
        .. "This record identifies a difference between a declared policy, right, "
        .. "safety constraint, accessibility requirement, or evidence rule and its "
        .. "actual enforcement or test coverage. "
        .. "No person, community, identity, health condition, disability, "
        .. "assistive technology, augmentation status, or cybernetic status is assessed. "
        .. "Reason codes: " .. reasons .. "."
end

return GapRegister
