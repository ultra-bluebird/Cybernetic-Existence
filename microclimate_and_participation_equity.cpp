#include "microclimate_and_participation_equity.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <numeric>
#include <unordered_map>
#include <unordered_set>
#include <utility>

namespace augmented_hub::community_equity {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

double distance_meters(
    double first_x,
    double first_y,
    double second_x,
    double second_y) noexcept {

    const double delta_x = first_x - second_x;
    const double delta_y = first_y - second_y;

    return std::sqrt(delta_x * delta_x + delta_y * delta_y);
}

double variance_reduction_factor(
    double distance_m,
    double decay_distance_m) noexcept {

    if (decay_distance_m <= kEpsilon) {
        return 0.0;
    }

    return std::exp(-distance_m / decay_distance_m);
}

bool is_complete_microclimate_site(
    const SensorCandidateSite& site) noexcept {

    return site.temperature_supported &&
        site.humidity_supported &&
        site.solar_radiation_supported &&
        site.wind_supported;
}

struct SiteBenefit {
    std::size_t site_index{};
    double weighted_variance_reduction{};
    double cost{};
};

double estimate_cell_variance(
    const NeighborhoodMicroclimateCell& cell,
    const std::vector<SensorCandidateSite>& selected_sites,
    double maximum_coverage_distance_m,
    double variance_decay_distance_m) {

    if (selected_sites.empty()) {
        return cell.baseline_prediction_variance;
    }

    double combined_precision = 0.0;
    bool within_coverage_distance = false;

    for (const auto& site : selected_sites) {
        const double distance = distance_meters(
            cell.centroid_x_m,
            cell.centroid_y_m,
            site.x_m,
            site.y_m);

        if (distance <= maximum_coverage_distance_m) {
            within_coverage_distance = true;
        }

        const double weight =
            variance_reduction_factor(distance, variance_decay_distance_m);

        const double measurement_variance =
            std::max(site.expected_measurement_variance, kEpsilon);

        combined_precision += weight / measurement_variance;
    }

    if (!within_coverage_distance || combined_precision <= kEpsilon) {
        return cell.baseline_prediction_variance;
    }

    const double prior_precision =
        1.0 / std::max(cell.baseline_prediction_variance, kEpsilon);

    return 1.0 / (prior_precision + combined_precision);
}

}  // namespace

