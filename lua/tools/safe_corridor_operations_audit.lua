local safe_corridor_operations_audit = {}

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

local function assert_nonnegative(value, field_name)
    assert_finite(value, field_name)
    assert(value >= 0, field_name .. " must be non-negative")
    return value
end

local function assert_positive(value, field_name)
    assert_nonnegative(value, field_name)
    assert(value > 0, field_name .. " must be greater than zero")
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

local function clamp(value, lower, upper)
    if value < lower then
        return lower
    end
    if value > upper then
        return upper
    end
    return value
end

local function mean(values, field_name)
    assert(type(values) == "table" and #values > 0,
        field_name .. " must be a non-empty array")

    local total = 0
    for index, value in ipairs(values) do
        total = total + assert_finite(value, field_name .. "[" .. index .. "]")
    end

    return total / #values
end

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function safe_corridor_operations_audit.dual_channel_stop_loop(input)
    assert(type(input) == "table", "stop-loop input must be a table")

    local channel_a_independent = assert_boolean(
        input.channel_a_independent,
        "channel_a_independent"
    )
    local channel_b_independent = assert_boolean(
        input.channel_b_independent,
        "channel_b_independent"
    )
    local test_pulse_a = assert_boolean(input.test_pulse_a, "test_pulse_a")
    local test_pulse_b = assert_boolean(input.test_pulse_b, "test_pulse_b")
    local discrepancy_detection = assert_boolean(
        input.discrepancy_detection,
        "discrepancy_detection"
    )
    local monitored_reset = assert_boolean(
        input.monitored_manual_reset,
        "monitored_manual_reset"
    )
    local safe_state_preserves_egress = assert_boolean(
        input.safe_state_preserves_egress,
        "safe_state_preserves_egress"
    )
    local qualified_validation = assert_boolean(
        input.qualified_validation,
        "qualified_validation"
    )
    local measured_false_trip_rate = assert_probability(
        input.measured_false_trip_rate,
        "measured_false_trip_rate"
    )
    local maximum_false_trip_rate = assert_probability(
        input.maximum_false_trip_rate,
        "maximum_false_trip_rate"
    )

    local architecture_ready = channel_a_independent
        and channel_b_independent
        and test_pulse_a
        and test_pulse_b
        and discrepancy_detection
        and monitored_reset
        and safe_state_preserves_egress
        and qualified_validation

    local false_trip_within_target =
        measured_false_trip_rate <= maximum_false_trip_rate

    return {
        architecture_ready = architecture_ready,
        false_trip_within_target = false_trip_within_target,
        safe_for_certification_claim = false,
        required_controls = {
            "independent_dual_channels",
            "separate_test_pulses",
            "cross_fault_and_discrepancy_detection",
            "monitored_manual_reset",
            "safe_state_with_egress",
            "measured_false_trip_characterization",
            "qualified_safety_validation",
        },
        decision = architecture_ready and false_trip_within_target
            and "submit the measured implementation for qualified functional-safety assessment; do not claim a performance level or safety-integrity level from this audit"
            or "correct channel independence, diagnostics, egress, validation, or false-trip gaps before further safety assessment",
        limitation = "This module cannot design a safety circuit, calculate PL or SIL, certify equipment, or authorize operation of life-safety or motion-control systems.",
    }
end

function safe_corridor_operations_audit.heat_alert_pipeline(input)
    assert(type(input) == "table", "heat-alert input must be a table")

    local ingest_ms = assert_nonnegative(input.ingest_ms, "ingest_ms")
    local edge_processing_ms = assert_nonnegative(
        input.edge_processing_ms,
        "edge_processing_ms"
    )
    local local_storage_ms = assert_nonnegative(
        input.local_storage_ms,
        "local_storage_ms"
    )
    local alert_evaluation_ms = assert_nonnegative(
        input.alert_evaluation_ms,
        "alert_evaluation_ms"
    )
    local delivery_ms = assert_nonnegative(input.delivery_ms, "delivery_ms")
    local latency_target_ms = assert_positive(
        input.latency_target_ms,
        "latency_target_ms"
    )
    local availability = assert_probability(input.availability, "availability")
    local availability_target = assert_probability(
        input.availability_target,
        "availability_target"
    )
    local local_buffering = assert_boolean(
        input.local_buffering,
        "local_buffering"
    )
    local failover_available = assert_boolean(
        input.failover_available,
        "failover_available"
    )
    local method_and_uncertainty_disclosed = assert_boolean(
        input.method_and_uncertainty_disclosed,
        "method_and_uncertainty_disclosed"
    )

    local end_to_end_latency_ms =
        ingest_ms + edge_processing_ms + local_storage_ms
        + alert_evaluation_ms + delivery_ms

    local latency_target_met = end_to_end_latency_ms <= latency_target_ms
    local availability_target_met = availability >= availability_target
    local resilience_ready = local_buffering and failover_available

    return {
        end_to_end_latency_ms = end_to_end_latency_ms,
        latency_target_ms = latency_target_ms,
        latency_target_met = latency_target_met,
        availability = availability,
        availability_target = availability_target,
        availability_target_met = availability_target_met,
        local_buffering = local_buffering,
        failover_available = failover_available,
        method_and_uncertainty_disclosed = method_and_uncertainty_disclosed,
        resilience_ready = resilience_ready,
        decision = latency_target_met
            and availability_target_met
            and resilience_ready
            and method_and_uncertainty_disclosed
            and "the supplied pipeline meets its declared operational targets; retain local buffering, failover exercises, and uncertainty-aware public alert wording"
            or "do not claim target performance; reduce the measured critical path and improve redundancy, observability, or disclosure controls",
        limitation = "This is a timing and availability budget audit. It does not select a database, operate alerting infrastructure, or guarantee sub-second latency or availability under real network and load conditions.",
    }
