#include "urban_equity_optimization.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <numeric>
#include <unordered_set>
#include <utility>

namespace augmented_hub::urban_equity {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool unique_identifiers(
    const std::vector<Neighborhood>& neighborhoods,
    const std::vector<HeatIntervention>& interventions) {

    std::unordered_set<std::string> identifiers;

    for (const auto& neighborhood : neighborhoods) {
        if (neighborhood.neighborhood_id.empty() ||
            !identifiers.insert(neighborhood.neighborhood_id).second) {
            return false;
        }
    }

    identifiers.clear();

    for (const auto& intervention : interventions) {
        if (intervention.intervention_id.empty() ||
            !identifiers.insert(intervention.intervention_id).second) {
            return false;
        }
    }

    return true;
}

double mean(const std::vector<double>& values) {
    const double sum =
        std::accumulate(values.begin(), values.end(), 0.0);

    return sum / static_cast<double>(values.size());
}

double population_standard_deviation(
    const std::vector<double>& values,
    double average) {

    double squared_distance_sum = 0.0;

    for (const double value : values) {
        const double distance = value - average;
        squared_distance_sum += distance * distance;
    }

    return std::sqrt(
        squared_distance_sum / static_cast<double>(values.size()));
}

double gini_coefficient(std::vector<double> values) {
    std::sort(values.begin(), values.end());

    const double total =
        std::accumulate(values.begin(), values.end(), 0.0);

    if (total <= kEpsilon) {
        return 0.0;
    }

    double weighted_sum = 0.0;

    for (std::size_t index = 0; index < values.size(); ++index) {
        weighted_sum +=
            static_cast<double>(index + 1U) * values[index];
    }

    const double count = static_cast<double>(values.size());

    return std::clamp(
        (2.0 * weighted_sum) / (count * total) -
        (count + 1.0) / count,
        0.0,
        1.0);
}

bool satisfies_equity(
    const std::vector<Neighborhood>& neighborhoods,
    const std::vector<double>& reductions,
    bool require_priority_equity) {

    for (std::size_t index = 0; index < neighborhoods.size(); ++index) {
        const auto& neighborhood = neighborhoods[index];

        if (require_priority_equity &&
            neighborhood.equity_priority &&
            reductions[index] + kEpsilon <
                neighborhood.minimum_temperature_reduction_celsius) {
            return false;
        }
    }

    return true;
}

double weighted_temperature_reduction(
    const std::vector<Neighborhood>& neighborhoods,
    const std::vector<double>& reductions) {

    double result = 0.0;

    for (std::size_t index = 0; index < neighborhoods.size(); ++index) {
        result += neighborhoods[index].vulnerability_weight *
            reductions[index];
    }

    return result;
}

double eco_benefit(const HeatIntervention& intervention) {
    return intervention.evapotranspiration_cooling_kwh +
        intervention.reflected_heat_reduction_kwh -
        intervention.absorbed_heat_kwh;
}

}  // namespace

std::expected<HeatPlanResult, PlanningError> optimize_heat_recovery_plan(
    const std::vector<Neighborhood>& neighborhoods,
    const std::vector<HeatIntervention>& interventions,
    const HeatPlanPolicy& policy) {

    if (neighborhoods.empty() || interventions.empty()) {
        return std::unexpected(PlanningError::empty_input);
    }

    if (!finite_nonnegative(policy.total_budget) ||
        !finite_nonnegative(policy.minimum_eco_benefit) ||
        !unique_identifiers(neighborhoods, interventions)) {
        return std::unexpected(PlanningError::invalid_numeric_input);
    }

    for (const auto& neighborhood : neighborhoods) {
        if (!finite_nonnegative(neighborhood.baseline_temperature_celsius) ||
            !finite_nonnegative(neighborhood.vulnerability_weight) ||
            !finite_nonnegative(
                neighborhood.minimum_temperature_reduction_celsius)) {
            return std::unexpected(PlanningError::invalid_numeric_input);
        }
    }

    for (const auto& intervention : interventions) {
        if (!finite_nonnegative(intervention.cost) ||
            !finite_nonnegative(intervention.evapotranspiration_cooling_kwh) ||
            !finite_nonnegative(intervention.reflected_heat_reduction_kwh) ||
            !finite_nonnegative(intervention.absorbed_heat_kwh) ||
            intervention.temperature_reduction_by_neighborhood_celsius.size() !=
                neighborhoods.size()) {
            return std::unexpected(PlanningError::invalid_numeric_input);
        }

        for (const double reduction :
             intervention.temperature_reduction_by_neighborhood_celsius) {
            if (!finite_nonnegative(reduction)) {
                return std::unexpected(PlanningError::invalid_numeric_input);
            }
        }
    }

    if (interventions.size() >=
        static_cast<std::size_t>(
            std::numeric_limits<unsigned long long>::digits)) {
        return std::unexpected(PlanningError::no_feasible_plan);
    }

    HeatPlanResult best_result{};
    bool found_feasible_plan = false;

    const unsigned long long combination_count =
        1ULL << interventions.size();

    for (unsigned long long selection_mask = 1ULL;
         selection_mask < combination_count;
         ++selection_mask) {

        std::vector<double> reductions(neighborhoods.size(), 0.0);
        std::vector<std::string> selected_ids;
        double cost = 0.0;
        double benefit = 0.0;

        for (std::size_t intervention_index = 0;
             intervention_index < interventions.size();
             ++intervention_index) {

            if ((selection_mask & (1ULL << intervention_index)) == 0ULL) {
                continue;
            }

            const auto& intervention = interventions[intervention_index];

            cost += intervention.cost;
            benefit += eco_benefit(intervention);
            selected_ids.push_back(intervention.intervention_id);

            for (std::size_t neighborhood_index = 0;
                 neighborhood_index < neighborhoods.size();
                 ++neighborhood_index) {
                reductions[neighborhood_index] +=
                    intervention.temperature_reduction_by_neighborhood_celsius[
                        neighborhood_index];
            }
        }

        if (cost > policy.total_budget + kEpsilon ||
            benefit + kEpsilon < policy.minimum_eco_benefit ||
            !satisfies_equity(
                neighborhoods,
                reductions,
                policy.require_priority_neighborhood_equity)) {
            continue;
        }

        const double objective =
            weighted_temperature_reduction(neighborhoods, reductions);

        if (!found_feasible_plan ||
            objective > best_result.weighted_temperature_reduction) {
            found_feasible_plan = true;
            best_result = HeatPlanResult{
                .selected_intervention_ids = std::move(selected_ids),
                .temperature_reduction_by_neighborhood_celsius =
                    std::move(reductions),
                .total_cost = cost,
                .weighted_temperature_reduction = objective,
                .eco_benefit_kwh = benefit,
                .equity_constraints_satisfied = true,
                .plain_language_explanation =
                    "The selected heat-relief interventions maximize the stated vulnerability-weighted cooling objective within the budget while satisfying the configured neighborhood equity floor. The result is planning evidence and requires applicable ecological, accessibility, and community review before deployment."
            };
        }
    }

    if (!found_feasible_plan) {
        return std::unexpected(PlanningError::no_feasible_plan);
    }

    return best_result;
}

