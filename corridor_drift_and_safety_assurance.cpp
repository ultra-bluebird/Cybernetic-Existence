#include "corridor_drift_and_safety_assurance.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <unordered_set>

namespace augmented_hub::assurance {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool valid_observation(const CorridorSensorObservation& observation) {
    return !observation.sensor_id.empty() &&
        !observation.phenomenon.empty() &&
        std::isfinite(observation.timestamp_seconds) &&
        std::isfinite(observation.measured_value) &&
        finite_nonnegative(observation.uncertainty_standard_deviation) &&
        std::isfinite(observation.expected_local_gradient_per_meter) &&
        finite_nonnegative(observation.distance_from_reference_m);
}

bool heartbeat_is_current(
    const AutomationSafetyInputs& inputs,
    const WatchdogPolicy& policy) noexcept {

    return inputs.current_time_seconds >= inputs.last_heartbeat_seconds &&
        inputs.current_time_seconds - inputs.last_heartbeat_seconds <=
            policy.maximum_heartbeat_interval_seconds;
}

bool emergency_or_person_present(
    const AutomationSafetyInputs& inputs) noexcept {

    return inputs.emergency_stop_pressed || inputs.person_detected;
}

}  // namespace

std::expected<DriftAssessment, AssuranceError>
assess_corridor_sensor_drift(
    const CorridorSensorObservation& subject,
    const std::vector<NeighborEvidence>& neighbors,
    const DriftPolicy& policy) {

    if (!valid_observation(subject) || neighbors.empty()) {
        return std::unexpected(AssuranceError::empty_input);
    }

    if (!finite_nonnegative(policy.discrepancy_sigma_multiplier) ||
        policy.discrepancy_sigma_multiplier <= 0.0 ||
        !finite_nonnegative(policy.minimum_neighbor_weight_sum) ||
        !finite_nonnegative(policy.maximum_alignment_window_seconds) ||
        !finite_nonnegative(policy.maximum_uncorrected_drift_ratio) ||
        policy.minimum_independently_verified_neighbors < 1.0) {
        return std::unexpected(AssuranceError::invalid_numeric_input);
    }

    std::unordered_set<std::string> neighbor_identifiers;
    double weighted_neighbor_sum = 0.0;
    double neighbor_weight_sum = 0.0;
    double expected_spatial_difference_sum = 0.0;
    double combined_variance = subject.uncertainty_standard_deviation *
        subject.uncertainty_standard_deviation;

    std::size_t independently_verified_neighbor_count = 0U;

    for (const auto& neighbor : neighbors) {
        if (!valid_observation(neighbor.observation) ||
            neighbor.observation.phenomenon != subject.phenomenon ||
            neighbor.observation.sensor_id == subject.sensor_id ||
            !neighbor_identifiers.insert(neighbor.observation.sensor_id).second ||
            !finite_nonnegative(neighbor.spatial_correlation_weight) ||
            neighbor.spatial_correlation_weight <= 0.0) {
            return std::unexpected(AssuranceError::invalid_numeric_input);
        }

        const double alignment_delta =
            std::abs(
                neighbor.observation.timestamp_seconds -
                subject.timestamp_seconds);

        if (alignment_delta > policy.maximum_alignment_window_seconds) {
            return std::unexpected(AssuranceError::incompatible_time_window);
        }

        weighted_neighbor_sum +=
            neighbor.spatial_correlation_weight *
            neighbor.observation.measured_value;

        neighbor_weight_sum += neighbor.spatial_correlation_weight;

        expected_spatial_difference_sum +=
            neighbor.spatial_correlation_weight *
            neighbor.observation.expected_local_gradient_per_meter *
            std::abs(
                neighbor.observation.distance_from_reference_m -
                subject.distance_from_reference_m);

        combined_variance +=
            neighbor.spatial_correlation_weight *
            neighbor.observation.uncertainty_standard_deviation *
            neighbor.observation.uncertainty_standard_deviation;

        if (neighbor.observation.independently_verified &&
            neighbor.observation.calibration_current) {
            ++independently_verified_neighbor_count;
        }
    }

    if (neighbor_weight_sum < policy.minimum_neighbor_weight_sum) {
        return std::unexpected(
            AssuranceError::insufficient_neighbor_evidence);
    }

    const double weighted_neighbor_estimate =
        weighted_neighbor_sum / neighbor_weight_sum;

    const double expected_spatial_difference =
        expected_spatial_difference_sum / neighbor_weight_sum;

    const double discrepancy =
        std::abs(subject.measured_value - weighted_neighbor_estimate);

    const double expected_standard_deviation =
        std::sqrt(std::max(combined_variance, kEpsilon));

    const double normalized_discrepancy =
        std::max(
            discrepancy - expected_spatial_difference,
            0.0) / expected_standard_deviation;

    const double corrected_candidate_value =
        (subject.measured_value + weighted_neighbor_sum) /
        (1.0 + neighbor_weight_sum);

    const bool enough_independent_neighbors =
        independently_verified_neighbor_count >=
        static_cast<std::size_t>(
            policy.minimum_independently_verified_neighbors);

    const bool possible_drift =
        normalized_discrepancy > policy.discrepancy_sigma_multiplier &&
        enough_independent_neighbors;

    const double reference_magnitude =
        std::max(std::abs(subject.measured_value), kEpsilon);

    const bool recalibration_required =
        possible_drift &&
        std::abs(subject.measured_value - corrected_candidate_value) /
            reference_magnitude >
            policy.maximum_uncorrected_drift_ratio;

    const DriftStatus status =
        recalibration_required
            ? DriftStatus::recalibration_required
            : possible_drift
                ? DriftStatus::drift_candidate_hold_for_review
                : DriftStatus::possible_spatial_variation;

    return DriftAssessment{
        .weighted_neighbor_estimate = weighted_neighbor_estimate,
        .expected_spatial_difference = expected_spatial_difference,
        .normalized_discrepancy = normalized_discrepancy,
        .corrected_candidate_value = corrected_candidate_value,
        .neighbor_weight_sum = neighbor_weight_sum,
        .independently_verified_neighbor_count =
            independently_verified_neighbor_count,
        .correction_candidate_available = possible_drift,
        .status = status,
        .plain_language_explanation =
            recalibration_required
                ? "The discrepancy exceeds the spatial-gradient and uncertainty-adjusted drift threshold, and independently verified neighboring evidence supports a recalibration requirement. The correction is preserved as a candidate; raw evidence remains unchanged."
                : possible_drift
                    ? "The discrepancy is more consistent with possible sensor drift than expected spatial variation. A candidate correction is available for review before it is used in a validated metric."
                    : "The observed difference is consistent with stated local spatial variation, timing, and uncertainty. The result remains available for trend monitoring."
    };
}