end

function safe_corridor_operations_audit.mutual_information_alignment(input)
    assert(type(input) == "table", "alignment input must be a table")
    assert(type(input.stream_pairs) == "table" and #input.stream_pairs > 0,
        "stream_pairs must be a non-empty array")

    local acceptance_threshold = assert_nonnegative(
        input.acceptance_threshold,
        "acceptance_threshold"
    )
    local temporal_consistency = assert_probability(
        input.temporal_consistency,
        "temporal_consistency"
    )
    local geometric_consistency = assert_probability(
        input.geometric_consistency,
        "geometric_consistency"
    )

    local pairs = {}
    local values = {}

    for index, pair in ipairs(input.stream_pairs) do
        assert(type(pair) == "table",
            "stream_pairs[" .. index .. "] must be a table")

        local id = assert_string(pair.id, "stream_pairs[" .. index .. "].id")
        local mutual_information = assert_nonnegative(
            pair.mutual_information,
            "stream_pairs[" .. index .. "].mutual_information"
        )
        local quality = assert_probability(
            pair.observation_quality,
            "stream_pairs[" .. index .. "].observation_quality"
        )

        values[#values + 1] = mutual_information
        pairs[#pairs + 1] = {
            id = id,
            mutual_information = mutual_information,
            observation_quality = quality,
            pair_accepts = mutual_information >= acceptance_threshold
                and quality >= 0.7,
        }
    end

    local mean_mutual_information = mean(values, "mutual information values")
    local alignment_candidate =
        mean_mutual_information >= acceptance_threshold
        and temporal_consistency >= 0.7
        and geometric_consistency >= 0.7

    return {
        mean_mutual_information = mean_mutual_information,
        acceptance_threshold = acceptance_threshold,
        temporal_consistency = temporal_consistency,
        geometric_consistency = geometric_consistency,
        alignment_candidate = alignment_candidate,
        stream_pairs = pairs,
        decision = alignment_candidate
            and "treat the streams as a candidate alignment result and confirm with independent geometric residuals and diverse field scenes"
            or "retain the alignment as unvalidated; inspect timing, calibration, observability, and scene-dependence before any high-impact use",
        limitation = "Mutual information is an alignment signal, not proof of correct extrinsics. It can be affected by shared noise, texture, scene content, and preprocessing choices.",
    }
end

function safe_corridor_operations_audit.conversion_loss_budget(input)
    assert(type(input) == "table", "loss input must be a table")
    assert(type(input.stages) == "table" and #input.stages > 0,
        "stages must be a non-empty array")

    local input_energy_wh = assert_positive(
        input.input_energy_wh,
        "input_energy_wh"
    )
    local total_loss_wh = 0
    local stages = {}

    for index, stage in ipairs(input.stages) do
        assert(type(stage) == "table", "stages[" .. index .. "] must be a table")

        local id = assert_string(stage.id, "stages[" .. index .. "].id")
        local efficiency = assert_probability(
            stage.efficiency,
            "stages[" .. index .. "].efficiency"
        )
        local avoidable_fraction = assert_probability(
            stage.avoidable_loss_fraction,
            "stages[" .. index .. "].avoidable_loss_fraction"
        )
        local input_to_stage_wh = input_energy_wh - total_loss_wh
        local loss_wh = input_to_stage_wh * (1 - efficiency)
        local avoidable_loss_wh = loss_wh * avoidable_fraction

        total_loss_wh = total_loss_wh + loss_wh
        stages[#stages + 1] = {
            id = id,
            efficiency = efficiency,
            loss_wh = loss_wh,
            avoidable_loss_wh = avoidable_loss_wh,
            avoidable_loss_fraction = avoidable_fraction,
        }
    end

    local output_energy_wh = math.max(0, input_energy_wh - total_loss_wh)
    local total_avoidable_loss_wh = 0

    for _, stage in ipairs(stages) do
        total_avoidable_loss_wh = total_avoidable_loss_wh + stage.avoidable_loss_wh
    end

    return {
        input_energy_wh = input_energy_wh,
        output_energy_wh = output_energy_wh,
        total_loss_wh = total_loss_wh,
        total_avoidable_loss_wh = total_avoidable_loss_wh,
        overall_efficiency = output_energy_wh / input_energy_wh,
        stages = stages,
        reduction_priorities = stages,
        limitation = "Avoidable-loss fractions must come from measured load profiles and component characterization. This audit does not design power electronics or establish safe operating limits.",
    }
end

function safe_corridor_operations_audit.interoperable_corridor_protection(input)
    assert(type(input) == "table", "protection input must be a table")

    local source_authentication = assert_boolean(
        input.source_authentication,
        "source_authentication"
    )
    local message_integrity = assert_boolean(
        input.message_integrity,
        "message_integrity"
    )
    local replay_detection = assert_boolean(
        input.replay_detection,
        "replay_detection"
    )
    local rate_limiting = assert_boolean(input.rate_limiting, "rate_limiting")
    local anomaly_logging = assert_boolean(
        input.anomaly_logging,
        "anomaly_logging"
    )
    local least_privilege_commands = assert_boolean(
        input.least_privilege_commands,
        "least_privilege_commands"
    )
    local local_safe_state = assert_boolean(
        input.local_safe_state,
        "local_safe_state"
    )
    local noninvasive_interoperability = assert_boolean(
        input.noninvasive_interoperability,
        "noninvasive_interoperability"
    )
    local no_identity_or_health_disclosure = assert_boolean(
        input.no_identity_or_health_disclosure,
        "no_identity_or_health_disclosure"
    )
    local accessible_human_fallback = assert_boolean(
        input.accessible_human_fallback,
        "accessible_human_fallback"
    )

    local protection_score = mean({
        source_authentication and 1 or 0,
        message_integrity and 1 or 0,
        replay_detection and 1 or 0,
        rate_limiting and 1 or 0,
        anomaly_logging and 1 or 0,
        least_privilege_commands and 1 or 0,
        local_safe_state and 1 or 0,
        noninvasive_interoperability and 1 or 0,
        no_identity_or_health_disclosure and 1 or 0,
        accessible_human_fallback and 1 or 0,
    }, "protection controls")

    local ready = source_authentication
        and message_integrity
        and replay_detection
        and least_privilege_commands
        and local_safe_state
        and noninvasive_interoperability
        and no_identity_or_health_disclosure
        and accessible_human_fallback

    return {
        protection_score = protection_score,
        protection_ready = ready,
        required_properties = {
            "authenticated_and_integrity_checked_control_messages",
            "replay_detection_and_rate_limits",
            "least_privilege_actuator_commands",
            "local_safe_state_when_trust_is_lost",
            "privacy_minimizing_assistive_interoperability",
            "no_medical_or_identity_disclosure_requirement",
            "accessible_human_fallback",
        },
        decision = ready
            and "use a privacy-minimizing interoperable interface with local safe-state behavior and accountable diagnostics"
            or "do not rely on the corridor for high-impact automation until protection, privacy, and continuity gaps are closed",
        limitation = "This is a high-level safety and interoperability checklist. It does not implement security protocols, perform penetration testing, control actuators, or replace independent review.",
    }
end

function safe_corridor_operations_audit.assessment_metrics(input)
    assert(type(input) == "table", "metrics input must be a table")

    local knowledge_factor = mean({
        assert_probability(input.safety_validation_coverage, "safety_validation_coverage"),
        assert_probability(input.latency_and_availability_measurement_quality, "latency_and_availability_measurement_quality"),
        assert_probability(input.alignment_validation_coverage, "alignment_validation_coverage"),
        assert_probability(input.power_measurement_quality, "power_measurement_quality"),
        assert_probability(input.interoperability_review_quality, "interoperability_review_quality"),
    }, "knowledge-factor inputs")

    local eco_impact_value = mean({
        assert_probability(input.heat_alert_benefit, "heat_alert_benefit"),
        assert_probability(input.energy_efficiency_benefit, "energy_efficiency_benefit"),
        assert_probability(input.service_continuity_benefit, "service_continuity_benefit"),
        assert_probability(input.accessibility_benefit, "accessibility_benefit"),
    }, "eco-impact inputs")

    local harm_risk = mean({
        assert_probability(input.false_trip_or_stop_risk, "false_trip_or_stop_risk"),
        assert_probability(input.alert_failure_risk, "alert_failure_risk"),
        assert_probability(input.alignment_failure_risk, "alignment_failure_risk"),
        assert_probability(input.power_quality_risk, "power_quality_risk"),
        assert_probability(input.spoofing_or_exclusion_risk, "spoofing_or_exclusion_risk"),
    }, "harm-risk inputs")

    return {
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
    }
end

return safe_corridor_operations_audit