std::expected<MicroclimatePlacementAssessment, EquityPlanningError>
select_microclimate_sensor_sites(
    const std::vector<NeighborhoodMicroclimateCell>& cells,
    const std::vector<SensorCandidateSite>& candidate_sites,
    const MicroclimatePlacementPolicy& policy) {

    if (cells.empty() || candidate_sites.empty()) {
        return std::unexpected(EquityPlanningError::empty_input);
    }

    if (!finite_nonnegative(policy.total_budget) ||
        !finite_nonnegative(policy.maximum_prediction_variance) ||
        !finite_unit_interval(policy.minimum_priority_coverage_fraction) ||
        !finite_nonnegative(policy.maximum_coverage_distance_m) ||
        policy.maximum_coverage_distance_m <= 0.0 ||
        !finite_nonnegative(policy.variance_decay_distance_m) ||
        policy.variance_decay_distance_m <= 0.0 ||
        policy.minimum_sites_per_priority_neighborhood == 0U) {
        return std::unexpected(EquityPlanningError::invalid_numeric_input);
    }

    std::unordered_set<std::string> cell_identifiers;
    std::unordered_set<std::string> priority_neighborhoods;

    for (const auto& cell : cells) {
        if (cell.cell_id.empty() ||
            cell.neighborhood_id.empty() ||
            !cell_identifiers.insert(cell.cell_id).second ||
            !std::isfinite(cell.centroid_x_m) ||
            !std::isfinite(cell.centroid_y_m) ||
            !finite_nonnegative(cell.baseline_prediction_variance) ||
            !finite_nonnegative(cell.heat_exposure_weight)) {
            return std::unexpected(EquityPlanningError::invalid_numeric_input);
        }

        if (cell.monitoring_priority) {
            priority_neighborhoods.insert(cell.neighborhood_id);
        }
    }

    std::unordered_set<std::string> site_identifiers;
    std::vector<SensorCandidateSite> usable_sites;

    for (const auto& site : candidate_sites) {
        if (site.site_id.empty() ||
            !site_identifiers.insert(site.site_id).second ||
            !std::isfinite(site.x_m) ||
            !std::isfinite(site.y_m) ||
            !finite_nonnegative(site.installation_cost) ||
            !finite_nonnegative(site.annual_maintenance_cost) ||
            !finite_nonnegative(site.expected_measurement_variance)) {
            return std::unexpected(EquityPlanningError::invalid_numeric_input);
        }

        if (is_complete_microclimate_site(site)) {
            usable_sites.push_back(site);
        }
    }

    if (usable_sites.empty()) {
        return std::unexpected(
            EquityPlanningError::infeasible_coverage_constraint);
    }

    std::vector<SensorCandidateSite> selected_sites;
    std::vector<std::string> selected_site_ids;
    double total_cost = 0.0;

    while (true) {
        std::unordered_map<std::string, std::size_t>
            priority_neighborhood_site_counts;

        for (const auto& site : selected_sites) {
            for (const auto& cell : cells) {
                if (!cell.monitoring_priority) {
                    continue;
                }

                const double distance = distance_meters(
                    cell.centroid_x_m,
                    cell.centroid_y_m,
                    site.x_m,
                    site.y_m);

                if (distance <= policy.maximum_coverage_distance_m) {
                    ++priority_neighborhood_site_counts[
                        cell.neighborhood_id];
                }
            }
        }

        bool priority_coverage_complete = true;

        for (const auto& neighborhood : priority_neighborhoods) {
            if (priority_neighborhood_site_counts[neighborhood] <
                policy.minimum_sites_per_priority_neighborhood) {
                priority_coverage_complete = false;
                break;
            }
        }

        double maximum_variance = 0.0;

        for (const auto& cell : cells) {
            maximum_variance = std::max(
                maximum_variance,
                estimate_cell_variance(
                    cell,
                    selected_sites,
                    policy.maximum_coverage_distance_m,
                    policy.variance_decay_distance_m));
        }

        if (priority_coverage_complete &&
            maximum_variance <= policy.maximum_prediction_variance) {
            break;
        }

        std::optional<SiteBenefit> best_site;

        for (std::size_t site_index = 0;
             site_index < usable_sites.size();
             ++site_index) {

            const auto& candidate = usable_sites[site_index];

            if (std::find(
                    selected_site_ids.begin(),
                    selected_site_ids.end(),
                    candidate.site_id) != selected_site_ids.end()) {
                continue;
            }

            const double candidate_cost =
                candidate.installation_cost +
                candidate.annual_maintenance_cost;

            if (total_cost + candidate_cost >
                policy.total_budget + kEpsilon) {
                continue;
            }

            double weighted_reduction = 0.0;

            for (const auto& cell : cells) {
                const double before = estimate_cell_variance(
                    cell,
                    selected_sites,
                    policy.maximum_coverage_distance_m,
                    policy.variance_decay_distance_m);

                std::vector<SensorCandidateSite> provisional =
                    selected_sites;

                provisional.push_back(candidate);

                const double after = estimate_cell_variance(
                    cell,
                    provisional,
                    policy.maximum_coverage_distance_m,
                    policy.variance_decay_distance_m);

                weighted_reduction +=
                    cell.heat_exposure_weight *
                    std::max(before - after, 0.0);

                if (cell.monitoring_priority &&
                    priority_neighborhood_site_counts[
                        cell.neighborhood_id] <
                        policy.minimum_sites_per_priority_neighborhood &&
                    distance_meters(
                        cell.centroid_x_m,
                        cell.centroid_y_m,
                        candidate.x_m,
                        candidate.y_m) <=
                        policy.maximum_coverage_distance_m) {
                    weighted_reduction += cell.heat_exposure_weight;
                }
            }

            if (!best_site.has_value() ||
                weighted_reduction / std::max(candidate_cost, 1.0) >
                    best_site->weighted_variance_reduction /
                    std::max(best_site->cost, 1.0)) {
                best_site = SiteBenefit{
                    .site_index = site_index,
                    .weighted_variance_reduction = weighted_reduction,
                    .cost = candidate_cost
                };
            }
        }

        if (!best_site.has_value()) {
            return std::unexpected(
                EquityPlanningError::infeasible_coverage_constraint);
        }

        const auto& selected = usable_sites[best_site->site_index];

        total_cost += best_site->cost;
        selected_site_ids.push_back(selected.site_id);
        selected_sites.push_back(selected);
    }

    double maximum_residual_variance = 0.0;
    double weighted_residual_variance = 0.0;
    std::unordered_set<std::string> covered_priority_neighborhoods;

    for (const auto& cell : cells) {
        const double residual_variance = estimate_cell_variance(
            cell,
            selected_sites,
            policy.maximum_coverage_distance_m,
            policy.variance_decay_distance_m);

        maximum_residual_variance = std::max(
            maximum_residual_variance,
            residual_variance);

        weighted_residual_variance +=
            cell.heat_exposure_weight * residual_variance;

        if (cell.monitoring_priority) {
            for (const auto& site : selected_sites) {
                if (distance_meters(
                        cell.centroid_x_m,
                        cell.centroid_y_m,
                        site.x_m,
                        site.y_m) <=
                    policy.maximum_coverage_distance_m) {
                    covered_priority_neighborhoods.insert(
                        cell.neighborhood_id);
                    break;
                }
            }
        }
    }

    const double priority_coverage_fraction =
        priority_neighborhoods.empty()
            ? 1.0
            : static_cast<double>(
                covered_priority_neighborhoods.size()) /
                static_cast<double>(priority_neighborhoods.size());

    return MicroclimatePlacementAssessment{
        .selected_site_ids = std::move(selected_site_ids),
        .total_cost = total_cost,
        .maximum_residual_prediction_variance =
            maximum_residual_variance,
        .weighted_residual_prediction_variance =
            weighted_residual_variance,
        .priority_neighborhoods_covered =
            covered_priority_neighborhoods.size(),
        .priority_neighborhood_count =
            priority_neighborhoods.size(),
        .equity_variance_constraint_satisfied =
            maximum_residual_variance <=
            policy.maximum_prediction_variance,
        .coverage_constraint_satisfied =
            priority_coverage_fraction + kEpsilon >=
            policy.minimum_priority_coverage_fraction,
        .plain_language_explanation =
            "The selected sensor sites reduce modeled neighborhood-scale temperature prediction uncertainty while enforcing the stated priority-neighborhood coverage and maximum-variance constraints. The result is a planning scenario; final siting requires local representativeness, mounting, shielding, calibration, power, communications, maintenance, land-access, and community review."
    };
}

