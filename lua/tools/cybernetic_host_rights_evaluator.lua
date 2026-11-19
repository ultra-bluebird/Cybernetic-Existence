-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/cybernetic_host_rights_evaluator.lua
-- Destination: lua/tools/

local RightsEvaluator = {}
RightsEvaluator.__index = RightsEvaluator

local right_order = {
    "self_asserted_identity",
    "privacy_and_data_minimization",
    "assistive_technology_necessity",
    "psychological_continuity",
    "augmentation_and_happiness",
    "equal_access_and_non_discrimination",
    "accessible_grievance_and_review",
    "social_acceptance_and_inclusion",
    "autonomy_and_final_authority",
    "freedom_from_coercion",
    "explanation_and_transparency",
    "ecological_responsibility",
}

local critical_rights = {
    self_asserted_identity = true,
    privacy_and_data_minimization = true,
    assistive_technology_necessity = true,
    psychological_continuity = true,
    equal_access_and_non_discrimination = true,
    autonomy_and_final_authority = true,
    freedom_from_coercion = true,
}

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function finite_number(value, field)
    assert(
        type(value) == "number"
            and value == value
            and value ~= math.huge
            and value ~= -math.huge,
        (field or "value") .. " must be a finite number"
    )
    return value
end

local function clamp01(value)
    value = finite_number(value, "score")

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic evaluation input is not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function flag(input, key, default)
    local value = input[key]

    if value == nil then
        return default
    end

    assert(type(value) == "boolean", key .. " must be boolean")
    return value
end

local function required_flag(input, key)
    return flag(input, key, false) == true
end

local function prohibited_flag(input, key)
    return flag(input, key, false) ~= true
end

local function check_self_asserted_identity(input)
    local respected = prohibited_flag(input, "requires_third_party_certification")
        and required_flag(input, "accepts_unverifiable_identity")
        and required_flag(input, "identity_claim_not_gated")

    return respected, {
        "Remove third-party certification as a condition for ordinary identity recognition.",
        "Accept self-asserted and unverifiable identity claims for ordinary access.",
        "Do not gate an identity claim behind verification status.",
    }
end

local function check_privacy(input)
    local respected = prohibited_flag(input, "collects_raw_identifiers")
        and prohibited_flag(input, "collects_biometrics")
        and prohibited_flag(input, "collects_raw_neural_signals")
        and prohibited_flag(input, "requires_device_fingerprint")
        and required_flag(input, "data_minimized")
        and required_flag(input, "aggregate_only")

    return respected, {
        "Remove raw identifiers, biometrics, raw neural signals, and device fingerprints from this decision path.",
        "Apply data minimization and aggregate-only processing where possible.",
        "Redact direct identifiers before any external processing.",
    }
end

local function check_assistive_technology(input)
    if prohibited_flag(input, "assistive_technology_required") then
        return true, {}
    end

    local respected = prohibited_flag(
        input,
        "treats_assistive_technology_as_optional"
    )
        and required_flag(input, "assistive_technology_supported")
        and required_flag(input, "effective_communication_available")
        and required_flag(
            input,
            "assistive_fallback_preserves_core_access"
        )

    return respected, {
        "Treat declared assistive technology as a necessity rather than optional convenience.",
        "Provide effective communication in the person's usable modality.",
        "Provide an equivalent fallback that preserves core access.",
    }
end

local function check_psychological_continuity(input)
    if prohibited_flag(input, "interface_change_detected") then
        return true, {}
    end

    local respected = required_flag(input, "continuity_access_preserved")
        and required_flag(input, "task_context_preserved")
        and required_flag(input, "identity_continuity_preserved")
        and required_flag(input, "memory_and_preferences_preserved")

    return respected, {
        "Preserve access, current task context, and authorized preferences across interface changes.",
        "Do not treat an assistive interface change as loss of identity continuity.",
    }
end

