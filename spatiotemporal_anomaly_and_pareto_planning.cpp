#include "spatiotemporal_anomaly_and_pareto_planning.hpp"

#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <unordered_set>

namespace augmented_hub::advanced_analytics {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

bool valid_observation(const SpatioTemporalObservation& observation) {
    return !observation.sensor_id.empty() &&
        !observation.location_cell_id.empty() &&
        std::isfinite(observation.timestamp_seconds) &&
        std::isfinite(observation.measured_value) &&
        std::isfinite(observation.trend_value) &&
        std::isfinite(observation.seasonal_value) &&
        finite_nonnegative(observation.expected_standard_deviation) &&
        std::isfinite(observation.calibration_completed_at_seconds);
}

bool dominates(
    const InfrastructureScenario& left,
    const InfrastructureScenario& right) noexcept {

    const bool no_worse =
        left.ecological_benefit >= right.ecological_benefit &&
        left.social_inequity <= right.social_inequity &&
        left.total_cost <= right.total_cost &&
        left.accessibility_benefit >= right.accessibility_benefit &&
        left.harm_risk <= right.harm_risk;

    const bool strictly_better_somewhere =
        left.ecological_benefit > right.ecological_benefit ||
        left.social_inequity < right.social_inequity ||
        left.total_cost < right.total_cost ||
        left.accessibility_benefit > right.accessibility_benefit ||
        left.harm_risk < right.harm_risk;

    return no_worse && strictly_better_somewhere;
}

}  // namespace

