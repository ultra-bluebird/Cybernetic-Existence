#include "heat_island_and_riparian_planning.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <unordered_set>
#include <utility>

namespace augmented_hub::eco_restoration {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

double candidate_reflected_heat_reduction(
    const HeatMitigationCandidate& candidate,
    const UrbanSurfaceProfile& surface) noexcept {

    return std::max(
        candidate.improved_albedo - candidate.baseline_albedo,
        0.0) *
        surface.incoming_radiation_w_per_m2 *
        candidate.area_m2;
}

double candidate_evapotranspiration_cooling(
    const HeatMitigationCandidate& candidate) noexcept {

    return candidate.latent_heat_j_per_kg *
        candidate.evapotranspiration_rate_kg_per_m2_s *
        candidate.area_m2;
}

double candidate_shade_cooling(
    const HeatMitigationCandidate& candidate,
    const UrbanSurfaceProfile& surface) noexcept {

    return candidate.shade_effectiveness *
        surface.incoming_radiation_w_per_m2 *
        candidate.area_m2;
}

double candidate_total_cooling(
    const HeatMitigationCandidate& candidate,
    const UrbanSurfaceProfile& surface) noexcept {

    return
        candidate_reflected_heat_reduction(candidate, surface) +
        candidate_evapotranspiration_cooling(candidate) +
        candidate_shade_cooling(candidate, surface);
}

bool valid_surface(const UrbanSurfaceProfile& surface) noexcept {
    return finite_nonnegative(surface.total_area_m2) &&
        surface.total_area_m2 > 0.0 &&
        finite_unit_interval(surface.asphalt_fraction) &&
        finite_unit_interval(surface.rooftop_fraction) &&
        finite_unit_interval(surface.mixed_land_use_fraction) &&
        finite_nonnegative(surface.incoming_radiation_w_per_m2) &&
        finite_nonnegative(surface.air_mass_kg) &&
        surface.air_mass_kg > 0.0 &&
        finite_nonnegative(surface.air_specific_heat_j_per_kg_k) &&
        surface.air_specific_heat_j_per_kg_k > 0.0 &&
        finite_nonnegative(surface.anthropogenic_heat_flux_w_per_m2);
}

bool valid_zone(const RiparianZoneProfile& zone) noexcept {
    return !zone.zone_id.empty() &&
        finite_nonnegative(zone.available_buffer_width_m) &&
        finite_nonnegative(zone.corridor_length_m) &&
        finite_nonnegative(
            zone.photosynthetically_active_radiation_w_per_m2) &&
        finite_nonnegative(zone.air_density_kg_per_m3) &&
        zone.air_density_kg_per_m3 > 0.0 &&
        finite_nonnegative(zone.air_specific_heat_j_per_kg_k) &&
        zone.air_specific_heat_j_per_kg_k > 0.0 &&
        finite_nonnegative(zone.mixing_height_m) &&
        zone.mixing_height_m > 0.0 &&
        finite_nonnegative(zone.inflow_concentration_kg_per_m3) &&
        finite_nonnegative(zone.outflow_concentration_kg_per_m3) &&
        finite_nonnegative(zone.water_flow_m3_per_s) &&
        finite_nonnegative(zone.evaluation_duration_s);
}

}  // namespace

