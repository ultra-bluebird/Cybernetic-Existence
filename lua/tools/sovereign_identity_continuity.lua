-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/sovereign_identity_continuity.lua
-- Destination: lua/tools/

local sovereign_identity_continuity = {}

local function is_finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function assert_finite(value, name)
    assert(is_finite(value), name .. " must be a finite number")
    return value
end

local function assert_probability(value, name)
    assert_finite(value, name)
    assert(value >= 0 and value <= 1, name .. " must be in [0, 1]")
    return value
end

local function assert_boolean(value, name)
    assert(type(value) == "boolean", name .. " must be boolean")
    return value
end

local function assert_string(value, name)
    assert(type(value) == "string" and value ~= "", name .. " must be a non-empty string")
    return value
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

local function mean(values, name)
    assert(type(values) == "table" and #values > 0, name .. " must be a non-empty array")

    local total = 0
    for index, value in ipairs(values) do
        total = total + assert_probability(value, name .. "[" .. index .. "]")
    end

    return total / #values
end

local function set_from_array(values, name)
    assert(type(values) == "table", name .. " must be an array")

    local result = {}
    for index, value in ipairs(values) do
        result[assert_string(value, name .. "[" .. index .. "]")] = true
    end

    return result
end

local function copy_array(values)
    local copied = {}
    for index, value in ipairs(values) do
        copied[index] = value
    end
    return copied
end

function sovereign_identity_continuity.recognize_stated_identity(input)
    assert(type(input) == "table", "identity input must be a table")

    local stated = assert_boolean(input.stated, "stated")
    local internally_contradictory = assert_boolean(
        input.internally_contradictory,
        "internally_contradictory"
    )
    local entails_concrete_imminent_unlawful_harm = assert_boolean(
        input.entails_concrete_imminent_unlawful_harm,
        "entails_concrete_imminent_unlawful_harm"
    )

    local recognition_eligible = stated
        and not internally_contradictory
        and not entails_concrete_imminent_unlawful_harm

    return {
        recognition_eligible = recognition_eligible,
        certification_required = false,
        identity_verification_required = false,
        biometric_required = false,
        augmentation_proof_required = false,
        anti_discrimination_protection_required = recognition_eligible,
        identity_claim_scored = false,
        decision = recognition_eligible
            and "recognize the stated identity without certification or technical proof"
            or "do not automate exclusion; preserve ordinary participation and provide accessible human review for any concrete concern",
    }
end

function sovereign_identity_continuity.evaluate_restriction_gate(input)
    assert(type(input) == "table", "restriction input must be a table")

    local legitimate_purpose = assert_boolean(
        input.legitimate_purpose,
        "legitimate_purpose"
    )
    local evidence_tied_to_conduct_or_condition = assert_boolean(
        input.evidence_tied_to_conduct_or_condition,
        "evidence_tied_to_conduct_or_condition"
    )
    local no_less_restrictive_effective_alternative = assert_boolean(
        input.no_less_restrictive_effective_alternative,
        "no_less_restrictive_effective_alternative"
    )
    local minimized_scope_and_duration = assert_boolean(
        input.minimized_scope_and_duration,
        "minimized_scope_and_duration"
    )
    local accessible_human_review = assert_boolean(
        input.accessible_human_review,
        "accessible_human_review"
    )
    local continuity_measure_available = assert_boolean(
        input.continuity_measure_available,
        "continuity_measure_available"
    )

    local justified = legitimate_purpose
        and evidence_tied_to_conduct_or_condition
        and no_less_restrictive_effective_alternative
        and minimized_scope_and_duration
        and accessible_human_review
        and continuity_measure_available

    return {
        restriction_justified = justified,
        automated_adverse_action_permitted = false,
        ordinary_service_continuity_required = true,
        accessible_human_review_required = true,
        identity_recognition_must_continue = true,
        decision = justified
            and "apply only the narrow, time-limited service condition while preserving recognition, review, and continuity"
            or "do not impose the proposed restriction; preserve ordinary service and remediate the missing safeguard",
    }
end

function sovereign_identity_continuity.evaluate_non_displacement(input)
    assert(type(input) == "table", "terminology input must be a table")

    local original_term = assert_string(input.original_term, "original_term")
    local proposed_term = assert_string(input.proposed_term, "proposed_term")
    local explicit_consent = assert_boolean(input.explicit_consent, "explicit_consent")
    local scope_declared = assert_boolean(input.scope_declared, "scope_declared")

    local replacement_requested = original_term ~= proposed_term
    local permitted = not replacement_requested
        or (explicit_consent and scope_declared)

    return {
        original_term = original_term,
        proposed_term = proposed_term,
        replacement_requested = replacement_requested,
        replacement_permitted = permitted,
        original_term_must_remain_visible = replacement_requested,
        decision = permitted
            and "preserve the original term and present any approved parallel translation as optional"
            or "do not replace, narrow, omit, or redefine the original term without explicit scoped consent",
    }
end

function sovereign_identity_continuity.evaluate_fallback_continuity(input)
    assert(type(input) == "table", "fallback input must be a table")

    local profile_available = assert_boolean(
        input.profile_available,
        "profile_available"
    )
    local ordinary_service_available = assert_boolean(
        input.ordinary_service_available,
        "ordinary_service_available"
    )
    local accessible_clarification_available = assert_boolean(
        input.accessible_clarification_available,
        "accessible_clarification_available"
    )
    local neutral_terminology_available = assert_boolean(
        input.neutral_terminology_available,
        "neutral_terminology_available"
    )

    local fallback_ready = profile_available
        or (
            ordinary_service_available
            and accessible_clarification_available
            and neutral_terminology_available
        )

    return {
        profile_available = profile_available,
        fallback_ready = fallback_ready,
        profile_inference_permitted = false,
        terminology_replacement_permitted = false,
        ordinary_service_available = ordinary_service_available,
        accessible_clarification_available = accessible_clarification_available,
        neutral_terminology_available = neutral_terminology_available,
        decision = profile_available
            and "use the active profile only within its declared purpose and scope"
            or "request scoped clarification, use neutral language, and preserve ordinary service without guessing personal context",
    }
end

function sovereign_identity_continuity.evaluate_continuity_floor(input)
    assert(type(input) == "table", "continuity input must be a table")
    assert(type(input.current) == "table", "input.current must be a table")
    assert(type(input.floor) == "table", "input.floor must be a table")

    local dimensions = {
        "learning",
        "expression",
        "autonomy",
        "privacy",
        "assistive_communication",
    }

    local current = {}
    local floor = {}
    local below_floor = {}

    for _, dimension in ipairs(dimensions) do
        current[dimension] = assert_probability(
            input.current[dimension],
            "current." .. dimension
        )
        floor[dimension] = assert_probability(
            input.floor[dimension],
            "floor." .. dimension
        )

        if current[dimension] < floor[dimension] then
            below_floor[#below_floor + 1] = dimension
        end
    end

    local continuity_preserved = #below_floor == 0

    return {
        continuity_preserved = continuity_preserved,
        current = current,
        floor = floor,
        below_floor = below_floor,
        fallback_required = not continuity_preserved,
        decision = continuity_preserved
            and "continuity dimensions meet the supplied protection floors"
            or "preserve access through a fallback route and remediate every dimension below its floor",
    }
end

function sovereign_identity_continuity.evaluate_monotone_protection(input)
    assert(type(input) == "table", "protection input must be a table")

    local previous = assert_probability(
        input.previous_protection_level,
        "previous_protection_level"
    )
    local proposed = assert_probability(
        input.proposed_protection_level,
        "proposed_protection_level"
    )
    local explicit_user_approval = assert_boolean(
        input.explicit_user_approval,
        "explicit_user_approval"
    )
    local purpose_declared = assert_boolean(
        input.purpose_declared,
        "purpose_declared"
    )

    local weakens_protection = proposed < previous
    local permitted = not weakens_protection
        or (explicit_user_approval and purpose_declared)

    return {
        previous_protection_level = previous,
        proposed_protection_level = proposed,
        weakens_protection = weakens_protection,
        change_permitted = permitted,
        decision = permitted
            and "record the protection level and require transparent review for any future change"
            or "reject the change because it weakens a continuity or identity-protection floor without explicit scoped approval",
    }
end

function sovereign_identity_continuity.evaluate_assistive_communication(input)
    assert(type(input) == "table", "communication input must be a table")

    local available_formats = set_from_array(
        input.available_formats,
        "available_formats"
    )
    local requested_format = assert_string(
        input.requested_format,
        "requested_format"
    )
    local plain_language_available = assert_boolean(
        input.plain_language_available,
        "plain_language_available"
    )
    local one_question_limit = assert_boolean(
        input.one_question_limit,
        "one_question_limit"
    )
    local sensitive_disclosure_required = assert_boolean(
        input.sensitive_disclosure_required,
        "sensitive_disclosure_required"
    )
    local human_fallback_available = assert_boolean(
        input.human_fallback_available,
        "human_fallback_available"
    )

    local requested_format_available = available_formats[requested_format] == true
    local privacy_respecting = not sensitive_disclosure_required
    local communication_ready = requested_format_available
        and plain_language_available
        and one_question_limit
        and privacy_respecting
        and human_fallback_available

    return {
        requested_format = requested_format,
        requested_format_available = requested_format_available,
        plain_language_available = plain_language_available,
        one_question_limit = one_question_limit,
        privacy_respecting = privacy_respecting,
        human_fallback_available = human_fallback_available,
        communication_ready = communication_ready,
        decision = communication_ready
            and "provide the selected accessible format without requiring sensitive disclosure"
            or "add an accessible format or human fallback without requesting identity, health, or augmentation information",
    }
end

function sovereign_identity_continuity.create_privacy_minimized_audit_event(input)
    assert(type(input) == "table", "audit input must be a table")

    local prohibited_fields = {
        "identity_certificate",
        "biometric_data",
        "health_data",
        "did_proof",
        "augmentation_proof",
        "persistent_device_identifier",
        "raw_sensor_payload",
    }

    for _, field in ipairs(prohibited_fields) do
        assert(input[field] == nil, "audit input must not contain " .. field)
    end

    local time_window = assert_string(input.time_window, "time_window")
    local action_type = assert_string(input.action_type, "action_type")
    local service_component = assert_string(
        input.service_component,
        "service_component"
    )
    local rule_reference = assert_string(
        input.rule_reference,
        "rule_reference"
    )
    local human_review_state = assert_string(
        input.human_review_state,
        "human_review_state"
    )
    local outcome = assert_string(input.outcome, "outcome")
    local uncertainty_or_exception = assert_string(
        input.uncertainty_or_exception,
        "uncertainty_or_exception"
    )
    local continuity_action = assert_string(
        input.continuity_action,
        "continuity_action"
    )
    local retention_boundary = assert_string(
        input.retention_boundary,
        "retention_boundary"
    )

    return {
        time_window = time_window,
        action_type = action_type,
        service_component = service_component,
        rule_reference = rule_reference,
        human_review_state = human_review_state,
        outcome = outcome,
        uncertainty_or_exception = uncertainty_or_exception,
        continuity_action = continuity_action,
        retention_boundary = retention_boundary,
        privacy_minimized = true,
        identity_verification_present = false,
        decision = "retain only the minimum operational record needed for review and remediation",
    }
end

function sovereign_identity_continuity.evaluate_case(input)
    assert(type(input) == "table", "case input must be a table")

    local recognition = sovereign_identity_continuity.recognize_stated_identity(
        input.identity
    )
    local restriction = sovereign_identity_continuity.evaluate_restriction_gate(
        input.restriction
    )
    local fallback = sovereign_identity_continuity.evaluate_fallback_continuity(
        input.fallback
    )
    local continuity = sovereign_identity_continuity.evaluate_continuity_floor(
        input.continuity
    )
    local communication =
        sovereign_identity_continuity.evaluate_assistive_communication(
            input.communication
        )

    local knowledge_factor = mean({
        assert_probability(input.evidence_quality, "evidence_quality"),
        assert_probability(
            input.communication_validation_quality,
            "communication_validation_quality"
        ),
        assert_probability(
            input.continuity_test_coverage,
            "continuity_test_coverage"
        ),
    }, "knowledge inputs")

    local eco_impact_value = mean({
        assert_probability(
            input.access_continuity_benefit,
            "access_continuity_benefit"
        ),
        assert_probability(
            input.resource_efficiency_benefit,
            "resource_efficiency_benefit"
        ),
        assert_probability(
            input.community_inclusion_benefit,
            "community_inclusion_benefit"
        ),
    }, "eco-impact inputs")

    local harm_risk = mean({
        assert_probability(
            input.exclusion_risk,
            "exclusion_risk"
        ),
        assert_probability(
            input.terminology_displacement_risk,
            "terminology_displacement_risk"
        ),
        assert_probability(
            input.continuity_disruption_risk,
            "continuity_disruption_risk"
        ),
        assert_probability(
            input.unnecessary_disclosure_risk,
            "unnecessary_disclosure_risk"
        ),
    }, "harm-risk inputs")

    local overall_status
    if not recognition.recognition_eligible then
        overall_status = "requires_human_review"
    elseif not fallback.fallback_ready
        or not continuity.continuity_preserved
        or not communication.communication_ready then
        overall_status = "requires_redesign"
    elseif not restriction.restriction_justified then
        overall_status = "allow_with_continuity"
    else
        overall_status = "requires_human_review"
    end

    return {
        recognition = recognition,
        restriction = restriction,
        fallback = fallback,
        continuity = continuity,
        communication = communication,
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
        overall_status = overall_status,
        scope = "local, non-actuating identity-respect and assistive-communication decision support",
        limitation = "This module does not verify identity, diagnose any person, control devices, modify firmware, secure a network, provide legal advice, or substitute for qualified accessibility, safety, privacy, or legal review.",
    }
end

return sovereign_identity_continuity
