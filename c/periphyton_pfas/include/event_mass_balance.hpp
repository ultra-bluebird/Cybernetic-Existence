#ifndef EVENT_MASS_BALANCE_HPP
#define EVENT_MASS_BALANCE_HPP

#include <cmath>
#include <stdexcept>
#include <string>

namespace periphyton_pfas {

struct PhaseConcentration {
    double dissolved_pfas_ng_m3;
    double particulate_pfas_ng_kg;
    double suspended_solids_kg_m3;
    double dissolved_uncertainty_ng_m3;
    double particulate_uncertainty_ng_kg;
    double suspended_solids_uncertainty_kg_m3;
};

struct FlowMeasurement {
    double discharge_m3_s;
    double discharge_uncertainty_m3_s;
};

struct FluxResult {
    double total_flux_ng_s;
    double standard_uncertainty_ng_s;
    double expanded_uncertainty_ng_s;
    bool resolved;
};

inline double calculate_particulate_water_basis_concentration(
    const PhaseConcentration& conc)
{
    if (conc.particulate_pfas_ng_kg < 0.0 || conc.suspended_solids_kg_m3 < 0.0) {
        throw std::invalid_argument(
            "particulate concentration and suspended solids must be non-negative");
    }
    return conc.particulate_pfas_ng_kg * conc.suspended_solids_kg_m3;
}

inline double calculate_total_concentration_ng_m3(const PhaseConcentration& conc)
{
    if (conc.dissolved_pfas_ng_m3 < 0.0) {
        throw std::invalid_argument("dissolved concentration must be non-negative");
    }
    double particulate_water_basis = calculate_particulate_water_basis_concentration(conc);
    return conc.dissolved_pfas_ng_m3 + particulate_water_basis;
}

inline FluxResult calculate_total_flux(
    const PhaseConcentration& conc,
    const FlowMeasurement& flow)
{
    if (flow.discharge_m3_s < 0.0) {
        throw std::invalid_argument("discharge must be non-negative");
    }
    if (conc.dissolved_pfas_ng_m3 < 0.0 || conc.particulate_pfas_ng_kg < 0.0
        || conc.suspended_solids_kg_m3 < 0.0) {
        throw std::invalid_argument("concentrations must be non-negative");
    }

    double total_conc = calculate_total_concentration_ng_m3(conc);
    double total_flux = total_conc * flow.discharge_m3_s;

    double variance_conc =
        conc.dissolved_uncertainty_ng_m3 * conc.dissolved_uncertainty_ng_m3 +
        (conc.particulate_uncertainty_ng_kg * conc.suspended_solids_kg_m3 +
         conc.particulate_pfas_ng_kg * conc.suspended_solids_uncertainty_kg_m3) *
        (conc.particulate_uncertainty_ng_kg * conc.suspended_solids_kg_m3 +
         conc.particulate_pfas_ng_kg * conc.suspended_solids_uncertainty_kg_m3);

    double standard_uncertainty = std::sqrt(
        variance_conc * flow.discharge_m3_s * flow.discharge_m3_s +
        total_conc * total_conc * flow.discharge_uncertainty_m3_s * flow.discharge_uncertainty_m3_s
    );

    double coverage_factor = 2.0;
    double expanded_uncertainty = coverage_factor * standard_uncertainty;

    bool resolved = (total_flux > expanded_uncertainty);

    return FluxResult{
        total_flux,
        standard_uncertainty,
        expanded_uncertainty,
        resolved
    };
}

struct FluxIncrementResult {
    double net_flux_ng_s;
    double standard_uncertainty_ng_s;
    double expanded_uncertainty_ng_s;
    bool resolved;
};

inline FluxIncrementResult subtract_fluxes(
    const FluxResult& downstream,
    const FluxResult& upstream,
    double coverage_factor)
{
    if (coverage_factor <= 0.0) {
        throw std::invalid_argument("coverage factor must be positive");
    }

    double net_flux = downstream.total_flux_ng_s - upstream.total_flux_ng_s;

    double combined_variance =
        downstream.standard_uncertainty_ng_s * downstream.standard_uncertainty_ng_s +
        upstream.standard_uncertainty_ng_s * upstream.standard_uncertainty_ng_s;

    double combined_standard_uncertainty = std::sqrt(combined_variance);
    double expanded_uncertainty = coverage_factor * combined_standard_uncertainty;

    bool resolved = (std::abs(net_flux) > expanded_uncertainty);

    return FluxIncrementResult{
        net_flux,
        combined_standard_uncertainty,
        expanded_uncertainty,
        resolved
    };
}

} // namespace periphyton_pfas

#endif // EVENT_MASS_BALANCE_HPP
