local inclusive_smart_city_policy_audit = {}

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

local function assert_nonnegative(value, name)
    assert_finite(value, name)
    assert(value >= 0, name .. " must be non-negative")
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

local function clamp(value, lower, upper)
    if value < lower then
        return lower
    end
    if value > upper then
        return upper
    end
    return value
end

local function average(values, name)
    assert(type(values) == "table" and #values > 0, name .. " must be a non-empty array")

    local total = 0
    for index, value in ipairs(values) do
        total = total + assert_finite(value, name .. "[" .. index .. "]")
    end

    return total / #values
end

function inclusive_smart_city_policy_audit.non_certified_identity_policy(input)
    assert(type(input) == "table", "identity-policy input must be a table")

    local identity_stated = assert_boolean(input.identity_stated, "identity_stated")
    local internally_contradictory = assert_boolean(
        input.internally_contradictory,
        "internally_contradictory"
    )
    local entails_imminent_unlawful_harm = assert_boolean(
        input.entails_imminent_unlawful_harm,
        "entails_imminent_unlawful_harm"
    )
    local service_requires_eligibility = assert_boolean(
        input.service_requires_eligibility,
        "service_requires_eligibility"
    )
    local eligibility_proof_present = assert_boolean(
        input.eligibility_proof_present,
        "eligibility_proof_present"
    )
    local human_review_available = assert_boolean(
        input.human_review_available,
        "human_review_available"
    )
    local continuity_measure_available = assert_boolean(
        input.continuity_measure_available,
        "continuity_measure_available"
    )

    local recognition_eligible = identity_stated
        and not internally_contradictory
        and not entails_imminent_unlawful_harm

    local service_access_ready = not service_requires_eligibility
        or eligibility_proof_present

    return {
        recognition_eligible = recognition_eligible,
        certification_required_for_recognition = false,
        anti_discrimination_protection_required = recognition_eligible,
        service_access_ready = service_access_ready,
        human_review_available = human_review_available,
        continuity_measure_available = continuity_measure_available,
        policy_decision = recognition_eligible
            and "recognize the stated identity without certification; evaluate only service-relevant eligibility through a minimally disclosive process"
            or "do not automate exclusion; provide accountable human review and continuity while any concrete safety or logical issue is assessed",
        limitation = "This is a policy-design logic aid, not legal advice or a substitute for applicable human-rights, disability, privacy, administrative, or public-accommodation law.",
    }
end

function inclusive_smart_city_policy_audit.acceptance_influence_score(input)
    assert(type(input) == "table", "acceptance input must be a table")

    local peer_contact_quality = assert_probability(
        input.peer_contact_quality,
        "peer_contact_quality"
    )
    local visible_role_model_presence = assert_probability(
        input.visible_role_model_presence,
        "visible_role_model_presence"
    )
    local policy_recognition = assert_probability(
        input.policy_recognition,
        "policy_recognition"
    )
    local positive_media_quality = assert_probability(
        input.positive_media_quality,
        "positive_media_quality"
    )
    local discrimination_event_rate = assert_probability(
        input.discrimination_event_rate,
        "discrimination_event_rate"
    )
    local accessible_redress_quality = assert_probability(
        input.accessible_redress_quality,
        "accessible_redress_quality"
    )

    local fairness_signal = average({
        peer_contact_quality,
        visible_role_model_presence,
        policy_recognition,
        positive_media_quality,
        accessible_redress_quality,
    }, "fairness-signal inputs")

    local positive_shift_likelihood = clamp(
        fairness_signal * (1 - discrimination_event_rate),
        0,
        1
    )

    return {
        fairness_signal = fairness_signal,
        discrimination_event_rate = discrimination_event_rate,
        positive_acceptance_shift_likelihood = positive_shift_likelihood,
        interpretation = positive_shift_likelihood >= 0.75
            and "the supplied aggregate indicators support a positive acceptance-shift scenario"
            or "strengthen anti-discrimination safeguards, representation, policy recognition, and accessible redress before claiming positive momentum",
        limitation = "Metrics must be collected voluntarily, aggregated, and purpose-limited. They are not suitable for labeling, ranking, or inferring attitudes of identifiable people.",
    }
end

function inclusive_smart_city_policy_audit.privacy_preserving_dashboard(input)
    assert(type(input) == "table", "dashboard input must be a table")

    local aggregate_cell_population = assert_nonnegative(
        input.aggregate_cell_population,
        "aggregate_cell_population"
    )
    local minimum_release_population = assert_nonnegative(
        input.minimum_release_population,
        "minimum_release_population"
    )
    local time_window_days = assert_nonnegative(
        input.time_window_days,
        "time_window_days"
    )
    local minimum_time_window_days = assert_nonnegative(
        input.minimum_time_window_days,
        "minimum_time_window_days"
    )
    local direct_identifiers = assert_boolean(
        input.direct_identifiers_present,
        "direct_identifiers_present"
    )
    local persistent_identifiers = assert_boolean(
        input.persistent_identifiers_present,
        "persistent_identifiers_present"
    )
    local small_cell_suppression = assert_boolean(
        input.small_cell_suppression_enabled,
        "small_cell_suppression_enabled"
    )
    local uncertainty_shown = assert_boolean(
        input.uncertainty_shown,
        "uncertainty_shown"
    )
    local opt_out_path = assert_boolean(
        input.opt_out_or_nonparticipation_path,
        "opt_out_or_nonparticipation_path"
    )

    local release_population_safe =
        aggregate_cell_population >= minimum_release_population
    local release_time_safe = time_window_days >= minimum_time_window_days
    local no_identifiers = not direct_identifiers and not persistent_identifiers

    local publishable = release_population_safe
        and release_time_safe
        and no_identifiers
        and small_cell_suppression
        and uncertainty_shown
        and opt_out_path

    return {
        dashboard_publishable = publishable,
        release_population_safe = release_population_safe,
        release_time_safe = release_time_safe,
        no_identifiers = no_identifiers,
        small_cell_suppression_enabled = small_cell_suppression,
        uncertainty_shown = uncertainty_shown,
        opt_out_or_nonparticipation_path = opt_out_path,
        dashboard_rules = {
            "publish_only_aggregate_time_series",
            "suppress_small_cells",
            "avoid_identity_or_device_categories",
            "show_uncertainty_and_method_limits",
            "use_coarse_geographic_and_time_windows",
            "provide_nonparticipation_path",
        },
        decision = publishable
            and "publish aggregate trend changes with uncertainty and methodology notes"
            or "do not publish the dashboard view until aggregation, suppression, uncertainty, or participation safeguards are corrected",
    }
end

function inclusive_smart_city_policy_audit.sensor_fusion_robustness(input)
    assert(type(input) == "table", "sensor-fusion input must be a table")

    local thermal_occlusion_risk = assert_probability(
        input.thermal_occlusion_risk,
        "thermal_occlusion_risk"
    )
    local lidar_reflection_or_dropout_risk = assert_probability(
        input.lidar_reflection_or_dropout_risk,
        "lidar_reflection_or_dropout_risk"
    )
    local radar_multipath_risk = assert_probability(
        input.radar_multipath_risk,
        "radar_multipath_risk"
    )
    local vision_misclassification_risk = assert_probability(
        input.vision_misclassification_risk,
        "vision_misclassification_risk"
    )
    local sensor_disagreement_detected = assert_boolean(
        input.sensor_disagreement_detected,
        "sensor_disagreement_detected"
    )
    local non_automated_fallback = assert_boolean(
        input.non_automated_fallback_available,
        "non_automated_fallback_available"
    )
    local accessible_human_review = assert_boolean(
        input.accessible_human_review_available,
        "accessible_human_review_available"
    )

    local aggregate_failure_risk = average({
        thermal_occlusion_risk,
        lidar_reflection_or_dropout_risk,
        radar_multipath_risk,
        vision_misclassification_risk,
    }, "sensor-fusion risk inputs")

    local require_fallback = sensor_disagreement_detected
        or aggregate_failure_risk >= 0.25

    return {
        aggregate_failure_risk = aggregate_failure_risk,
        sensor_disagreement_detected = sensor_disagreement_detected,
        non_automated_fallback_available = non_automated_fallback,
        accessible_human_review_available = accessible_human_review,
        automated_high_impact_decision_permitted = false,
        require_fallback = require_fallback,
        decision = require_fallback
            and "avoid automated adverse treatment; preserve passage or service through a non-sensor-dependent path and log only de-identified system diagnostics"
            or "continue observational validation while retaining non-automated access and human review",
        limitation = "Treat implant, prosthetic, mobility-aid, and external-component interactions as diverse test conditions, not as identity categories. No individual tracking or medical inference is warranted.",
    }
end

function inclusive_smart_city_policy_audit.authentication_bias_resistance(input)
    assert(type(input) == "table", "authentication input must be a table")

    local biometric_required = assert_boolean(
        input.biometric_required,
        "biometric_required"
    )
    local non_biometric_alternative = assert_boolean(
        input.non_biometric_alternative_available,
        "non_biometric_alternative_available"
    )
    local alternative_equivalent_access = assert_boolean(
        input.alternative_provides_equivalent_access,
        "alternative_provides_equivalent_access"
    )
    local retry_or_human_review = assert_boolean(
        input.retry_or_human_review_available,
        "retry_or_human_review_available"
    )
    local biometric_failure_parity = assert_probability(
        input.biometric_failure_parity,
        "biometric_failure_parity"
    )
    local identity_or_health_disclosure_required = assert_boolean(
        input.identity_or_health_disclosure_required,
        "identity_or_health_disclosure_required"
    )
    local continuous_retraining_on_people = assert_boolean(
        input.continuous_retraining_on_people,
        "continuous_retraining_on_people"
    )

    local privacy_respecting = not identity_or_health_disclosure_required
        and not continuous_retraining_on_people
    local inclusive_path = not biometric_required
        or (
            non_biometric_alternative
            and alternative_equivalent_access
            and retry_or_human_review
        )

    local bias_resistant = inclusive_path
        and privacy_respecting
        and biometric_failure_parity >= 0.95

    return {
        biometric_required = biometric_required,
        non_biometric_alternative_available = non_biometric_alternative,
        alternative_provides_equivalent_access = alternative_equivalent_access,
        retry_or_human_review_available = retry_or_human_review,
        biometric_failure_parity = biometric_failure_parity,
        privacy_respecting = privacy_respecting,
        bias_resistant_design = bias_resistant,
        decision = bias_resistant
            and "offer the non-biometric path as an equal, immediate service route and continue aggregate failure-parity monitoring"
            or "redesign authentication so no person must disclose health or identity information or repeatedly fail a biometric gate to obtain equal service",
        limitation = "This checks declared accessibility and privacy properties. It does not validate a biometric system, establish legal compliance, or justify collection of biometric data.",
    }
end

function inclusive_smart_city_policy_audit.assessment_metrics(input)
    assert(type(input) == "table", "metrics input must be a table")

    local knowledge_factor = average({
        assert_probability(input.policy_evidence_quality, "policy_evidence_quality"),
        assert_probability(input.aggregate_validation_coverage, "aggregate_validation_coverage"),
        assert_probability(input.accessibility_testing_coverage, "accessibility_testing_coverage"),
        assert_probability(input.privacy_review_quality, "privacy_review_quality"),
    }, "knowledge-factor inputs")

    local eco_impact_value = average({
        assert_probability(input.service_continuity_benefit, "service_continuity_benefit"),
        assert_probability(input.access_equity_benefit, "access_equity_benefit"),
        assert_probability(input.resource_efficiency_benefit, "resource_efficiency_benefit"),
    }, "eco-impact inputs")

    local harm_risk = average({
        assert_probability(input.exclusion_risk, "exclusion_risk"),
        assert_probability(input.data_disclosure_risk, "data_disclosure_risk"),
        assert_probability(input.sensor_failure_risk, "sensor_failure_risk"),
        assert_probability(input.biometric_bias_risk, "biometric_bias_risk"),
    }, "harm-risk inputs")

    return {
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
    }
end

return inclusive_smart_city_policy_audit
