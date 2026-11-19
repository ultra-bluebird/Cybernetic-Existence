#ifndef AUGMENTED_HUB_URBAN_EQUITY_OPTIMIZATION_HPP
#define AUGMENTED_HUB_URBAN_EQUITY_OPTIMIZATION_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::urban_equity {

enum class PlanningError {
    empty_input,
    invalid_numeric_input,
    duplicate_identifier,
    infeasible_equity_constraint,
    no_feasible_plan,
    invalid_fairness_input
};

enum class InterventionType {
    shade_canopy,
    green_roof,
    reflective_surface
};

struct Neighborhood {
    std::string neighborhood_id;
    double baseline_temperature_celsius{};
    double vulnerability_weight{};
    bool equity_priority{};
    double minimum_temperature_reduction_celsius{};
};

struct HeatIntervention {
    std::string intervention_id;
    InterventionType type{};
    double cost{};
    std::vector<double> temperature_reduction_by_neighborhood_celsius;
    double evapotranspiration_cooling_kwh{};
    double reflected_heat_reduction_kwh{};
    double absorbed_heat_kwh{};
};

struct HeatPlanPolicy {
    double total_budget{};
    double minimum_eco_benefit{};
    bool require_priority_neighborhood_equity{true};
};

struct HeatPlanResult {
    std::vector<std::string> selected_intervention_ids;
    std::vector<double> temperature_reduction_by_neighborhood_celsius;
    double total_cost{};
    double weighted_temperature_reduction{};
    double eco_benefit_kwh{};
    bool equity_constraints_satisfied{};
    std::string plain_language_explanation;
};

struct TransitNeighborhoodMetrics {
    std::string neighborhood_id;
    double mean_wait_minutes{};
    double accessible_stops{};
    double population{};
    double fare_to_income_ratio{};
    double on_time_performance{};
};

struct TransitFairnessResult {
    double wait_time_equality{};
    double accessibility_coverage_equality{};
    double affordability_equality{};
    double on_time_equality{};
    double composite_fairness{};
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<HeatPlanResult, PlanningError>
optimize_heat_recovery_plan(
    const std::vector<Neighborhood>& neighborhoods,
    const std::vector<HeatIntervention>& interventions,
    const HeatPlanPolicy& policy);

[[nodiscard]] std::expected<TransitFairnessResult, PlanningError>
calculate_transit_fairness(
    const std::vector<TransitNeighborhoodMetrics>& metrics);

}  // namespace augmented_hub::urban_equity

#endif
