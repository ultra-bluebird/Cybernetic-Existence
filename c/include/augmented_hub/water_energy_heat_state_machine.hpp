#ifndef AUGMENTED_HUB_WATER_ENERGY_HEAT_STATE_MACHINE_HPP
#define AUGMENTED_HUB_WATER_ENERGY_HEAT_STATE_MACHINE_HPP

#include <cmath>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>

namespace augmented_hub {

enum class NexusState {
    Normal,
    WaterStress,
    HeatAlert,
    GridWaterPeak,
    ThermalDemandHigh,
    CombinedStress,
    Emergency
};

struct NexusThresholds {
    int water_stress_stage_threshold;
    double grid_water_factor_peak_threshold;
    double thermal_demand_high_kw;
};

struct NexusInputs {
    std::optional<int> water_stress_stage;
    std::optional<bool> heat_alert_active;
    std::optional<double> grid_water_factor;
    std::optional<double> thermal_demand_kw;
    std::optional<bool> critical_threshold_breach;
    std::optional<bool> telemetry_consistent;
    std::optional<bool> human_review_approved;
};

struct TransitionResult {
    NexusState prior_state;
    NexusState next_state;
    bool ker_re_evaluation_required;
    bool human_review_required;
    std::string explanation_code;
};

class WaterEnergyHeatStateMachine final {
public:
    explicit WaterEnergyHeatStateMachine(NexusThresholds thresholds)
        : thresholds_(thresholds) {
        validate_thresholds();
    }

    [[nodiscard]] TransitionResult transition(
        NexusState current,
        const NexusInputs& inputs
    ) const {
        if (!inputs_complete(inputs) || !inputs_consistent(inputs)) {
            return emergency_transition(
                current,
                "NEXUS_INPUT_MISSING_OR_CONTRADICTORY_EMERGENCY"
            );
        }

        if (inputs.critical_threshold_breach.value()) {
            return emergency_transition(
                current,
                "NEXUS_CRITICAL_THRESHOLD_BREACH_EMERGENCY"
            );
        }

        if (current == NexusState::Emergency &&
            !inputs.human_review_approved.value()) {
            return {
                current,
                NexusState::Emergency,
                true,
                true,
                "EMERGENCY_EXIT_HUMAN_REVIEW_REQUIRED"
            };
        }

        const bool water_stress =
            inputs.water_stress_stage.value() >=
            thresholds_.water_stress_stage_threshold;

        const bool heat_alert = inputs.heat_alert_active.value();

        const bool grid_water_peak =
            inputs.grid_water_factor.value() >=
            thresholds_.grid_water_factor_peak_threshold;

        const bool thermal_demand_high =
            inputs.thermal_demand_kw.value() >=
            thresholds_.thermal_demand_high_kw;

        const int active_stresses =
            static_cast<int>(water_stress)
            + static_cast<int>(heat_alert)
            + static_cast<int>(grid_water_peak)
            + static_cast<int>(thermal_demand_high);

        NexusState next = NexusState::Normal;

        if (active_stresses >= 2) {
            next = NexusState::CombinedStress;
        } else if (water_stress) {
            next = NexusState::WaterStress;
        } else if (heat_alert) {
            next = NexusState::HeatAlert;
        } else if (grid_water_peak) {
            next = NexusState::GridWaterPeak;
        } else if (thermal_demand_high) {
            next = NexusState::ThermalDemandHigh;
        }

        return {
            current,
            next,
            current != next,
            current == NexusState::Emergency || next == NexusState::CombinedStress,
            current == next
                ? "NEXUS_STATE_UNCHANGED"
                : "NEXUS_STATE_CHANGED_KER_REEVALUATION_REQUIRED"
        };
    }

private:
    NexusThresholds thresholds_;

    void validate_thresholds() const {
        if (thresholds_.water_stress_stage_threshold < 0 ||
            thresholds_.water_stress_stage_threshold > 5) {
            throw std::invalid_argument(
                "water_stress_stage_threshold must be within 0..5."
            );
        }

        if (!std::isfinite(thresholds_.grid_water_factor_peak_threshold) ||
            thresholds_.grid_water_factor_peak_threshold < 0.0) {
            throw std::invalid_argument(
                "grid_water_factor_peak_threshold must be finite and non-negative."
            );
        }

        if (!std::isfinite(thresholds_.thermal_demand_high_kw) ||
            thresholds_.thermal_demand_high_kw < 0.0) {
            throw std::invalid_argument(
                "thermal_demand_high_kw must be finite and non-negative."
            );
        }
    }

    [[nodiscard]] static bool inputs_complete(const NexusInputs& inputs) {
        return inputs.water_stress_stage.has_value()
            && inputs.heat_alert_active.has_value()
            && inputs.grid_water_factor.has_value()
            && inputs.thermal_demand_kw.has_value()
            && inputs.critical_threshold_breach.has_value()
            && inputs.telemetry_consistent.has_value()
            && inputs.human_review_approved.has_value();
    }

    [[nodiscard]] static bool inputs_consistent(const NexusInputs& inputs) {
        if (!inputs.telemetry_consistent.value_or(false)) {
            return false;
        }

        if (inputs.water_stress_stage.value() < 0 ||
            inputs.water_stress_stage.value() > 5) {
            return false;
        }

        return std::isfinite(inputs.grid_water_factor.value())
            && inputs.grid_water_factor.value() >= 0.0
            && std::isfinite(inputs.thermal_demand_kw.value())
            && inputs.thermal_demand_kw.value() >= 0.0;
    }

    [[nodiscard]] static TransitionResult emergency_transition(
        NexusState prior,
        std::string explanation_code
    ) {
        return {
            prior,
            NexusState::Emergency,
            true,
            true,
            std::move(explanation_code)
        };
    }
};

}  // namespace augmented_hub

#endif