std::expected<TransitFairnessResult, PlanningError> calculate_transit_fairness(
    const std::vector<TransitNeighborhoodMetrics>& metrics) {

    if (metrics.size() < 2U) {
        return std::unexpected(PlanningError::empty_input);
    }

    std::unordered_set<std::string> identifiers;
    std::vector<double> waits;
    std::vector<double> accessibility_rates;
    std::vector<double> fare_to_income_ratios;
    std::vector<double> on_time_rates;

    waits.reserve(metrics.size());
    accessibility_rates.reserve(metrics.size());
    fare_to_income_ratios.reserve(metrics.size());
    on_time_rates.reserve(metrics.size());

    for (const auto& metric : metrics) {
        if (metric.neighborhood_id.empty() ||
            !identifiers.insert(metric.neighborhood_id).second ||
            !finite_nonnegative(metric.mean_wait_minutes) ||
            !finite_nonnegative(metric.accessible_stops) ||
            !finite_nonnegative(metric.population) ||
            metric.population <= 0.0 ||
            !finite_nonnegative(metric.fare_to_income_ratio) ||
            !std::isfinite(metric.on_time_performance) ||
            metric.on_time_performance < 0.0 ||
            metric.on_time_performance > 1.0) {
            return std::unexpected(PlanningError::invalid_fairness_input);
        }

        waits.push_back(metric.mean_wait_minutes);
        accessibility_rates.push_back(
            metric.accessible_stops / metric.population);
        fare_to_income_ratios.push_back(metric.fare_to_income_ratio);
        on_time_rates.push_back(metric.on_time_performance);
    }

    const double mean_wait = mean(waits);
    const double wait_coefficient_of_variation =
        mean_wait > kEpsilon
            ? population_standard_deviation(waits, mean_wait) / mean_wait
            : 0.0;

    const double wait_equality =
        std::clamp(1.0 - wait_coefficient_of_variation, 0.0, 1.0);

    const auto [minimum_accessibility, maximum_accessibility] =
        std::minmax_element(
            accessibility_rates.begin(),
            accessibility_rates.end());

    const double accessibility_equality =
        *maximum_accessibility > kEpsilon
            ? std::clamp(
                *minimum_accessibility / *maximum_accessibility,
                0.0,
                1.0)
            : 1.0;

    const double affordability_equality =
        std::clamp(
            1.0 - gini_coefficient(fare_to_income_ratios),
            0.0,
            1.0);

    const double mean_on_time = mean(on_time_rates);
    const double on_time_coefficient_of_variation =
        mean_on_time > kEpsilon
            ? population_standard_deviation(on_time_rates, mean_on_time) /
                mean_on_time
            : 0.0;

    const double on_time_equality =
        std::clamp(1.0 - on_time_coefficient_of_variation, 0.0, 1.0);

    const double product =
        wait_equality *
        accessibility_equality *
        affordability_equality *
        on_time_equality;

    const double composite_fairness =
        std::pow(product, 0.25);

    return TransitFairnessResult{
        .wait_time_equality = wait_equality,
        .accessibility_coverage_equality = accessibility_equality,
        .affordability_equality = affordability_equality,
        .on_time_equality = on_time_equality,
        .composite_fairness = composite_fairness,
        .plain_language_explanation =
            "This score compares neighborhood-level transit service outcomes: wait time, accessible-stop coverage, affordability, and on-time performance. It does not use identity, augmentation status, assistive-technology data, or private individual records."
    };
}

}  // namespace augmented_hub::urban_equity
