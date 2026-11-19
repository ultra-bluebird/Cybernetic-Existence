local universal_assistance_continuity_audit = {}

local function is_finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function assert_finite(value, field_name)
    assert(is_finite(value), field_name .. " must be a finite number")
    return value
end

local function assert_probability(value, field_name)
    assert_finite(value, field_name)
    assert(value >= 0 and value <= 1, field_name .. " must be in [0, 1]")
    return value
end

local function assert_boolean(value, field_name)
    assert(type(value) == "boolean", field_name .. " must be boolean")
    return value
end

local function assert_string(value, field_name)
    assert(type(value) == "string" and value ~= "",
        field_name .. " must be a non-empty string")
    return value
end

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function average(values, field_name)
    assert(type(values) == "table" and #values > 0,
        field_name .. " must be a non-empty array")

    local total = 0
    for index, value in ipairs(values) do
        total = total + assert_finite(value, field_name .. "[" .. index .. "]")
    end

    return total / #values
end

local function set_from_array(values, field_name)
    assert(type(values) == "table", field_name .. " must be an array")

    local result = {}
    for index, value in ipairs(values) do
        result[assert_string(value, field_name .. "[" .. index .. "]")] = true
    end

    return result
end

local function missing_items(available, required)
    local missing = {}

    for _, item in ipairs(required) do
        if not available[item] then
            missing[#missing + 1] = item
        end
    end

    return missing
end

function universal_assistance_continuity_audit.communication_modes(input)
    assert(type(input) == "table", "communication input must be a table")

    local provided = set_from_array(input.provided_modes, "provided_modes")
    local required = {
        "plain_language_visual",
        "auditory_output",
        "tactile_or_haptic_feedback",
        "high_contrast_visual",
        "physical_or_non_touch_input",
        "non_digital_human_assistance",
    }

    local missing = missing_items(provided, required)

    return {
        required_universal_modes = required,
        provided_modes = sorted_keys(provided),
        missing_modes = missing,
        universal_communication_ready = #missing == 0,
        decision = #missing == 0
            and "panel provides the minimum defined multimodal baseline; validate with voluntary accessibility testing"
            or "add the missing modes and preserve a human-accessible route before treating the panel as universally usable",
        limitation = "The baseline is a service-design checklist, not a substitute for co-design, language access, hardware ergonomics, or applicable accessibility obligations.",
    }
end

function universal_assistance_continuity_audit.service_continuity(input)
    assert(type(input) == "table", "continuity input must be a table")

    local offline_or_local_mode = assert_boolean(
        input.offline_or_local_mode,
        "offline_or_local_mode"
    )
    local backward_compatible_protocol = assert_boolean(
        input.backward_compatible_protocol,
        "backward_compatible_protocol"
    )
    local staged_update = assert_boolean(input.staged_update, "staged_update")
    local alternative_communication_path = assert_boolean(
        input.alternative_communication_path,
        "alternative_communication_path"
    )
    local spectrum_transition_notice = assert_boolean(
        input.spectrum_transition_notice,
        "spectrum_transition_notice"
    )
    local accessible_human_fallback = assert_boolean(
        input.accessible_human_fallback,
        "accessible_human_fallback"
    )
    local no_identity_or_health_disclosure = assert_boolean(
        input.no_identity_or_health_disclosure,
        "no_identity_or_health_disclosure"
    )

    local continuity_score = average({
        offline_or_local_mode and 1 or 0,
        backward_compatible_protocol and 1 or 0,
        staged_update and 1 or 0,
        alternative_communication_path and 1 or 0,
        spectrum_transition_notice and 1 or 0,
        accessible_human_fallback and 1 or 0,
        no_identity_or_health_disclosure and 1 or 0,
    }, "continuity controls")

    local continuity_ready = offline_or_local_mode
        and alternative_communication_path
        and accessible_human_fallback
        and no_identity_or_health_disclosure

    return {
        continuity_ready = continuity_ready,
        continuity_score = continuity_score,
        controls = {
            offline_or_local_mode = offline_or_local_mode,
            backward_compatible_protocol = backward_compatible_protocol,
            staged_update = staged_update,
            alternative_communication_path = alternative_communication_path,
            spectrum_transition_notice = spectrum_transition_notice,
            accessible_human_fallback = accessible_human_fallback,
            no_identity_or_health_disclosure = no_identity_or_health_disclosure,
        },
        decision = continuity_ready
            and "maintain local and human-accessible service paths throughout the update or spectrum transition"
            or "do not rely on a city-wide change until local continuity, alternate access, and human fallback are present",
        limitation = "This is a continuity-planning audit only. It does not configure firmware, spectrum, radio systems, or assistive devices.",
    }
end

function universal_assistance_continuity_audit.identity_fairness_framework(input)
    assert(type(input) == "table", "identity-framework input must be a table")

    local identity_stated = assert_boolean(input.identity_stated, "identity_stated")
    local internally_contradictory = assert_boolean(
        input.internally_contradictory,
        "internally_contradictory"
    )
    local imminent_unlawful_harm = assert_boolean(
        input.imminent_unlawful_harm,
        "imminent_unlawful_harm"
    )
    local service_eligibility_required = assert_boolean(
        input.service_eligibility_required,
        "service_eligibility_required"
    )
    local minimally_disclosive_proof_verified = assert_boolean(
        input.minimally_disclosive_proof_verified,
        "minimally_disclosive_proof_verified"
    )
    local accessible_human_review = assert_boolean(
        input.accessible_human_review,
        "accessible_human_review"
    )
    local continuity_measure = assert_boolean(
        input.continuity_measure,
        "continuity_measure"
    )

    local identity_recognized = identity_stated
        and not internally_contradictory
        and not imminent_unlawful_harm

    local service_eligibility_met = not service_eligibility_required
        or minimally_disclosive_proof_verified

    local fair_treatment_ready = identity_recognized
        and service_eligibility_met
        and accessible_human_review
        and continuity_measure

    return {
        identity_recognized = identity_recognized,
        anti_discrimination_protection_required = identity_recognized,
        certification_required_for_identity_recognition = false,
        service_eligibility_met = service_eligibility_met,
        accessible_human_review = accessible_human_review,
        continuity_measure = continuity_measure,
        fair_treatment_ready = fair_treatment_ready,
        framework = {
            "recognize_stated_identity_without_certification",
            "assess_only_service_relevant_eligibility",
            "use_minimally_disclosive_eligibility_proof",
            "prohibit_identity_based_denial",
            "provide_accessible_human_review",
            "preserve_continuity_during_disputes_or_failures",
        },
        decision = fair_treatment_ready
            and "recognize identity, honor anti-discrimination protection, and evaluate only service-relevant eligibility without excess disclosure"
            or "do not deny identity recognition; correct the eligibility, review, or continuity gap through accountable procedures",
    }
end

function universal_assistance_continuity_audit.automatic_door_fusion(input)
    assert(type(input) == "table", "door-fusion input must be a table")

    local thermal_confidence = assert_probability(
        input.thermal_confidence,
        "thermal_confidence"
    )
    local lidar_confidence = assert_probability(
        input.lidar_confidence,
        "lidar_confidence"
    )
    local radar_confidence = assert_probability(
        input.radar_confidence,
        "radar_confidence"
    )
    local nonvisual_presence_sensor_confidence = assert_probability(
        input.nonvisual_presence_sensor_confidence,
        "nonvisual_presence_sensor_confidence"
    )
    local sensor_disagreement = assert_boolean(
        input.sensor_disagreement,
        "sensor_disagreement"
    )
    local passage_requested = assert_boolean(
        input.passage_requested,
        "passage_requested"
    )
    local accessible_manual_or_human_path = assert_boolean(
        input.accessible_manual_or_human_path,
        "accessible_manual_or_human_path"
    )

    local fusion_confidence = average({
        thermal_confidence,
        lidar_confidence,
        radar_confidence,
        nonvisual_presence_sensor_confidence,
    }, "fusion confidence inputs")

    local automated_adverse_treatment_permitted = false
    local facilitate_passage = passage_requested
        and accessible_manual_or_human_path

    return {
        fusion_confidence = fusion_confidence,
        sensor_disagreement = sensor_disagreement,
        passage_requested = passage_requested,
        accessible_manual_or_human_path = accessible_manual_or_human_path,
        automated_adverse_treatment_permitted = automated_adverse_treatment_permitted,
        facilitate_passage = facilitate_passage,
        failure_modes_to_test = {
            "thermal_occlusion_or_low_contrast",
            "reflective_or_multipath_lidar_returns",
            "radar_multipath_or_static-object_ambiguity",
            "vision_model_confusion_from_non_standard_silhouettes",
            "cross_sensor_time_or_geometry_misalignment",
        },
        decision = accessible_manual_or_human_path
            and "treat disagreement or low confidence as a reason to preserve safe passage and record only de-identified diagnostic telemetry"
            or "add an accessible non-sensor-dependent passage route; do not make service contingent on classifier confidence",
        limitation = "This is a test-planning and assurance aid. It does not control doors, classify people, identify devices, or make individual safety determinations.",
    }
end

function universal_assistance_continuity_audit.noncoercive_public_engagement(input)
    assert(type(input) == "table", "engagement input must be a table")

    local voluntary_participation = assert_boolean(
        input.voluntary_participation,
        "voluntary_participation"
    )
    local informed_context = assert_boolean(
        input.informed_context,
        "informed_context"
    )
    local viewpoint_pluralism = assert_boolean(
        input.viewpoint_pluralism,
        "viewpoint_pluralism"
    )
    local accessible_formats = assert_boolean(
        input.accessible_formats,
        "accessible_formats"
    )
    local paid_or_supported_participation = assert_boolean(
        input.paid_or_supported_participation,
        "paid_or_supported_participation"
    )
    local anonymous_feedback = assert_boolean(
        input.anonymous_feedback,
        "anonymous_feedback"
    )
    local no_belief_or_identity_inference = assert_boolean(
        input.no_belief_or_identity_inference,
        "no_belief_or_identity_inference"
    )
    local published_response_to_feedback = assert_boolean(
        input.published_response_to_feedback,
        "published_response_to_feedback"
    )

    local protocol_score = average({
        voluntary_participation and 1 or 0,
        informed_context and 1 or 0,
        viewpoint_pluralism and 1 or 0,
        accessible_formats and 1 or 0,
        paid_or_supported_participation and 1 or 0,
        anonymous_feedback and 1 or 0,
        no_belief_or_identity_inference and 1 or 0,
        published_response_to_feedback and 1 or 0,
    }, "engagement protocol controls")

    local noncoercive = voluntary_participation
        and informed_context
        and viewpoint_pluralism
        and accessible_formats
        and no_belief_or_identity_inference

    return {
        noncoercive = noncoercive,
        protocol_score = protocol_score,
        principles = {
            "voluntary_participation",
            "plain_language_and_accessible_formats",
            "no_required_belief_or_identity_disclosure",
            "pluralistic_and_good_faith_discussion",
            "anonymous_or_low-risk_feedback",
            "supported_participation_to_reduce_access_barriers",
            "public_response_to_aggregate_feedback",
        },
        decision = noncoercive
            and "use the protocol to support informed, voluntary dialogue and track only aggregate process quality"
            or "redesign engagement so participation, viewpoints, and nonparticipation are equally respected",
        limitation = "Engagement may measure aggregate process quality, not the beliefs, identities, or ideological conformity of individual participants.",
    }
end

function universal_assistance_continuity_audit.assessment_metrics(input)
    assert(type(input) == "table", "metrics input must be a table")

    local knowledge_factor = average({
        assert_probability(input.accessibility_test_coverage, "accessibility_test_coverage"),
        assert_probability(input.continuity_exercise_coverage, "continuity_exercise_coverage"),
        assert_probability(input.privacy_review_quality, "privacy_review_quality"),
        assert_probability(input.participatory_governance_quality, "participatory_governance_quality"),
    }, "knowledge-factor inputs")

    local eco_impact_value = average({
        assert_probability(input.service_continuity_benefit, "service_continuity_benefit"),
        assert_probability(input.access_equity_benefit, "access_equity_benefit"),
        assert_probability(input.resource_efficiency_benefit, "resource_efficiency_benefit"),
    }, "eco-impact inputs")

    local harm_risk = average({
        assert_probability(input.exclusion_risk, "exclusion_risk"),
        assert_probability(input.data_disclosure_risk, "data_disclosure_risk"),
        assert_probability(input.update_or_spectrum_outage_risk, "update_or_spectrum_outage_risk"),
        assert_probability(input.sensor_fusion_failure_risk, "sensor_fusion_failure_risk"),
        assert_probability(input.coercion_risk, "coercion_risk"),
    }, "harm-risk inputs")

    return {
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
    }
end

return universal_assistance_continuity_audit
