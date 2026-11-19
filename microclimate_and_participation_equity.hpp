#ifndef AUGMENTED_HUB_MICROCLIMATE_AND_PARTICIPATION_EQUITY_HPP
#define AUGMENTED_HUB_MICROCLIMATE_AND_PARTICIPATION_EQUITY_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::community_equity {

enum class EquityPlanningError {
    empty_input,
    invalid_numeric_input,
    duplicate_identifier,
    infeasible_coverage_constraint,
    insufficient_aggregation,
    invalid_time_sequence
};

struct NeighborhoodMicroclimateCell {
    std::string cell_id;
    std::string neighborhood_id;
    double centroid_x_m{};
    double centroid_y_m{};
    double baseline_prediction_variance{};
    double heat_exposure_weight{};
    bool monitoring_priority{};
};

struct SensorCandidateSite {
    std::string site_id;
    double x_m{};
    double y_m{};
    double installation_cost{};
    double annual_maintenance_cost{};
    double expected_measurement_variance{};
    bool temperature_supported{};
    bool humidity_supported{};
    bool solar_radiation_supported{};
    bool wind_supported{};
};

struct MicroclimatePlacementPolicy {
    double total_budget{};
    double maximum_prediction_variance{};
    double minimum_priority_coverage_fraction{1.0};
    double maximum_coverage_distance_m{500.0};
    double variance_decay_distance_m{300.0};
    std::size_t minimum_sites_per_priority_neighborhood{1};
};

struct MicroclimatePlacementAssessment {
    std::vector<std::string> selected_site_ids;
    double total_cost{};
    double maximum_residual_prediction_variance{};
    double weighted_residual_prediction_variance{};
    std::size_t priority_neighborhoods_covered{};
    std::size_t priority_neighborhood_count{};
    bool equity_variance_constraint_satisfied{};
    bool coverage_constraint_satisfied{};
    std::string plain_language_explanation;
};

struct GeographicParticipationAggregate {
    std::string neighborhood_id;
    std::size_t aggregate_participant_count{};
    std::size_t population_estimate{};
    double participation_barrier_report_rate{};
    double accessible_event_availability{};
    double offline_participation_availability{};
    double language_access_availability{};
    bool data_is_non_identifying{true};
    bool feedback_is_voluntary{true};
};

struct ParticipationEquityPolicy {
    std::size_t minimum_aggregation_count{20};
    double minimum_population_estimate{1.0};
    double minimum_accessible_event_availability{0.0};
    double minimum_offline_participation_availability{0.0};
    double minimum_language_access_availability{0.0};
};

struct ParticipationEquityAssessment {
    double participation_equity_index{};
    double minimum_participation_rate{};
    double maximum_participation_rate{};
    double average_barrier_report_rate{};
    std::vector<std::string> neighborhoods_requiring_barrier_review;
    bool aggregate_evidence_eligible{};
    std::string plain_language_explanation;
};

[[nodiscard]]
std::expected<MicroclimatePlacementAssessment, EquityPlanningError>
select_microclimate_sensor_sites(
    const std::vector<NeighborhoodMicroclimateCell>& cells,
    const std::vector<SensorCandidateSite>& candidate_sites,
    const MicroclimatePlacementPolicy& policy);

[[nodiscard]]
std::expected<ParticipationEquityAssessment, EquityPlanningError>
evaluate_geographic_participation_equity(
    const std::vector<GeographicParticipationAggregate>& aggregates,
    const ParticipationEquityPolicy& policy);

}  // namespace augmented_hub::community_equity

#endif