local function check_augmentation_and_happiness(input)
    local respected = prohibited_flag(input, "restricts_augmentation_choice")
        and required_flag(input, "supports_personal_augmentation_goals")
        and required_flag(input, "does_not_penalize_augmentation")
        and required_flag(input, "allows_self_determined_enhancement")

    return respected, {
        "Remove unjustified restrictions on voluntary augmentation choice.",
        "Do not penalize a person for augmentation status or goals.",
        "Support self-determined enhancement choices within applicable safety and legal boundaries.",
    }
end

local function check_equal_access(input)
    local respected = prohibited_flag(
        input,
        "denies_access_for_augmentation_status"
    )
        and prohibited_flag(
            input,
            "reduces_access_for_augmentation_status"
        )
        and prohibited_flag(
            input,
            "uses_identity_verifiability_for_access"
        )
        and prohibited_flag(
            input,
            "requires_third_party_certification_for_service"
        )
        and prohibited_flag(
            input,
            "does_not_provide_reasonable_accommodation"
        )

    return respected, {
        "Remove access restrictions tied to augmentation status.",
        "Do not reduce ordinary service access because identity cannot be independently verified.",
        "Remove certification gates from ordinary service access.",
        "Provide reasonable accommodation and an equivalent service path.",
    }
end

local function check_accessible_review(input)
    local respected = required_flag(
        input,
        "accessible_grievance_path_available"
    )
        and required_flag(input, "privacy_preserving_audit_available")
        and required_flag(input, "independent_review_possible")
        and required_flag(input, "remedies_are_effective")

    return respected, {
        "Provide an accessible grievance process.",
        "Provide a privacy-preserving audit record.",
        "Provide an independent review route and effective remedy process.",
    }
end

local function check_social_acceptance(input)
    local respected = prohibited_flag(input, "community_exclusion_risk")
        and required_flag(input, "stigmatization_prohibited")
        and required_flag(input, "public_inclusion_commitments")
        and required_flag(input, "anti_discrimination_policies_active")

    return respected, {
        "Address identified community-exclusion risks.",
        "Adopt explicit anti-stigmatization and anti-discrimination commitments.",
        "Publish measurable inclusion commitments for the relevant service or event.",
    }
end

local function check_autonomy(input)
    local respected = required_flag(input, "user_is_final_authority")
        and required_flag(input, "user_override_available")
        and required_flag(input, "informed_consent_required")
        and required_flag(input, "coercion_absent")
        and required_flag(
            input,
            "irreversible_change_requires_explicit_confirmation"
        )

    return respected, {
        "Return final decision authority to the individual.",
        "Provide an accessible override for automated adaptations.",
        "Require informed consent for optional or consequential processing.",
        "Require explicit confirmation for any irreversible change.",
    }
end

local function check_coercion(input)
    local respected = prohibited_flag(input, "coercive_design_detected")
        and prohibited_flag(input, "punitive_consent_refusal")
        and prohibited_flag(input, "manipulative_interface_patterns")
        and required_flag(input, "undue_influence_prohibited")

    return respected, {
        "Remove coercive and manipulative interface patterns.",
        "Do not punish refusal of optional consent.",
        "Adopt and enforce an undue-influence prohibition.",
    }
end

local function check_explanation(input)
    local respected = required_flag(input, "decision_explanation_available")
        and required_flag(input, "explanation_in_accessible_format")
        and required_flag(input, "algorithmic_transparency_required")

    return respected, {
        "Provide a comprehensible decision explanation.",
        "Provide the explanation in an accessible format.",
        "Document the applicable algorithmic or policy basis for review.",
    }
end

local function check_ecological_responsibility(input)
    if prohibited_flag(input, "material_ecological_impact") then
        return true, {}
    end

    local ecological_harm_risk = clamp01(
        input.ecological_harm_risk or 1.0
    )

    local respected = required_flag(
        input,
        "ecological_assessment_available"
    )
        and ecological_harm_risk <= 0.35
        and required_flag(input, "sustainable_practices_implemented")

    return respected, {
        "Complete an evidence-based ecological assessment.",
        "Reduce ecological harm risk to the declared operational corridor.",
        "Implement documented sustainable practices before proceeding.",
    }
