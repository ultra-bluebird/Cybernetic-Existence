#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <optional>
#include <string_view>

namespace augmented_hub::solar_iot {

enum class DutyMode : std::uint8_t {
    CriticalReserve,
    BaselineOnly,
    Adaptive,
    EnergySurplus
};

struct EnergyConfiguration {
    float battery_capacity_wh;
    float minimum_state_of_charge;
    float reserve_state_of_charge;
    float maximum_state_of_charge;
    float charge_efficiency;
    float discharge_efficiency;
    float panel_area_m2;
    float panel_efficiency;
    float mppt_efficiency;
    float power_path_efficiency;
    float essential_energy_wh_per_cycle;
    float baseline_energy_wh_per_cycle;
    float optional_energy_wh_per_cycle;
    float critical_sample_interval_s;
    float baseline_sample_interval_s;
    float adaptive_min_interval_s;
    float adaptive_max_interval_s;
    float maximum_depth_of_discharge;
};

struct EnergySnapshot {
    std::int64_t observed_at_unix_s;
    float battery_state_of_charge;
    float current_harvest_w;
    float forecast_harvest_wh;
    float forecast_uncertainty_wh;
    float battery_temperature_c;
    float battery_health_fraction;
    float recent_depth_of_discharge;
    float critical_load_forecast_wh;
};

struct EnergyDecision {
    DutyMode mode;
    float sample_interval_s;
    bool enable_essential_sampling;
    bool enable_baseline_sampling;
    bool enable_optional_sampling;
    bool enable_radio_transmission;
    bool request_maintenance_review;
    float projected_state_of_charge;
    float available_energy_wh;
    std::string_view explanation;
};

constexpr float clamp(float value, float low, float high) {
    return std::max(low, std::min(value, high));
}

constexpr bool is_finite(float value) {
    return value == value
        && value != std::numeric_limits<float>::infinity()
        && value != -std::numeric_limits<float>::infinity();
}

bool validate_configuration(const EnergyConfiguration& configuration) {
    const std::array<float, 16> values = {
        configuration.battery_capacity_wh,
        configuration.minimum_state_of_charge,
        configuration.reserve_state_of_charge,
        configuration.maximum_state_of_charge,
        configuration.charge_efficiency,
        configuration.discharge_efficiency,
        configuration.panel_area_m2,
        configuration.panel_efficiency,
        configuration.mppt_efficiency,
        configuration.power_path_efficiency,
        configuration.essential_energy_wh_per_cycle,
        configuration.baseline_energy_wh_per_cycle,
        configuration.optional_energy_wh_per_cycle,
        configuration.critical_sample_interval_s,
        configuration.baseline_sample_interval_s,
        configuration.maximum_depth_of_discharge
    };

    for (const float value : values) {
        if (!is_finite(value) || value < 0.0F) {
            return false;
        }
    }

    return configuration.battery_capacity_wh > 0.0F
        && configuration.minimum_state_of_charge >= 0.0F
        && configuration.reserve_state_of_charge >= configuration.minimum_state_of_charge
        && configuration.maximum_state_of_charge <= 1.0F
        && configuration.reserve_state_of_charge <= configuration.maximum_state_of_charge
        && configuration.charge_efficiency > 0.0F
        && configuration.charge_efficiency <= 1.0F
        && configuration.discharge_efficiency > 0.0F
        && configuration.discharge_efficiency <= 1.0F
        && configuration.panel_area_m2 > 0.0F
        && configuration.panel_efficiency > 0.0F
        && configuration.panel_efficiency <= 1.0F
        && configuration.mppt_efficiency > 0.0F
        && configuration.mppt_efficiency <= 1.0F
        && configuration.power_path_efficiency > 0.0F
        && configuration.power_path_efficiency <= 1.0F
        && configuration.critical_sample_interval_s > 0.0F
        && configuration.baseline_sample_interval_s > 0.0F
        && configuration.adaptive_min_interval_s > 0.0F
        && configuration.adaptive_max_interval_s >= configuration.adaptive_min_interval_s
        && configuration.maximum_depth_of_discharge > 0.0F
        && configuration.maximum_depth_of_discharge <= 1.0F;
}

bool validate_snapshot(const EnergySnapshot& snapshot) {
    const std::array<float, 8> values = {
        snapshot.battery_state_of_charge,
        snapshot.current_harvest_w,
        snapshot.forecast_harvest_wh,
        snapshot.forecast_uncertainty_wh,
        snapshot.battery_temperature_c,
        snapshot.battery_health_fraction,
        snapshot.recent_depth_of_discharge,
        snapshot.critical_load_forecast_wh
    };

    for (const float value : values) {
        if (!is_finite(value)) {
            return false;
        }
    }

    return snapshot.observed_at_unix_s > 0
        && snapshot.battery_state_of_charge >= 0.0F
        && snapshot.battery_state_of_charge <= 1.0F
        && snapshot.current_harvest_w >= 0.0F
        && snapshot.forecast_harvest_wh >= 0.0F
        && snapshot.forecast_uncertainty_wh >= 0.0F
        && snapshot.battery_health_fraction > 0.0F
        && snapshot.battery_health_fraction <= 1.0F
        && snapshot.recent_depth_of_discharge >= 0.0F
        && snapshot.recent_depth_of_discharge <= 1.0F
        && snapshot.critical_load_forecast_wh >= 0.0F;
}

float estimate_harvested_energy_wh(
    const EnergyConfiguration& configuration,
    float plane_of_array_irradiance_w_m2,
    float interval_hours,
    float shading_fraction,
    float temperature_derate_fraction
) {
    if (!validate_configuration(configuration)
        || !is_finite(plane_of_array_irradiance_w_m2)
        || !is_finite(interval_hours)
        || !is_finite(shading_fraction)
        || !is_finite(temperature_derate_fraction)
        || plane_of_array_irradiance_w_m2 < 0.0F
        || interval_hours < 0.0F
        || shading_fraction < 0.0F
        || shading_fraction > 1.0F
        || temperature_derate_fraction < 0.0F
        || temperature_derate_fraction > 1.0F) {
        return 0.0F;
    }

    const float incident_energy_wh =
        plane_of_array_irradiance_w_m2
        * configuration.panel_area_m2
        * interval_hours;

    const float harvest_efficiency =
        configuration.panel_efficiency
        * configuration.mppt_efficiency
        * configuration.power_path_efficiency
        * (1.0F - shading_fraction)
        * (1.0F - temperature_derate_fraction);

    return std::max(0.0F, incident_energy_wh * harvest_efficiency);
}

float degradation_penalty(
    const EnergySnapshot& snapshot,
    const EnergyConfiguration& configuration
) {
    const float depth_penalty =
        clamp(
            snapshot.recent_depth_of_discharge
            / configuration.maximum_depth_of_discharge,
            0.0F,
            2.0F
        );

    const float temperature_penalty =
        snapshot.battery_temperature_c <= 35.0F
            ? 0.0F
            : clamp((snapshot.battery_temperature_c - 35.0F) / 25.0F, 0.0F, 1.0F);

    const float health_penalty = 1.0F - snapshot.battery_health_fraction;

    return clamp(
        0.55F * depth_penalty * depth_penalty
        + 0.25F * temperature_penalty
        + 0.20F * health_penalty,
        0.0F,
        1.0F
    );
}

std::optional<EnergyDecision> plan_duty_cycle(
    const EnergyConfiguration& configuration,
    const EnergySnapshot& snapshot
) {
    if (!validate_configuration(configuration) || !validate_snapshot(snapshot)) {
        return std::nullopt;
    }

    const float effective_capacity_wh =
        configuration.battery_capacity_wh * snapshot.battery_health_fraction;

    const float stored_energy_wh =
        effective_capacity_wh * snapshot.battery_state_of_charge;

    const float conservative_forecast_wh = std::max(
        0.0F,
        snapshot.forecast_harvest_wh - snapshot.forecast_uncertainty_wh
    );

    const float reserve_energy_wh =
        effective_capacity_wh * configuration.reserve_state_of_charge
        + snapshot.critical_load_forecast_wh;

    const float degradation_factor = degradation_penalty(snapshot, configuration);

    const float available_energy_wh = std::max(
        0.0F,
        stored_energy_wh
        + conservative_forecast_wh * configuration.charge_efficiency
        - reserve_energy_wh
    );

    const bool deep_cycle_risk =
        snapshot.recent_depth_of_discharge >= configuration.maximum_depth_of_discharge;

    const bool low_state_of_charge =
        snapshot.battery_state_of_charge <= configuration.minimum_state_of_charge;

    const bool reserve_state =
        snapshot.battery_state_of_charge <= configuration.reserve_state_of_charge;

    const bool maintenance_review =
        snapshot.battery_health_fraction < 0.70F
        || snapshot.battery_temperature_c > 50.0F
        || deep_cycle_risk;

    if (low_state_of_charge || available_energy_wh < configuration.essential_energy_wh_per_cycle) {
        return EnergyDecision{
            DutyMode::CriticalReserve,
            configuration.critical_sample_interval_s,
            true,
            false,
            false,
            false,
            maintenance_review,
            snapshot.battery_state_of_charge,
            available_energy_wh,
            "Critical energy reserve mode preserves essential sensing and pauses nonessential transmission."
        };
    }

    if (reserve_state || degradation_factor >= 0.70F) {
        const float projected_soc = clamp(
            (
                stored_energy_wh
                + conservative_forecast_wh * configuration.charge_efficiency
                - configuration.essential_energy_wh_per_cycle
            ) / effective_capacity_wh,
            configuration.minimum_state_of_charge,
            configuration.maximum_state_of_charge
        );

        return EnergyDecision{
            DutyMode::BaselineOnly,
            configuration.baseline_sample_interval_s,
            true,
            true,
            false,
            true,
            maintenance_review,
            projected_soc,
            available_energy_wh,
            "Reserve-protection mode preserves essential and baseline sampling while deferring optional workloads."
        };
    }

    const float surplus_scale_wh = std::max(
        configuration.baseline_energy_wh_per_cycle,
        0.01F
    );

    const float surplus_fraction = clamp(
        available_energy_wh / (4.0F * surplus_scale_wh),
        0.0F,
        1.0F
    );

    const float adaptive_interval_s =
        configuration.adaptive_max_interval_s
        - (
            configuration.adaptive_max_interval_s
            - configuration.adaptive_min_interval_s
        ) * surplus_fraction;

    const bool optional_allowed =
        available_energy_wh
        >= (
            configuration.essential_energy_wh_per_cycle
            + configuration.baseline_energy_wh_per_cycle
            + configuration.optional_energy_wh_per_cycle
        )
        && degradation_factor < 0.45F;

    const float projected_load_wh =
        configuration.essential_energy_wh_per_cycle
        + configuration.baseline_energy_wh_per_cycle
        + (optional_allowed ? configuration.optional_energy_wh_per_cycle : 0.0F);

    const float projected_soc = clamp(
        (
            stored_energy_wh
            + conservative_forecast_wh * configuration.charge_efficiency
            - projected_load_wh / configuration.discharge_efficiency
        ) / effective_capacity_wh,
        configuration.minimum_state_of_charge,
        configuration.maximum_state_of_charge
    );

    if (optional_allowed && surplus_fraction >= 0.70F) {
        return EnergyDecision{
            DutyMode::EnergySurplus,
            configuration.adaptive_min_interval_s,
            true,
            true,
            true,
            true,
            maintenance_review,
            projected_soc,
            available_energy_wh,
            "Forecasted energy surplus supports higher-rate ecological sampling and batched telemetry."
        };
    }

    return EnergyDecision{
        DutyMode::Adaptive,
        adaptive_interval_s,
        true,
        true,
        optional_allowed,
        true,
        maintenance_review,
        projected_soc,
        available_energy_wh,
        "Adaptive mode maintains baseline ecological sampling while scaling optional work to conservative energy availability."
    };
}

}  // namespace augmented_hub::solar_iot