std::expected<HeatMitigationAssessment, EcoPlanningError>
evaluate_heat_mitigation_portfolio(
    const UrbanSurfaceProfile& surface,
    const std::vector<HeatMitigationCandidate>& candidates,
    const HeatMitigationPolicy& policy) {

    if (!valid_surface(surface) || candidates.empty()) {
        return std::unexpected(EcoPlanningError::empty_input);
    }

    if (!finite_nonnegative(policy.total_budget) ||
        !finite_nonnegative(policy.maximum_annual_water_use_m3) ||
        !finite_nonnegative(policy.minimum_ecological_benefit) ||
        !finite_nonnegative(policy.minimum_accessibility_benefit) ||
        !finite_nonnegative(policy.minimum_temperature_reduction_k)) {
        return std::unexpected(EcoPlanningError::invalid_numeric_input);
    }

    std::unordered_set<std::string> identifiers;

    for (const auto& candidate : candidates) {
        if (candidate.candidate_id.empty() ||
            !identifiers.insert(candidate.candidate_id).second ||
            !finite_nonnegative(candidate.area_m2) ||
            !finite_nonnegative(candidate.capital_cost) ||
            !finite_nonnegative(candidate.annual_maintenance_cost) ||
            !finite_unit_interval(candidate.baseline_albedo) ||
            !finite_unit_interval(candidate.improved_albedo) ||
            !finite_nonnegative(
                candidate.evapotranspiration_rate_kg_per_m2_s) ||
            !finite_nonnegative(candidate.latent_heat_j_per_kg) ||
            !finite_unit_interval(candidate.shade_effectiveness) ||
            !finite_nonnegative(candidate.ecological_benefit) ||
            !finite_nonnegative(candidate.water_use_m3_per_year) ||
            !finite_nonnegative(candidate.accessibility_benefit)) {
            return std::unexpected(EcoPlanningError::invalid_numeric_input);
        }
    }

    if (candidates.size() >=
        static_cast<std::size_t>(
            std::numeric_limits<unsigned long long>::digits)) {
        return std::unexpected(EcoPlanningError::infeasible_plan);
    }

    HeatMitigationAssessment best{};
    bool found_feasible_plan = false;

    const unsigned long long combinations =
        1ULL << candidates.size();

    for (unsigned long long mask = 1ULL; mask < combinations; ++mask) {
        double total_cost = 0.0;
        double annual_water_use = 0.0;
        double reflected_heat_reduction = 0.0;
        double evapotranspiration_cooling = 0.0;
        double shade_cooling = 0.0;
        double ecological_benefit = 0.0;
        double accessibility_benefit = 0.0;
        std::vector<std::string> selected_ids;

        for (std::size_t index = 0; index < candidates.size(); ++index) {
            if ((mask & (1ULL << index)) == 0ULL) {
                continue;
            }

            const auto& candidate = candidates[index];

            total_cost +=
                candidate.capital_cost +
                candidate.annual_maintenance_cost;

            annual_water_use += candidate.water_use_m3_per_year;

            reflected_heat_reduction +=
                candidate_reflected_heat_reduction(candidate, surface);

            evapotranspiration_cooling +=
                candidate_evapotranspiration_cooling(candidate);

            shade_cooling +=
                candidate_shade_cooling(candidate, surface);

            ecological_benefit += candidate.ecological_benefit;
            accessibility_benefit += candidate.accessibility_benefit;
            selected_ids.push_back(candidate.candidate_id);
        }

        const double total_cooling =
            reflected_heat_reduction +
            evapotranspiration_cooling +
            shade_cooling;

        const double temperature_reduction =
            total_cooling /
            (surface.air_mass_kg *
             surface.air_specific_heat_j_per_kg_k);

        const bool feasible =
            total_cost <= policy.total_budget + kEpsilon &&
            annual_water_use <=
                policy.maximum_annual_water_use_m3 + kEpsilon &&
            ecological_benefit + kEpsilon >=
                policy.minimum_ecological_benefit &&
            accessibility_benefit + kEpsilon >=
                policy.minimum_accessibility_benefit &&
            temperature_reduction + kEpsilon >=
                policy.minimum_temperature_reduction_k;

        if (!feasible) {
            continue;
        }

        if (!found_feasible_plan ||
            temperature_reduction > best.estimated_temperature_reduction_k) {
            found_feasible_plan = true;

            best = HeatMitigationAssessment{
                .selected_candidate_ids = std::move(selected_ids),
                .total_cost = total_cost,
                .annual_water_use_m3 = annual_water_use,
                .reflected_heat_reduction_w =
                    reflected_heat_reduction,
                .evapotranspiration_cooling_w =
                    evapotranspiration_cooling,
                .shade_cooling_w = shade_cooling,
                .estimated_temperature_reduction_k =
                    temperature_reduction,
                .ecological_benefit = ecological_benefit,
                .accessibility_benefit = accessibility_benefit,
                .constraints_satisfied = true,
                .plain_language_explanation =
                    "The selected portfolio satisfies the stated budget, water-use, ecological-benefit, accessibility-benefit, and cooling thresholds. The temperature result is a scenario-level energy-balance estimate and should be combined with site microclimate, maintenance, water, habitat, and community review before deployment."
            };
        }
    }

    if (!found_feasible_plan) {
        return std::unexpected(EcoPlanningError::infeasible_plan);
    }

    return best;
}