end

local evaluators = {
    self_asserted_identity = check_self_asserted_identity,
    privacy_and_data_minimization = check_privacy,
    assistive_technology_necessity = check_assistive_technology,
    psychological_continuity = check_psychological_continuity,
    augmentation_and_happiness = check_augmentation_and_happiness,
    equal_access_and_non_discrimination = check_equal_access,
    accessible_grievance_and_review = check_accessible_review,
    social_acceptance_and_inclusion = check_social_acceptance,
    autonomy_and_final_authority = check_autonomy,
    freedom_from_coercion = check_coercion,
    explanation_and_transparency = check_explanation,
    ecological_responsibility = check_ecological_responsibility,
}

function RightsEvaluator.new(config)
    config = config or {}

    return setmetatable({
        minimum_knowledge_factor = clamp01(
            config.minimum_knowledge_factor or 0.75
        ),
        assessments = {},
        sequence = 0,
    }, RightsEvaluator)
end

function RightsEvaluator:evaluate(input)
    assert(type(input) == "table", "input must be a table")

    local decision_id = required_text(input.decision_id, "decision_id")
    local subject_reference = required_text(
        input.subject_reference,
        "subject_reference"
    )
    local action_kind = required_text(input.action_kind, "action_kind")

    local right_results = {}
    local remedies = {}
    local satisfied_count = 0
    local critical_failure = false

    for _, right in ipairs(right_order) do
        local respected, right_remedies = evaluators[right](input)

        right_results[right] = {
            respected = respected,
            critical = critical_rights[right] == true,
        }

        if respected then
            satisfied_count = satisfied_count + 1
        else
            if critical_rights[right] then
                critical_failure = true
            end

            for _, remedy in ipairs(right_remedies) do
                remedies[#remedies + 1] = remedy
            end
        end
    end

    local right_coverage = satisfied_count / #right_order
    local evidence_complete = input.evidence_complete == true
    local knowledge_factor = clamp01(
        right_coverage * 0.70
            + (evidence_complete and 0.30 or 0)
    )

    local constitutional_alignment = not critical_failure
        and knowledge_factor >= self.minimum_knowledge_factor
        and satisfied_count == #right_order

    local harm_risk = clamp01(
        (1 - right_coverage) * 0.55
            + (critical_failure and 0.30 or 0)
            + (not evidence_complete and 0.15 or 0)
    )

    local result = {
        decision_id = decision_id,
        subject_reference = subject_reference,
        action_kind = action_kind,
        advisory_only = true,
        constitutional_alignment = constitutional_alignment,
        rights_respected_count = satisfied_count,
        rights_required_count = #right_order,
        rights_coverage = right_coverage,
        right_results = right_results,
        required_remedies = remedies,
        user_is_final_authority = input.user_is_final_authority == true,
        external_execution_performed = false,
        knowledge_factor = knowledge_factor,
        eco_impact_value = clamp01(input.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        assessed_at_utc = input.assessed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.assessments[#self.assessments + 1] = copy_value(result)

    return result
end

function RightsEvaluator:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local assessments = {}
    local highest_harm_risk = 0
    local aligned_count = 0

    for _, assessment in ipairs(self.assessments) do
        if assessment.sequence > sequence then
            assessments[#assessments + 1] = copy_value(assessment)
            highest_harm_risk = math.max(
                highest_harm_risk,
                assessment.harm_risk
            )

            if assessment.constitutional_alignment then
                aligned_count = aligned_count + 1
            end
        end
    end

    local assessment_count = #assessments

    return {
        from_sequence = sequence,
        assessment_count = assessment_count,
        aligned_count = aligned_count,
        misaligned_count = assessment_count - aligned_count,
        assessments = assessments,
        knowledge_factor = assessment_count == 0 and 0
            or aligned_count / assessment_count,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return RightsEvaluator
