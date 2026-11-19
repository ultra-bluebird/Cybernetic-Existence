#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <stdexcept>
#include <vector>

namespace augmented_hub::bioswale {

struct HexBioswaleState {
    double pollutant_load_kg{};
    double design_infiltration_m3_per_s{};
    double design_removal_fraction{};
    double maintenance_condition{};
    double dust_loading{};
    double traffic_shear{};
    double maintenance_action{};
};

struct DecayParameters {
    double dust_decay_per_loading_step{};
    double shear_decay_per_shear_step{};
    double maintenance_recovery_fraction{};
};

struct OptimizationResult {
    double peak_l2_load_kg{};
    std::vector<double> updated_conditions{};
    bool maintenance_floor_met{};
};

static void require_finite_non_negative(double value, const char* name) {
    if (!std::isfinite(value) || value < 0.0) {
        throw std::invalid_argument(name);
    }
}

static void validate_state(const HexBioswaleState& state) {
    require_finite_non_negative(state.pollutant_load_kg, "invalid pollutant load");
    require_finite_non_negative(
        state.design_infiltration_m3_per_s,
        "invalid design infiltration"
    );
    require_finite_non_negative(
        state.design_removal_fraction,
        "invalid design removal fraction"
    );
    require_finite_non_negative(state.dust_loading, "invalid dust loading");
    require_finite_non_negative(state.traffic_shear, "invalid traffic shear");

    if (!std::isfinite(state.maintenance_condition) ||
        state.maintenance_condition < 0.0 ||
        state.maintenance_condition > 1.0) {
        throw std::invalid_argument("maintenance condition must be in [0, 1]");
    }

    if (!std::isfinite(state.maintenance_action) ||
        state.maintenance_action < 0.0 ||
        state.maintenance_action > 1.0) {
        throw std::invalid_argument("maintenance action must be in [0, 1]");
    }

    if (state.design_removal_fraction > 1.0) {
        throw std::invalid_argument("design removal fraction must be in [0, 1]");
    }
}

static void validate_decay(const DecayParameters& parameters) {
    require_finite_non_negative(
        parameters.dust_decay_per_loading_step,
        "invalid dust decay"
    );
    require_finite_non_negative(
        parameters.shear_decay_per_shear_step,
        "invalid shear decay"
    );

    if (!std::isfinite(parameters.maintenance_recovery_fraction) ||
        parameters.maintenance_recovery_fraction < 0.0 ||
        parameters.maintenance_recovery_fraction > 1.0) {
        throw std::invalid_argument(
            "maintenance recovery fraction must be in [0, 1]"
        );
    }
}

static double next_condition(
    const HexBioswaleState& state,
    const DecayParameters& parameters
) {
    const double degradation =
        parameters.dust_decay_per_loading_step * state.dust_loading +
        parameters.shear_decay_per_shear_step * state.traffic_shear;

    const double degraded =
        state.maintenance_condition * std::exp(-degradation);

    const double recovered =
        degraded + state.maintenance_action *
            parameters.maintenance_recovery_fraction *
            (1.0 - degraded);

    return std::clamp(recovered, 0.0, 1.0);
}

OptimizationResult evaluate_peak_l2_load(
    const std::vector<HexBioswaleState>& states,
    const DecayParameters& parameters,
    double minimum_condition
) {
    validate_decay(parameters);

    if (!std::isfinite(minimum_condition) ||
        minimum_condition < 0.0 ||
        minimum_condition > 1.0) {
        throw std::invalid_argument("minimum condition must be in [0, 1]");
    }

    if (states.empty()) {
        throw std::invalid_argument("at least one hex state is required");
    }

    double sum_of_squares = 0.0;
    bool maintenance_floor_met = true;
    std::vector<double> updated_conditions;
    updated_conditions.reserve(states.size());

    for (const auto& state : states) {
        validate_state(state);

        const double condition = next_condition(state, parameters);
        const double effective_removal =
            condition * state.design_removal_fraction;

        const double outlet_load =
            state.pollutant_load_kg * (1.0 - effective_removal);

        sum_of_squares += outlet_load * outlet_load;
        maintenance_floor_met =
            maintenance_floor_met && condition >= minimum_condition;

        updated_conditions.push_back(condition);
    }

    return {
        std::sqrt(sum_of_squares),
        std::move(updated_conditions),
        maintenance_floor_met
    };
}

}  // namespace augmented_hub::bioswale
