#ifndef AUGMENTED_HUB_CORRIDOR_DRIFT_AND_SAFETY_ASSURANCE_HPP
#define AUGMENTED_HUB_CORRIDOR_DRIFT_AND_SAFETY_ASSURANCE_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::assurance {

enum class AssuranceError {
    empty_input,
    invalid_numeric_input,
    duplicate_identifier,
    incompatible_time_window,
    insufficient_neighbor_evidence,
    invalid_watchdog_configuration,
    invalid_safety_state
};

enum class DriftStatus {
    nominal,
    possible_spatial_variation,
    drift_candidate_hold_for_review,
    recalibration_required
};

struct CorridorSensorObservation {
    std::string sensor_id;
    std::string phenomenon;
    double timestamp_seconds{};
    double measured_value{};
    double uncertainty_standard_deviation{};
    double expected_local_gradient_per_meter{};
    double distance_from_reference_m{};
    bool calibration_current{};
    bool independently_verified{};
};

struct NeighborEvidence {
    CorridorSensorObservation observation;
    double spatial_correlation_weight{};
};

struct DriftPolicy {
    double discrepancy_sigma_multiplier{3.0};
    double minimum_neighbor_weight_sum{1.0};
    double maximum_alignment_window_seconds{900.0};
    double maximum_uncorrected_drift_ratio{0.005};
    double minimum_independently_verified_neighbors{2.0};
};

struct DriftAssessment {
    double weighted_neighbor_estimate{};
    double expected_spatial_difference{};
    double normalized_discrepancy{};
    double corrected_candidate_value{};
    double neighbor_weight_sum{};
    std::size_t independently_verified_neighbor_count{};
    bool correction_candidate_available{};
    DriftStatus status{DriftStatus::possible_spatial_variation};
    std::string plain_language_explanation;
};

enum class SafetyMode {
    normal,
    restricted,
    safe_open,
    halted,
    degraded_hold_for_review
};

enum class SafetyEvent {
    heartbeat_received,
    heartbeat_timeout,
    person_detected,
    emergency_stop_pressed,
    emergency_stop_released,
    unsafe_ml_recommendation,
    verified_controller_command,
    post_incident_replay_requested
};

struct WatchdogPolicy {
    double maximum_heartbeat_interval_seconds{0.5};
    double maximum_response_time_seconds{0.25};
};

struct AutomationSafetyInputs {
    double current_time_seconds{};
    double last_heartbeat_seconds{};
    bool person_detected{};
    bool emergency_stop_pressed{};
    bool independent_safety_sensor_healthy{};
    bool verified_controller_available{};
    bool ml_component_healthy{};
    bool ml_recommendation_within_safe_envelope{};
};

struct SafetyAssessment {
    SafetyMode next_mode{SafetyMode::degraded_hold_for_review};
    bool autonomous_motion_permitted{};
    bool verified_fallback_required{};
    bool audit_replay_required{};
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<DriftAssessment, AssuranceError>
assess_corridor_sensor_drift(
    const CorridorSensorObservation& subject,
    const std::vector<NeighborEvidence>& neighbors,
    const DriftPolicy& policy);

[[nodiscard]] std::expected<SafetyAssessment, AssuranceError>
evaluate_layered_safety(
    SafetyMode current_mode,
    SafetyEvent event,
    const AutomationSafetyInputs& inputs,
    const WatchdogPolicy& policy);

[[nodiscard]] bool safety_liveness_property_holds(
    const SafetyAssessment& assessment,
    const AutomationSafetyInputs& inputs) noexcept;

}  // namespace augmented_hub::assurance

#endif