std::expected<ParticipationEquityAssessment, EquityPlanningError>
evaluate_geographic_participation_equity(
    const std::vector<GeographicParticipationAggregate>& aggregates,
    const ParticipationEquityPolicy& policy) {

    if (aggregates.size() < 2U) {
        return std::unexpected(EquityPlanningError::empty_input);
    }

    if (policy.minimum_aggregation_count == 0U ||
        !finite_nonnegative(policy.minimum_population_estimate) ||
        policy.minimum_population_estimate <= 0.0 ||
        !finite_unit_interval(
            policy.minimum_accessible_event_availability) ||
        !finite_unit_interval(
            policy.minimum_offline_participation_availability) ||
        !finite_unit_interval(
            policy.minimum_language_access_availability)) {
        return std::unexpected(EquityPlanningError::invalid_numeric_input);
    }

    std::unordered_set<std::string> neighborhood_identifiers;
    double minimum_participation_rate =
        std::numeric_limits<double>::infinity();
    double maximum_participation_rate = 0.0;
    double total_barrier_report_rate = 0.0;
    std::vector<std::string> barrier_review_neighborhoods;

    for (const auto& aggregate : aggregates) {
        if (aggregate.neighborhood_id.empty() ||
            !neighborhood_identifiers.insert(
                aggregate.neighborhood_id).second ||
            aggregate.population_estimate <
                policy.minimum_population_estimate ||
            !finite_unit_interval(
                aggregate.participation_barrier_report_rate) ||
            !finite_unit_interval(
                aggregate.accessible_event_availability) ||
            !finite_unit_interval(
                aggregate.offline_participation_availability) ||
            !finite_unit_interval(
                aggregate.language_access_availability) ||
            !aggregate.data_is_non_identifying ||
            !aggregate.feedback_is_voluntary) {
            return std::unexpected(EquityPlanningError::invalid_numeric_input);
        }

        if (aggregate.aggregate_participant_count <
            policy.minimum_aggregation_count) {
            return std::unexpected(
                EquityPlanningError::insufficient_aggregation);
        }

        const double participation_rate =
            static_cast<double>(aggregate.aggregate_participant_count) /
            static_cast<double>(aggregate.population_estimate);

        minimum_participation_rate = std::min(
            minimum_participation_rate,
            participation_rate);

        maximum_participation_rate = std::max(
            maximum_participation_rate,
            participation_rate);

        total_barrier_report_rate +=
            aggregate.participation_barrier_report_rate;

        if (aggregate.participation_barrier_report_rate > 0.0 ||
            aggregate.accessible_event_availability + kEpsilon <
                policy.minimum_accessible_event_availability ||
            aggregate.offline_participation_availability + kEpsilon <
                policy.minimum_offline_participation_availability ||
            aggregate.language_access_availability + kEpsilon <
                policy.minimum_language_access_availability) {
            barrier_review_neighborhoods.push_back(
                aggregate.neighborhood_id);
        }
    }

    const double participation_equity_index =
        maximum_participation_rate > kEpsilon
            ? std::clamp(
                minimum_participation_rate /
                maximum_participation_rate,
                0.0,
                1.0)
            : 1.0;

    const double average_barrier_report_rate =
        total_barrier_report_rate /
        static_cast<double>(aggregates.size());

    return ParticipationEquityAssessment{
        .participation_equity_index = participation_equity_index,
        .minimum_participation_rate = minimum_participation_rate,
        .maximum_participation_rate = maximum_participation_rate,
        .average_barrier_report_rate = average_barrier_report_rate,
        .neighborhoods_requiring_barrier_review =
            std::move(barrier_review_neighborhoods),
        .aggregate_evidence_eligible = true,
        .plain_language_explanation =
            "This assessment compares aggregate neighborhood participation rates and identifies program-design barriers such as limited accessible events, offline participation, language access, or voluntary aggregate barrier reports. It does not infer demographic identity, augmentation status, disability, personal beliefs, or personal participation history."
    };
}

}  // namespace augmented_hub::community_equity