std::expected<AnomalyAssessment, AnalyticsError>
assess_spatiotemporal_anomaly(
    const SpatioTemporalObservation& subject,
    const std::vector<SpatioTemporalObservation>& neighborhood_observations,
    const std::vector<SpatialNeighbor>& spatial_neighbors,
    const AnomalyPolicy& policy) {

    if (!valid_observation(subject) ||
        neighborhood_observations.empty() ||
        spatial_neighbors.empty()) {
        return std::unexpected(AnalyticsError::empty_input);
    }

    if (!finite_nonnegative(policy.baseline_z_threshold) ||
        policy.baseline_z_threshold <= 0.0 ||
        !finite_nonnegative(policy.recalibration_z_threshold) ||
        policy.recalibration_z_threshold <
            policy.baseline_z_threshold ||
        !finite_nonnegative(
            policy.post_calibration_stabilization_seconds) ||
        !finite_unit_interval(
            policy.distributed_event_neighbor_fraction) ||
        policy.minimum_neighbor_count == 0U ||
        !finite_nonnegative(policy.maximum_threshold_multiplier) ||
        policy.maximum_threshold_multiplier < 1.0) {
        return std::unexpected(AnalyticsError::invalid_numeric_input);
    }

    const double baseline =
        subject.trend_value + subject.seasonal_value;

    const double temporal_residual =
        subject.measured_value - baseline;

    const double expected_standard_deviation =
        std::max(subject.expected_standard_deviation, kEpsilon);

    const double standardized_temporal_score =
        temporal_residual / expected_standard_deviation;

    const bool within_stabilization_window =
        subject.calibration_state ==
            CalibrationState::post_recalibration_stabilization &&
        subject.timestamp_seconds >=
            subject.calibration_completed_at_seconds &&
        subject.timestamp_seconds -
            subject.calibration_completed_at_seconds <=
            policy.post_calibration_stabilization_seconds;

    const bool calibration_related =
        subject.calibration_state ==
            CalibrationState::recalibration_window ||
        within_stabilization_window;

    const double active_threshold =
        calibration_related
            ? policy.recalibration_z_threshold
            : policy.baseline_z_threshold;

    std::unordered_map<std::string, double> neighbor_weights;
    std::unordered_map<std::string, double> expected_gradients;

    for (const auto& neighbor : spatial_neighbors) {
        if (neighbor.source_sensor_id != subject.sensor_id ||
            neighbor.neighbor_sensor_id.empty() ||
            !finite_nonnegative(neighbor.spatial_weight) ||
            neighbor.spatial_weight <= 0.0 ||
            !std::isfinite(neighbor.expected_gradient_adjustment)) {
            return std::unexpected(AnalyticsError::invalid_numeric_input);
        }

        neighbor_weights[neighbor.neighbor_sensor_id] =
            neighbor.spatial_weight;

        expected_gradients[neighbor.neighbor_sensor_id] =
            neighbor.expected_gradient_adjustment;
    }

    double weighted_neighbor_residual_sum = 0.0;
    double neighbor_weight_sum = 0.0;
    std::size_t anomalous_neighbor_count = 0U;
    std::size_t usable_neighbor_count = 0U;

    for (const auto& neighbor_observation : neighborhood_observations) {
        if (!valid_observation(neighbor_observation) ||
            neighbor_observation.sensor_id == subject.sensor_id) {
            return std::unexpected(AnalyticsError::invalid_numeric_input);
        }

        const auto weight_iterator =
            neighbor_weights.find(neighbor_observation.sensor_id);

        if (weight_iterator == neighbor_weights.end()) {
            continue;
        }

        const double neighbor_residual =
            neighbor_observation.measured_value -
            neighbor_observation.trend_value -
            neighbor_observation.seasonal_value;

        const double adjusted_neighbor_residual =
            neighbor_residual -
            expected_gradients[neighbor_observation.sensor_id];

        weighted_neighbor_residual_sum +=
            weight_iterator->second * adjusted_neighbor_residual;

        neighbor_weight_sum += weight_iterator->second;
        ++usable_neighbor_count;

        const double neighbor_standard_deviation =
            std::max(
                neighbor_observation.expected_standard_deviation,
                kEpsilon);

        if (std::abs(neighbor_residual /
                     neighbor_standard_deviation) >=
            active_threshold) {
            ++anomalous_neighbor_count;
        }
    }

    if (usable_neighbor_count < policy.minimum_neighbor_count ||
        neighbor_weight_sum <= kEpsilon) {
        return std::unexpected(
            AnalyticsError::insufficient_baseline_evidence);
    }

    const double weighted_neighbor_residual =
        weighted_neighbor_residual_sum / neighbor_weight_sum;

    const double local_moran_proxy =
        standardized_temporal_score *
        weighted_neighbor_residual /
        expected_standard_deviation;

    const double neighbor_anomaly_fraction =
        static_cast<double>(anomalous_neighbor_count) /
        static_cast<double>(usable_neighbor_count);

    const bool subject_anomalous =
        std::abs(standardized_temporal_score) >= active_threshold;

    const bool distributed_candidate =
        subject_anomalous &&
        neighbor_anomaly_fraction >=
            policy.distributed_event_neighbor_fraction &&
        local_moran_proxy > 0.0;

    const bool local_sensor_candidate =
        subject_anomalous &&
        !distributed_candidate &&
        neighbor_anomaly_fraction <
            policy.distributed_event_neighbor_fraction;

    const AnomalyClassification classification =
        calibration_related
            ? AnomalyClassification::
                recalibration_related_hold_for_review
            : distributed_candidate
                ? AnomalyClassification::
                    distributed_environmental_candidate
                : local_sensor_candidate
                    ? AnomalyClassification::
                        local_sensor_candidate
                    : AnomalyClassification::nominal;

    return AnomalyAssessment{
        .temporal_residual = temporal_residual,
        .standardized_temporal_score =
            standardized_temporal_score,
        .local_moran_proxy = local_moran_proxy,
        .neighbor_anomaly_fraction =
            neighbor_anomaly_fraction,
        .active_threshold = active_threshold,
        .classification = classification,
        .review_required =
            classification != AnomalyClassification::nominal,
        .plain_language_explanation =
            classification ==
                AnomalyClassification::
                    recalibration_related_hold_for_review
                ? "The observation occurs during a recalibration or post-recalibration stabilization interval. The threshold has been widened and the result is held for review rather than being classified as a confirmed environmental or sensor event."
                : classification ==
                    AnomalyClassification::
                        distributed_environmental_candidate
                    ? "The subject sensor and multiple spatially related neighbors show temporally unusual residuals in the same direction after trend, seasonal, and expected-gradient adjustment. The result is a distributed environmental event candidate for review."
                    : classification ==
                        AnomalyClassification::
                            local_sensor_candidate
                        ? "The subject sensor is anomalous while neighboring evidence does not support a distributed event. The result is a local sensor-health or localized-condition candidate for review."
                        : "The observation is within the active temporal and spatial anomaly thresholds."
    };
}

