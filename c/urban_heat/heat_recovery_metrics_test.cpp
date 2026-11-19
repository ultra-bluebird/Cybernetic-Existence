#include "heat_recovery_metrics.cpp"

#include <cassert>
#include <cmath>

int main() {
    using namespace augmented_hub::urban_heat;

    const HeatRecoveryInputs inputs{
        .solar_irradiance_w_per_m2 = 800.0,
        .baseline_surface_albedo = 0.15,
        .reflective_pavement_fraction = 0.50,
        .reflective_pavement_albedo = 0.45,
        .tree_canopy_fraction = 0.25,
        .canopy_albedo = 0.20,
        .canopy_evapotranspiration_mm_per_day = 4.0,
        .latent_heat_of_vaporization_j_per_kg = 2'450'000.0,
        .water_available_for_evapotranspiration_mm_per_day = 3.0,
        .rainfall_recharge_mm_per_day = 1.0,
        .irrigation_input_mm_per_day = 4.0,
        .runoff_loss_mm_per_day = 0.5,
        .deep_percolation_loss_mm_per_day = 0.5,
        .eco_benefit_reference_w_per_m2 = 150.0,
    };

    const HeatRecoveryAssessment assessment = assess_heat_recovery(inputs);

    assert(std::abs(
        assessment.reflective_albedo_heat_reduction_w_per_m2 - 120.0
    ) < 0.0001);

    assert(std::abs(
        assessment.canopy_albedo_heat_reduction_w_per_m2 - 10.0
    ) < 0.0001);

    assert(std::abs(
        assessment.actual_evapotranspiration_mm_per_day - 3.0
    ) < 0.0001);

    assert(assessment.evapotranspiration_heat_reduction_w_per_m2 > 21.0);
    assert(assessment.net_heat_flux_reduction_w_per_m2 > 151.0);
    assert(assessment.result_metrics.eco_impact_value == 1.0);
    assert(std::abs(assessment.water_balance_change_mm_per_day - 1.0) < 0.0001);

    return 0;
}
