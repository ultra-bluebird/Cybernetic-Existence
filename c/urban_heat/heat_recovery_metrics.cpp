#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <string>

namespace augmented_hub::urban_heat {

struct ResultMetrics {
    double knowledge_factor{};
    double eco_impact_value{};
    double harm_risk{};
    double accessibility_impact{};
    double rights_alignment{};
    double net_heat_flux_reduction_w_per_m2{};
    double water_balance_change_mm_per_day{};
    std::string explanation{};
};

struct HeatRecoveryInputs {
    double solar_irradiance_w_per_m2{};
    double baseline_surface_albedo{};
    double reflective_pavement_fraction{};
    double reflective_pavement_albedo{};
    double tree_canopy_fraction{};
    double canopy_albedo{};
    double canopy_evapotranspiration_mm_per_day{};
    double latent_heat_of_vaporization_j_per_kg{};
    double water_available_for_evapotranspiration_mm_per_day{};
    double rainfall_recharge_mm_per_day{};
    double irrigation_input_mm_per_day{};
    double runoff_loss_mm_per_day{};
    double deep_percolation_loss_mm_per_day{};
    double eco_benefit_reference_w_per_m2{};
};

struct HeatRecoveryAssessment {
    double reflective_albedo_heat_reduction_w_per_m2{};
    double canopy_albedo_heat_reduction_w_per_m2{};
    double evapotranspiration_heat_reduction_w_per_m2{};
    double net_heat_flux_reduction_w_per_m2{};
    double actual_evapotranspiration_mm_per_day{};
    double water_balance_change_mm_per_day{};
    double eco_impact_contributor{};
    ResultMetrics result_metrics{};
};

void require_finite_non_negative(const char* field, double value) {
    if (!std::isfinite(value) || value < 0.0) {
        throw std::invalid_argument(std::string(field) + " must be finite and non-negative");
    }
}

void require_unit_interval(const char* field, double value) {
    if (!std::isfinite(value) || value < 0.0 || value > 1.0) {
        throw std::invalid_argument(std::string(field) + " must be within [0, 1]");
    }
}

double clamp_unit_interval(double value) {
    return std::clamp(value, 0.0, 1.0);
}

double millimeters_per_day_to_latent_heat_flux_w_per_m2(
    double evapotranspiration_mm_per_day,
    double latent_heat_of_vaporization_j_per_kg
) {
    require_finite_non_negative("evapotranspiration_mm_per_day", evapotranspiration_mm_per_day);
    require_finite_non_negative("latent_heat_of_vaporization_j_per_kg", latent_heat_of_vaporization_j_per_kg);

    constexpr double seconds_per_day = 86'400.0;
    constexpr double kilograms_per_square_meter_per_millimeter = 1.0;

    return (
        evapotranspiration_mm_per_day
        * kilograms_per_square_meter_per_millimeter
        * latent_heat_of_vaporization_j_per_kg
    ) / seconds_per_day;
}

HeatRecoveryAssessment assess_heat_recovery(const HeatRecoveryInputs& inputs) {
    require_finite_non_negative("solar_irradiance_w_per_m2", inputs.solar_irradiance_w_per_m2);
    require_unit_interval("baseline_surface_albedo", inputs.baseline_surface_albedo);
    require_unit_interval("reflective_pavement_fraction", inputs.reflective_pavement_fraction);
    require_unit_interval("reflective_pavement_albedo", inputs.reflective_pavement_albedo);
    require_unit_interval("tree_canopy_fraction", inputs.tree_canopy_fraction);
    require_unit_interval("canopy_albedo", inputs.canopy_albedo);
    require_finite_non_negative(
        "canopy_evapotranspiration_mm_per_day",
        inputs.canopy_evapotranspiration_mm_per_day
    );
    require_finite_non_negative(
        "water_available_for_evapotranspiration_mm_per_day",
        inputs.water_available_for_evapotranspiration_mm_per_day
    );
    require_finite_non_negative("rainfall_recharge_mm_per_day", inputs.rainfall_recharge_mm_per_day);
    require_finite_non_negative("irrigation_input_mm_per_day", inputs.irrigation_input_mm_per_day);
    require_finite_non_negative("runoff_loss_mm_per_day", inputs.runoff_loss_mm_per_day);
    require_finite_non_negative(
        "deep_percolation_loss_mm_per_day",
        inputs.deep_percolation_loss_mm_per_day
    );
    require_finite_non_negative("eco_benefit_reference_w_per_m2", inputs.eco_benefit_reference_w_per_m2);

    const double reflective_albedo_gain = std::max(
        0.0,
        inputs.reflective_pavement_albedo - inputs.baseline_surface_albedo
    );

    const double canopy_albedo_gain = std::max(
        0.0,
        inputs.canopy_albedo - inputs.baseline_surface_albedo
    );

    const double actual_evapotranspiration_mm_per_day = std::min(
        inputs.canopy_evapotranspiration_mm_per_day,
        inputs.water_available_for_evapotranspiration_mm_per_day
    );

    const double reflective_albedo_heat_reduction_w_per_m2 =
        inputs.solar_irradiance_w_per_m2
        * inputs.reflective_pavement_fraction
        * reflective_albedo_gain;

    const double canopy_albedo_heat_reduction_w_per_m2 =
        inputs.solar_irradiance_w_per_m2
        * inputs.tree_canopy_fraction
        * canopy_albedo_gain;

    const double evapotranspiration_heat_reduction_w_per_m2 =
        inputs.tree_canopy_fraction
        * millimeters_per_day_to_latent_heat_flux_w_per_m2(
            actual_evapotranspiration_mm_per_day,
            inputs.latent_heat_of_vaporization_j_per_kg
        );

    const double net_heat_flux_reduction_w_per_m2 =
        reflective_albedo_heat_reduction_w_per_m2
        + canopy_albedo_heat_reduction_w_per_m2
        + evapotranspiration_heat_reduction_w_per_m2;

    const double water_balance_change_mm_per_day =
        inputs.rainfall_recharge_mm_per_day
        + inputs.irrigation_input_mm_per_day
        - actual_evapotranspiration_mm_per_day
        - inputs.runoff_loss_mm_per_day
        - inputs.deep_percolation_loss_mm_per_day;

    const double eco_impact_contributor =
        inputs.eco_benefit_reference_w_per_m2 > 0.0
            ? clamp_unit_interval(
                net_heat_flux_reduction_w_per_m2
                / inputs.eco_benefit_reference_w_per_m2
            )
            : 0.0;

    ResultMetrics result_metrics{
        .knowledge_factor = 0.90,
        .eco_impact_value = eco_impact_contributor,
        .harm_risk = water_balance_change_mm_per_day < 0.0 ? 0.30 : 0.12,
        .accessibility_impact = 0.88,
        .rights_alignment = 0.94,
        .net_heat_flux_reduction_w_per_m2 = net_heat_flux_reduction_w_per_m2,
        .water_balance_change_mm_per_day = water_balance_change_mm_per_day,
        .explanation =
            "Net heat-flux reduction combines reflective pavement albedo gain, canopy albedo gain, and the latent heat flux associated with water-limited evapotranspiration. The eco-impact contribution is normalized against a locally defined, reviewable heat-reduction reference.",
    };

    return HeatRecoveryAssessment{
        .reflective_albedo_heat_reduction_w_per_m2 =
            reflective_albedo_heat_reduction_w_per_m2,
        .canopy_albedo_heat_reduction_w_per_m2 =
            canopy_albedo_heat_reduction_w_per_m2,
        .evapotranspiration_heat_reduction_w_per_m2 =
            evapotranspiration_heat_reduction_w_per_m2,
        .net_heat_flux_reduction_w_per_m2 = net_heat_flux_reduction_w_per_m2,
        .actual_evapotranspiration_mm_per_day =
            actual_evapotranspiration_mm_per_day,
        .water_balance_change_mm_per_day = water_balance_change_mm_per_day,
        .eco_impact_contributor = eco_impact_contributor,
        .result_metrics = result_metrics,
    };
}

}  // namespace augmented_hub::urban_heat