std::expected<ParetoPlanningAssessment, AnalyticsError>
evaluate_pareto_infrastructure_scenarios(
    const std::vector<InfrastructureScenario>& scenarios,
    const EpsilonConstraintPolicy& policy) {

    if (scenarios.empty()) {
        return std::unexpected(AnalyticsError::empty_input);
    }

    if (!finite_unit_interval(policy.maximum_social_inequity) ||
        !finite_nonnegative(policy.maximum_total_cost) ||
        !finite_unit_interval(policy.minimum_accessibility_benefit) ||
        !finite_unit_interval(policy.maximum_harm_risk)) {
        return std::unexpected(AnalyticsError::invalid_numeric_input);
    }

    std::unordered_set<std::string> identifiers;
    std::vector<const InfrastructureScenario*> feasible;

    for (const auto& scenario : scenarios) {
        if (scenario.scenario_id.empty() ||
            !identifiers.insert(scenario.scenario_id).second ||
            !finite_unit_interval(scenario.ecological_benefit) ||
            !finite_unit_interval(scenario.social_inequity) ||
            !finite_nonnegative(scenario.total_cost) ||
            !finite_unit_interval(scenario.accessibility_benefit) ||
            !finite_unit_interval(scenario.harm_risk)) {
            return std::unexpected(AnalyticsError::invalid_numeric_input);
        }

        const bool feasible_under_constraints =
            scenario.social_inequity <=
                policy.maximum_social_inequity &&
            scenario.total_cost <= policy.maximum_total_cost &&
            scenario.accessibility_benefit + kEpsilon >=
                policy.minimum_accessibility_benefit &&
            scenario.harm_risk <= policy.maximum_harm_risk &&
            (!policy.require_non_discrimination_invariant ||
             scenario.satisfies_non_discrimination_invariant) &&
            (!policy.require_essential_access_preservation ||
             scenario.preserves_essential_access);

        if (feasible_under_constraints) {
            feasible.push_back(&scenario);
        }
    }

    if (feasible.empty()) {
        return std::unexpected(
            AnalyticsError::infeasible_tradeoff_constraint);
    }

    std::vector<std::string> feasible_identifiers;
    std::vector<std::string> pareto_identifiers;

    for (const auto* scenario : feasible) {
        feasible_identifiers.push_back(scenario->scenario_id);

        bool dominated_by_another = false;

        for (const auto* comparison : feasible) {
            if (comparison == scenario) {
                continue;
            }

            if (dominates(*comparison, *scenario)) {
                dominated_by_another = true;
                break;
            }
        }

        if (!dominated_by_another) {
            pareto_identifiers.push_back(scenario->scenario_id);
        }
    }

    return ParetoPlanningAssessment{
        .feasible_scenario_ids = std::move(feasible_identifiers),
        .pareto_optimal_scenario_ids = std::move(pareto_identifiers),
        .recommended_review_set_description =
            "Review the non-dominated scenarios with affected communities, ecological reviewers, accessibility reviewers, operators, and public-interest stakeholders. Select a scenario through a documented decision rule rather than silently collapsing distinct priorities into one score.",
        .stakeholder_review_required = true,
        .plain_language_explanation =
            "The evaluation first applies non-negotiable access, non-discrimination, harm, equity, affordability, and accessibility constraints. It then retains every non-dominated scenario so stakeholders can see the genuine ecological, equity, accessibility, cost, and risk tradeoffs."
    };
}

}  // namespace augmented_hub::advanced_analytics