std::expected<RiparianPlanAssessment, EcoPlanningError>
evaluate_riparian_restoration_plan(
    const RiparianZoneProfile& zone,
    const std::vector<RiparianPlantOption>& plants,
    const RiparianPolicy& policy) {

    if (!valid_zone(zone) || plants.empty()) {
        return std::unexpected(EcoPlanningError::empty_input);
    }

    if (!finite_nonnegative(policy.total_budget) ||
        !finite_nonnegative(policy.maximum_water_use_m3_per_year) ||
        !finite_nonnegative(policy.minimum_buffer_width_m) ||
        !finite_unit_interval(policy.minimum_native_fraction) ||
        !finite_nonnegative(policy.minimum_accessibility_clear_width_m) ||
        !finite_unit_interval(policy.maximum_maintenance_score)) {
        return std::unexpected(EcoPlanningError::invalid_numeric_input);
    }

    if (zone.available_buffer_width_m + kEpsilon <
        policy.minimum_buffer_width_m +
        policy.minimum_accessibility_clear_width_m) {
        return std::unexpected(EcoPlanningError::infeasible_plan);
    }

    std::unordered_set<std::string> identifiers;
    std::vector<const RiparianPlantOption*> eligible_plants;

    for (const auto& plant : plants) {
        if (plant.plant_id.empty() ||
            !identifiers.insert(plant.plant_id).second ||
            plant.common_name.empty() ||
            !finite_nonnegative(plant.mature_leaf_area_index) ||
            !finite_nonnegative(
                plant.evapotranspiration_rate_kg_per_m2_s) ||
            !finite_unit_interval(plant.nutrient_uptake_score) ||
            !finite_unit_interval(plant.sediment_stabilization_score) ||
            !finite_unit_interval(plant.habitat_value_score) ||
            !finite_unit_interval(plant.annual_maintenance_score) ||
            !finite_nonnegative(plant.annual_water_use_m3_per_m2)) {
            return std::unexpected(EcoPlanningError::invalid_numeric_input);
        }

        if (plant.suitable_zone == zone.zone_type &&
            plant.native_to_project_region &&
            plant.annual_maintenance_score <=
                policy.maximum_maintenance_score) {
            eligible_plants.push_back(&plant);
        }
    }

    if (eligible_plants.empty()) {
        return std::unexpected(EcoPlanningError::insufficient_evidence);
    }

    const double selected_buffer_width =
        std::max(
            policy.minimum_buffer_width_m,
            zone.available_buffer_width_m -
                policy.minimum_accessibility_clear_width_m);

    const double vegetation_area =
        selected_buffer_width * zone.corridor_length_m;

    double total_leaf_area_index = 0.0;
    double total_evapotranspiration_rate = 0.0;
    double nutrient_uptake_score = 0.0;
    double sediment_stabilization_score = 0.0;
    double habitat_value_score = 0.0;
    double annual_water_use_m3 = 0.0;
    std::vector<std::string> selected_plant_ids;

    for (const auto* plant : eligible_plants) {
        total_leaf_area_index += plant->mature_leaf_area_index;
        total_evapotranspiration_rate +=
            plant->evapotranspiration_rate_kg_per_m2_s;
        nutrient_uptake_score += plant->nutrient_uptake_score;
        sediment_stabilization_score +=
            plant->sediment_stabilization_score;
        habitat_value_score += plant->habitat_value_score;
        annual_water_use_m3 +=
            plant->annual_water_use_m3_per_m2 * vegetation_area;
        selected_plant_ids.push_back(plant->plant_id);
    }

    const double plant_count =
        static_cast<double>(eligible_plants.size());

    const double average_leaf_area_index =
        total_leaf_area_index / plant_count;

    const double average_evapotranspiration_rate =
        total_evapotranspiration_rate / plant_count;

    const double shading_efficiency =
        std::clamp(
            average_leaf_area_index / (average_leaf_area_index + 1.0),
            0.0,
            1.0);

    const double estimated_shade_cooling_k =
        average_leaf_area_index *
        zone.photosynthetically_active_radiation_w_per_m2 *
        shading_efficiency /
        (zone.air_density_kg_per_m3 *
         zone.air_specific_heat_j_per_kg_k *
         zone.mixing_height_m);

    const double concentration_delta =
        std::max(
            zone.inflow_concentration_kg_per_m3 -
            zone.outflow_concentration_kg_per_m3,
            0.0);

    const double estimated_pollutant_mass_removed_kg =
        concentration_delta *
        zone.water_flow_m3_per_s *
        zone.evaluation_duration_s;

    const bool native_requirements_satisfied =
        static_cast<double>(eligible_plants.size()) / plant_count >=
        policy.minimum_native_fraction;

    const bool access_requirements_satisfied =
        zone.available_buffer_width_m - selected_buffer_width +
        kEpsilon >= policy.minimum_accessibility_clear_width_m;

    const bool water_use_within_plan =
        annual_water_use_m3 <=
        policy.maximum_water_use_m3_per_year + kEpsilon;

    return RiparianPlanAssessment{
        .selected_plant_ids = std::move(selected_plant_ids),
        .selected_buffer_width_m = selected_buffer_width,
        .estimated_shade_cooling_k = estimated_shade_cooling_k,
        .estimated_pollutant_mass_removed_kg =
            estimated_pollutant_mass_removed_kg,
        .nutrient_uptake_score =
            nutrient_uptake_score / plant_count,
        .sediment_stabilization_score =
            sediment_stabilization_score / plant_count,
        .habitat_value_score =
            habitat_value_score / plant_count,
        .water_use_m3_per_year = annual_water_use_m3,
        .native_requirements_satisfied =
            native_requirements_satisfied,
        .access_requirements_satisfied =
            access_requirements_satisfied,
        .review_required = true,
        .plain_language_explanation =
            water_use_within_plan
                ? "The candidate riparian design selects native, zone-suitable, lower-maintenance plant options while preserving the configured accessible clear width. Cooling and pollutant-removal values are scenario estimates that require field hydrology, plant-survival, habitat, water-budget, maintenance, and community review."
                : "The candidate plant set exceeds the stated annual water-use budget. The plan remains evidence for review and should be evaluated with site-specific water availability, plant establishment strategy, and ecological tradeoffs."
    };
}

}  // namespace augmented_hub::eco_restoration
