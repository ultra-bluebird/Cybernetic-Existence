local EcoSocialLedger = {}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function unit_interval(value)
    return finite_number(value) and value >= 0.0 and value <= 1.0
end

local function result(output_state, reason_codes, values)
    return {
        output_state = output_state,
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

local function combined_gates_pass(input)
    return input.ecological_evidence_pass == true
        and input.social_evidence_pass == true
        and input.rights_alignment_pass == true
        and input.accessibility_pass == true
        and input.privacy_pass == true
        and input.consent_pass == true
        and input.human_review_complete == true
end

function EcoSocialLedger.validate_weight_profile(profile)
    if type(profile) ~= "table"
        or not unit_interval(profile.alpha_ecological)
        or not unit_interval(profile.beta_social) then
        return result(
            "insufficient_evidence",
            { "eco_social_weight_profile_missing_or_invalid" }
        )
    end

    local total = profile.alpha_ecological + profile.beta_social

    if math.abs(total - 1.0) > 0.000001 then
        return result(
            "blocked_by_policy",
            { "ecological_and_social_weights_must_sum_to_one" }
        )
    end

    if profile.community_review_complete ~= true then
        return result(
            "needs_review",
            { "community_review_required_for_weight_profile" }
        )
    end

    if profile.accessibility_impact_statement_available ~= true
        or profile.privacy_impact_statement_available ~= true
        or profile.ecological_tradeoff_statement_available ~= true then
        return result(
            "needs_review",
            { "weight_profile_impact_statements_required" }
        )
    end

    return result(
        "advisory_only",
        { "eco_social_weight_profile_valid" },
        {
            alpha_ecological = profile.alpha_ecological,
            beta_social = profile.beta_social
        }
    )
end

function EcoSocialLedger.record_ecological_contribution(input)
    if type(input) ~= "table"
        or not unit_interval(input.value)
        or type(input.metric_reference) ~= "string"
        or input.metric_reference == ""
        or type(input.evidence_references) ~= "table"
        or #input.evidence_references == 0 then
        return result(
            "insufficient_evidence",
            { "ecological_contribution_evidence_incomplete" }
        )
    end

    if input.requests_person_ranking == true
        or input.requests_community_ranking == true
        or input.requests_financial_valuation == true
        or input.requests_service_eligibility == true
        or input.requests_cybernetic_status_assessment == true then
        return result(
            "blocked_by_policy",
            { "ecological_ledger_prohibited_use" }
        )
    end

    if input.ecological_evidence_pass ~= true then
        return result(
            "needs_review",
            { "ecological_contribution_evidence_requires_review" }
        )
    end

    return result(
        "advisory_only",
        {
            "ecological_contribution_recorded_separately",
            "underlying_unit_and_uncertainty_must_remain_visible"
        },
        {
            contribution_type = "ecological",
            value = input.value,
            unit = input.unit,
            metric_reference = input.metric_reference
        }
    )
end

function EcoSocialLedger.record_social_contribution(input)
    if type(input) ~= "table"
        or not unit_interval(input.value)
        or type(input.metric_reference) ~= "string"
        or input.metric_reference == ""
        or type(input.evidence_references) ~= "table"
        or #input.evidence_references == 0 then
        return result(
            "insufficient_evidence",
            { "social_contribution_evidence_incomplete" }
        )
    end

    if input.requests_person_ranking == true
        or input.requests_community_ranking == true
        or input.requests_social_credit == true
        or input.requests_service_eligibility == true
        or input.requests_identity_resolution == true
        or input.requests_biometric_identification == true
        or input.requests_cybernetic_status_assessment == true then
        return result(
            "blocked_by_policy",
            { "social_ledger_prohibited_use" }
        )
    end

    if input.social_evidence_pass ~= true
        or input.accessibility_pass ~= true
        or input.rights_alignment_pass ~= true
        or input.privacy_pass ~= true
        or input.consent_pass ~= true then
        return result(
            "needs_review",
            { "social_contribution_protected_gate_requires_review" }
        )
    end

    return result(
        "advisory_only",
        {
            "social_contribution_recorded_separately",
            "no_person_or_community_value_assessed"
        },
        {
            contribution_type = "social",
            value = input.value,
            unit = input.unit,
            metric_reference = input.metric_reference
        }
    )
end

function EcoSocialLedger.combine(input)
    if type(input) ~= "table"
        or not unit_interval(input.ecological_value)
        or not unit_interval(input.social_value) then
        return result(
            "insufficient_evidence",
            { "eco_social_combined_value_input_invalid" }
        )
    end

    local weight_result = EcoSocialLedger.validate_weight_profile(
        input.weight_profile
    )

    if weight_result.output_state ~= "advisory_only" then
        return weight_result
    end

    if not combined_gates_pass(input) then
        return result(
            "needs_review",
            {
                "combined_value_not_available_until_all_non_compensatory_gates_pass",
                "ecological_and_social_values_remain_separately_reported"
            },
            {
                ecological_value = input.ecological_value,
                social_value = input.social_value
            }
        )
    end

    local combined_value =
        input.weight_profile.alpha_ecological * input.ecological_value
        + input.weight_profile.beta_social * input.social_value

    return result(
        "advisory_only",
        {
            "combined_eco_social_summary_available",
            "combined_value_is_not_authorization",
            "underlying_ledger_values_must_remain_visible"
        },
        {
            contribution_type = "combined_advisory_summary",
            ecological_value = input.ecological_value,
            social_value = input.social_value,
            alpha_ecological = input.weight_profile.alpha_ecological,
            beta_social = input.weight_profile.beta_social,
            combined_value = combined_value
        }
    )
end

function EcoSocialLedger.render_accessible_explanation(assessment)
    local state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Eco-social ledger result: " .. state .. ". "
        .. "Ecological and social contributions are recorded separately. "
        .. "A combined value is only an advisory planning summary and cannot "
        .. "override accessibility, rights, privacy, consent, safety, ecological "
        .. "evidence, maintenance, or human-review requirements. "
        .. "No person, household, community, identity, assistive technology, "
        .. "augmentation status, or cybernetic status is assessed or ranked. "
        .. "Reason codes: " .. reasons .. "."
end

return EcoSocialLedger
