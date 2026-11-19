#ifndef AUGMENTED_HUB_HEAT_ISLAND_AND_RIPARIAN_PLANNING_HPP
#define AUGMENTED_HUB_HEAT_ISLAND_AND_RIPARIAN_PLANNING_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::eco_restoration {

enum class EcoPlanningError {
    empty_input,
    invalid_numeric_input,
    duplicate_identifier,
    infeasible_plan,
    insufficient_evidence
};

enum class HeatMitigationType {
    green_roof,
    reflective_surface,
    shade_canopy,
    native_vegetation
};

enum class CorridorZone {
    residential,
    commercial,
    industrial
};

struct UrbanSurfaceProfile {
    double total_area_m2{};
    double asphalt_fraction{};
    double rooftop_fraction{};
    double mixed_land_use_fraction{};
    double incoming_radiation_w_per_m2{};
    double air_mass_kg{};
    double air_specific_heat_j_per_kg_k{};
    double anthropogenic_heat_flux_w_per_m2{};
};

struct HeatMitigationCandidate {
    std::string candidate_id;
    HeatMitigationType type{};
    double area_m2{};
    double capital_cost{};
    double annual_maintenance_cost{};
    double baseline_albedo{};
    double improved_albedo{};
    double evapotranspiration_rate_kg_per_m2_s{};
    double latent_heat_j_per_kg{};
    double shade_effectiveness{};
    double ecological_benefit{};
    double water_use_m3_per_year{};
    double accessibility_benefit{};
};

struct HeatMitigationPolicy {
    double total_budget{};
    double maximum_annual_water_use_m3{};
    double minimum_ecological_benefit{};
    double minimum_accessibility_benefit{};
    double minimum_temperature_reduction_k{};
};

struct HeatMitigationAssessment {
    std::vector<std::string> selected_candidate_ids;
    double total_cost{};
    double annual_water_use_m3{};
    double reflected_heat_reduction_w{};
    double evapotranspiration_cooling_w{};
    double shade_cooling_w{};
    double estimated_temperature_reduction_k{};
    double ecological_benefit{};
    double accessibility_benefit{};
    bool constraints_satisfied{};
    std::string plain_language_explanation;
};

struct RiparianPlantOption {
    std::string plant_id;
    std::string common_name;
    CorridorZone suitable_zone{};
    bool native_to_project_region{};
    double mature_leaf_area_index{};
    double evapotranspiration_rate_kg_per_m2_s{};
    double nutrient_uptake_score{};
    double sediment_stabilization_score{};
    double habitat_value_score{};
    double annual_maintenance_score{};
    double annual_water_use_m3_per_m2{};
};

struct RiparianZoneProfile {
    std::string zone_id;
    CorridorZone zone_type{};
    double available_buffer_width_m{};
    double corridor_length_m{};
    double photosynthetically_active_radiation_w_per_m2{};
    double air_density_kg_per_m3{};
    double air_specific_heat_j_per_kg_k{};
    double mixing_height_m{};
    double inflow_concentration_kg_per_m3{};
    double outflow_concentration_kg_per_m3{};
    double water_flow_m3_per_s{};
    double evaluation_duration_s{};
};

struct RiparianPolicy {
    double total_budget{};
    double maximum_water_use_m3_per_year{};
    double minimum_buffer_width_m{};
    double minimum_native_fraction{1.0};
    double minimum_accessibility_clear_width_m{};
    double maximum_maintenance_score{};
};

struct RiparianPlanAssessment {
    std::vector<std::string> selected_plant_ids;
    double selected_buffer_width_m{};
    double estimated_shade_cooling_k{};
    double estimated_pollutant_mass_removed_kg{};
    double nutrient_uptake_score{};
    double sediment_stabilization_score{};
    double habitat_value_score{};
    double water_use_m3_per_year{};
    bool native_requirements_satisfied{};
    bool access_requirements_satisfied{};
    bool review_required{};
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<HeatMitigationAssessment, EcoPlanningError>
evaluate_heat_mitigation_portfolio(
    const UrbanSurfaceProfile& surface,
    const std::vector<HeatMitigationCandidate>& candidates,
    const HeatMitigationPolicy& policy);

[[nodiscard]] std::expected<RiparianPlanAssessment, EcoPlanningError>
evaluate_riparian_restoration_plan(
    const RiparianZoneProfile& zone,
    const std::vector<RiparianPlantOption>& plants,
    const RiparianPolicy& policy);

}  // namespace augmented_hub::eco_restoration

#endif
