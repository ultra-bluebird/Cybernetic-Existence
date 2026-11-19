#ifndef AUGMENTED_HUB_SPATIOTEMPORAL_ANOMALY_AND_PARETO_PLANNING_HPP
#define AUGMENTED_HUB_SPATIOTEMPORAL_ANOMALY_AND_PARETO_PLANNING_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::advanced_analytics {

enum class AnalyticsError {
    empty_input,
    invalid_numeric_input,
    duplicate_identifier,
    incompatible_observation_window,
    insufficient_baseline_evidence,
    invalid_calibration_event,
    infeasible_tradeoff_constraint
};

enum class CalibrationState {
    stable,
    recalibration_window,
    post_recalibration_stabilization,
    validated
};

enum class AnomalyClassification {
    nominal,
    local_sensor_candidate,
    distributed_environmental_candidate,
    recalibration_related_hold_for_review
};

struct SpatioTemporalObservation {
    std::string sensor_id;
    std::string location_cell_id;
    double timestamp_seconds{};
    double measured_value{};
    double trend_value{};
    double seasonal_value{};
    double expected_standard_deviation{};
    CalibrationState calibration_state{CalibrationState::stable};
    double calibration_completed_at_seconds{};
};

struct SpatialNeighbor {
    std::string source_sensor_id;
    std::string neighbor_sensor_id;
    double spatial_weight{};
    double expected_gradient_adjustment{};
};

struct AnomalyPolicy {
    double baseline_z_threshold{3.0};
    double recalibration_z_threshold{4.5};
    double post_calibration_stabilization_seconds{3600.0};
    double distributed_event_neighbor_fraction{0.50};
    std::size_t minimum_neighbor_count{2};
    double maximum_threshold_multiplier{2.0};
};

struct AnomalyAssessment {
    double temporal_residual{};
    double standardized_temporal_score{};
    double local_moran_proxy{};
    double neighbor_anomaly_fraction{};
    double active_threshold{};
    AnomalyClassification classification{
        AnomalyClassification::recalibration_related_hold_for_review
    };
    bool review_required{};
    std::string plain_language_explanation;
};

struct InfrastructureScenario {
    std::string scenario_id;
    double ecological_benefit{};
    double social_inequity{};
    double total_cost{};
    double accessibility_benefit{};
    double harm_risk{};
    bool satisfies_non_discrimination_invariant{};
    bool preserves_essential_access{};
};

struct EpsilonConstraintPolicy {
    double maximum_social_inequity{};
    double maximum_total_cost{};
    double minimum_accessibility_benefit{};
    double maximum_harm_risk{};
    bool require_non_discrimination_invariant{true};
    bool require_essential_access_preservation{true};
};

struct ParetoPlanningAssessment {
    std::vector<std::string> feasible_scenario_ids;
    std::vector<std::string> pareto_optimal_scenario_ids;
    std::string recommended_review_set_description;
    bool stakeholder_review_required{};
    std::string plain_language_explanation;
};

[[nodiscard]]
std::expected<AnomalyAssessment, AnalyticsError>
assess_spatiotemporal_anomaly(
    const SpatioTemporalObservation& subject,
    const std::vector<SpatioTemporalObservation>& neighborhood_observations,
    const std::vector<SpatialNeighbor>& spatial_neighbors,
    const AnomalyPolicy& policy);

[[nodiscard]]
std::expected<ParetoPlanningAssessment, AnalyticsError>
evaluate_pareto_infrastructure_scenarios(
    const std::vector<InfrastructureScenario>& scenarios,
    const EpsilonConstraintPolicy& policy);

}  // namespace augmented_hub::advanced_analytics

#endif
