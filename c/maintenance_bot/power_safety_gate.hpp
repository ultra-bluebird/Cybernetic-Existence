#ifndef AUGMENTED_HUB_MAINTENANCE_BOT_POWER_SAFETY_GATE_HPP
#define AUGMENTED_HUB_MAINTENANCE_BOT_POWER_SAFETY_GATE_HPP

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <string_view>

namespace augmented_hub::maintenance_bot {

enum class BmsStatus {
    Healthy,
    Fault,
    Unknown
};

enum class ThermalStatus {
    WithinApprovedRange,
    OutsideApprovedRange,
    Unknown
};

enum class PowerAction {
    PermitPlanningReview,
    ReturnToApprovedChargePoint,
    EnterSafeMaintenanceState
};

struct BatterySafetyLimits {
    double minimum_operational_soc_fraction;
    double maximum_operational_soc_fraction;
    double return_reserve_soc_fraction;
};

struct BatteryState {
    double state_of_charge_fraction;
    double state_of_health_fraction;
    BmsStatus bms_status;
    ThermalStatus thermal_status;
};

struct PowerDecision {
    PowerAction action;
    std::string_view reason;
};

inline bool is_fraction(double value) {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

inline bool is_valid_limits(const BatterySafetyLimits& limits) {
    return is_fraction(limits.minimum_operational_soc_fraction) &&
           is_fraction(limits.maximum_operational_soc_fraction) &&
           is_fraction(limits.return_reserve_soc_fraction) &&
           limits.minimum_operational_soc_fraction <
               limits.maximum_operational_soc_fraction &&
           limits.return_reserve_soc_fraction >=
               limits.minimum_operational_soc_fraction &&
           limits.return_reserve_soc_fraction <=
               limits.maximum_operational_soc_fraction;
}

inline PowerDecision evaluate_power_safety(
    const BatterySafetyLimits& limits,
    const BatteryState& state
) {
    if (!is_valid_limits(limits)) {
        return {
            PowerAction::EnterSafeMaintenanceState,
            "Battery safety limits are invalid."
        };
    }

    if (!is_fraction(state.state_of_charge_fraction) ||
        !is_fraction(state.state_of_health_fraction)) {
        return {
            PowerAction::EnterSafeMaintenanceState,
            "Battery state values are invalid."
        };
    }

    if (state.bms_status != BmsStatus::Healthy) {
        return {
            PowerAction::EnterSafeMaintenanceState,
            "Battery-management system health is not approved."
        };
    }

    if (state.thermal_status != ThermalStatus::WithinApprovedRange) {
        return {
            PowerAction::EnterSafeMaintenanceState,
            "Battery temperature is outside the approved operating range."
        };
    }

    if (state.state_of_charge_fraction <
        limits.return_reserve_soc_fraction) {
        return {
            PowerAction::ReturnToApprovedChargePoint,
            "Battery state of charge is below the return reserve."
        };
    }

    return {
        PowerAction::PermitPlanningReview,
        "Battery state permits review of a reserve-preserving work plan."
    };
}

inline double clamp_charge_target(
    const BatterySafetyLimits& limits,
    double requested_target_soc_fraction
) {
    if (!is_valid_limits(limits) ||
        !is_fraction(requested_target_soc_fraction)) {
        return limits.minimum_operational_soc_fraction;
    }

    return std::clamp(
        requested_target_soc_fraction,
        limits.minimum_operational_soc_fraction,
        limits.maximum_operational_soc_fraction
    );
}

}  // namespace augmented_hub::maintenance_bot

#endif
