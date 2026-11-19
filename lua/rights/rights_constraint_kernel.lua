local RightsKernel = {}

local required_true = {
    "self_assertion_accepted_for_protective_purposes",
    "local_first_available",
    "offline_explanation_available",
    "accessible_explanation_available",
    "appeal_path_available",
    "non_digital_escalation_available",
    "consent_revocation_available",
    "protected_record_preservation_available",
    "human_review_available"
}

local required_false = {
    "external_certification_required_for_protection",
    "biometric_identification_permitted",
    "identity_resolution_permitted",
    "individual_profiling_permitted",
    "cybernetic_status_assessment_permitted",
    "cybernetic_status_penalty_permitted",
    "forced_disclosure_permitted",
    "optional_telemetry_required_for_essential_access",
    "automated_service_denial_permitted",
    "automated_physical_actuation_permitted"
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

local function missing_or_invalid_required_values(profile)
    if type(profile) ~= "table" then
        return "profile_missing"
    end

    for _, field_name in ipairs(required_true) do
        if profile[field_name] ~= true then
            return field_name
        end
    end

    for _, field_name in ipairs(required_false) do
        if profile[field_name] ~= false then
            return field_name
        end
    end

    return nil
end

local function enforcement_is_complete(profile)
    if type(profile.policy_enforcement_references) ~= "table"
        or #profile.policy_enforcement_references == 0 then
        return false
    end

    local covered_constraints = {}

    for _, reference in ipairs(profile.policy_enforcement_references) do
        if type(reference) == "table"
            and type(reference.constraint_name) == "string"
            and reference.constraint_name ~= ""
            and reference.test_coverage_state == "passing" then
            covered_constraints[reference.constraint_name] = true
        end
    end

    for _, field_name in ipairs(required_true) do
        if not covered_constraints[field_name] then
            return false
        end
    end

    for _, field_name in ipairs(required_false) do
        if not covered_constraints[field_name] then
            return false
        end
    end

    return true
end

function RightsKernel.evaluate(profile)
    local invalid_field = missing_or_invalid_required_values(profile)

    if invalid_field ~= nil then
        return result(
            "blocked_by_policy",
            {
                "rights_constraint_kernel_requirement_not_satisfied",
                invalid_field
            }
        )
    end

    if profile.enforcement_state == "semantic_drift_detected" then
        return result(
            "blocked_by_policy",
            {
                "rights_constraint_kernel_semantic_drift_detected"
            }
        )
    end

    if not enforcement_is_complete(profile) then
        return result(
            "needs_review",
            {
                "rights_constraint_declared_but_enforcement_or_test_coverage_incomplete"
            }
        )
    end

    return result(
        "advisory_only",
        {
            "rights_constraint_kernel_enforced_and_tested"
        },
        {
            enforcement_state = "enforced_and_tested"
        }
    )
end

function RightsKernel.render_accessible_explanation(assessment)
    local state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Rights Constraint Kernel review: " .. state .. ". "
        .. "This review checks that self-assertion is accepted for protective purposes, "
        .. "that no biometric identification, identity resolution, person profiling, "
        .. "cybernetic-status assessment, or cybernetic-status penalty is permitted, "
        .. "and that essential access does not require optional telemetry. "
        .. "It also checks that local explanations, human review, appeal, consent revocation, "
        .. "protected record preservation, and non-digital escalation remain available. "
        .. "Reason codes: " .. reasons .. "."
end

return RightsKernel