std::expected<SafetyAssessment, AssuranceError>
evaluate_layered_safety(
    SafetyMode current_mode,
    SafetyEvent event,
    const AutomationSafetyInputs& inputs,
    const WatchdogPolicy& policy) {

    if (!std::isfinite(inputs.current_time_seconds) ||
        !std::isfinite(inputs.last_heartbeat_seconds) ||
        !finite_nonnegative(policy.maximum_heartbeat_interval_seconds) ||
        policy.maximum_heartbeat_interval_seconds <= 0.0 ||
        !finite_nonnegative(policy.maximum_response_time_seconds) ||
        policy.maximum_response_time_seconds <= 0.0) {
        return std::unexpected(
            AssuranceError::invalid_watchdog_configuration);
    }

    const bool watchdog_ok = heartbeat_is_current(inputs, policy);
    const bool immediate_safe_state_required =
        emergency_or_person_present(inputs) ||
        !inputs.independent_safety_sensor_healthy ||
        !inputs.verified_controller_available ||
        !watchdog_ok;

    if (inputs.emergency_stop_pressed ||
        event == SafetyEvent::emergency_stop_pressed) {
        return SafetyAssessment{
            .next_mode = SafetyMode::halted,
            .autonomous_motion_permitted = false,
            .verified_fallback_required = true,
            .audit_replay_required = true,
            .plain_language_explanation =
                "Emergency stop is authoritative. Autonomous motion is disabled, the system enters a halted state, and an auditable inspection and reset workflow is required."
        };
    }

    if (inputs.person_detected ||
        event == SafetyEvent::person_detected) {
        return SafetyAssessment{
            .next_mode = SafetyMode::safe_open,
            .autonomous_motion_permitted = false,
            .verified_fallback_required = true,
            .audit_replay_required = false,
            .plain_language_explanation =
                "A person is detected in the protected area. The safety layer inhibits unsafe motion and transitions to a verified safe-open state."
        };
    }

    if (immediate_safe_state_required ||
        event == SafetyEvent::heartbeat_timeout) {
        return SafetyAssessment{
            .next_mode = SafetyMode::degraded_hold_for_review,
            .autonomous_motion_permitted = false,
            .verified_fallback_required = true,
            .audit_replay_required = true,
            .plain_language_explanation =
                "The watchdog, independent safety sensor, or verified controller does not satisfy its required health condition. The system enters a degraded hold-for-review state and does not permit autonomous motion."
        };
    }

    if (event == SafetyEvent::unsafe_ml_recommendation ||
        !inputs.ml_component_healthy ||
        !inputs.ml_recommendation_within_safe_envelope) {
        return SafetyAssessment{
            .next_mode = SafetyMode::restricted,
            .autonomous_motion_permitted = false,
            .verified_fallback_required = true,
            .audit_replay_required = true,
            .plain_language_explanation =
                "The machine-learning component is unavailable, unhealthy, or produced a recommendation outside the verified safe envelope. Its output is rejected and the verified fallback path retains authority."
        };
    }

    if (event == SafetyEvent::post_incident_replay_requested) {
        return SafetyAssessment{
            .next_mode = SafetyMode::degraded_hold_for_review,
            .autonomous_motion_permitted = false,
            .verified_fallback_required = false,
            .audit_replay_required = true,
            .plain_language_explanation =
                "A post-incident replay has been requested. The system preserves evidence and enters review mode without changing physical operation authority."
        };
    }

    if (event == SafetyEvent::verified_controller_command ||
        event == SafetyEvent::heartbeat_received) {
        return SafetyAssessment{
            .next_mode = SafetyMode::normal,
            .autonomous_motion_permitted = true,
            .verified_fallback_required = false,
            .audit_replay_required = false,
            .plain_language_explanation =
                "Independent safety sensing, watchdog timing, and the verified controller satisfy the current operational envelope. Any machine-learning output remains advisory and constrained by the verified controller."
        };
    }

    return SafetyAssessment{
        .next_mode = current_mode,
        .autonomous_motion_permitted = false,
        .verified_fallback_required = true,
        .audit_replay_required = false,
        .plain_language_explanation =
            "No verified condition authorizes a transition to autonomous motion. The current safety mode remains in effect."
    };
}

bool safety_liveness_property_holds(
    const SafetyAssessment& assessment,
    const AutomationSafetyInputs& inputs) noexcept {

    if (inputs.person_detected) {
        return assessment.next_mode == SafetyMode::safe_open ||
            assessment.next_mode == SafetyMode::halted ||
            assessment.next_mode == SafetyMode::degraded_hold_for_review;
    }

    if (inputs.emergency_stop_pressed) {
        return assessment.next_mode == SafetyMode::halted;
    }

    return true;
}

}  // namespace augmented_hub::assurance
