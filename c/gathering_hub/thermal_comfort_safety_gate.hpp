#ifndef AUGMENTED_HUB_GATHERING_HUB_THERMAL_COMFORT_SAFETY_GATE_HPP
#define AUGMENTED_HUB_GATHERING_HUB_THERMAL_COMFORT_SAFETY_GATE_HPP

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <string_view>

namespace augmented_hub::gathering_hub {

enum class SensorHealth {
    Healthy,
    Stale,
    Fault
};

enum class OutdoorAirQuality {
    Acceptable,
    Degraded,
    EmergencyRestricted,
    Unknown
};

enum class ThermalAction {
    ApplyBoundedControl,
    RevertToApprovedMinimumVentilation,
    HoldConservativeSetpointAndEscalate
};

struct ComfortEnvelope {
    double minimum_zone_temperature_celsius;
    double maximum_zone_temperature_celsius;
    double maximum_temperature_change_celsius_per_minute;
    double minimum_relative_humidity_fraction;
    double maximum_relative_humidity_fraction;
};

struct ThermalSample {
    double zone_temperature_celsius;
    double relative_humidity_fraction;
    double co2_ppm;
    double temperature_change_celsius_per_minute;
    SensorHealth temperature_sensor_health;
    SensorHealth humidity_sensor_health;
    SensorHealth co2_sensor_health;
    OutdoorAirQuality outdoor_air_quality;
};

struct ThermalDecision {
    ThermalAction action;
    std::string_view reason;
    bool allow_demand_controlled_ventilation;
};

inline bool is_finite_in_range(double value, double minimum, double maximum) {
    return std::isfinite(value) && value >= minimum && value <= maximum;
}

inline bool is_valid_envelope(const ComfortEnvelope& envelope) {
    return
        is_finite_in_range(
            envelope.minimum_zone_temperature_celsius,
            10.0,
            30.0
        ) &&
        is_finite_in_range(
            envelope.maximum_zone_temperature_celsius,
            15.0,
            35.0
        ) &&
        envelope.minimum_zone_temperature_celsius <
            envelope.maximum_zone_temperature_celsius &&
        is_finite_in_range(
            envelope.maximum_temperature_change_celsius_per_minute,
            0.001,
            0.5
        ) &&
        is_finite_in_range(
            envelope.minimum_relative_humidity_fraction,
            0.1,
            0.6
        ) &&
        is_finite_in_range(
            envelope.maximum_relative_humidity_fraction,
            0.3,
            0.8
        ) &&
        envelope.minimum_relative_humidity_fraction <=
            envelope.maximum_relative_humidity_fraction;
}

inline ThermalDecision evaluate_thermal_safety(
    const ComfortEnvelope& envelope,
    const ThermalSample& sample
) {
    if (!is_valid_envelope(envelope)) {
        return {
            ThermalAction::HoldConservativeSetpointAndEscalate,
            "Thermal comfort envelope is invalid.",
            false
        };
    }

    if (
        sample.temperature_sensor_health != SensorHealth::Healthy ||
        sample.humidity_sensor_health != SensorHealth::Healthy ||
        sample.co2_sensor_health != SensorHealth::Healthy
    ) {
        return {
            ThermalAction::RevertToApprovedMinimumVentilation,
            "A required thermal or indoor-air-quality sensor is stale or faulty.",
            false
        };
    }

    if (
        !is_finite_in_range(sample.zone_temperature_celsius, -40.0, 80.0) ||
        !is_finite_in_range(sample.relative_humidity_fraction, 0.0, 1.0) ||
        !is_finite_in_range(sample.co2_ppm, 0.0, 10000.0) ||
        !std::isfinite(sample.temperature_change_celsius_per_minute)
    ) {
        return {
            ThermalAction::HoldConservativeSetpointAndEscalate,
            "Thermal sample values are invalid.",
            false
        };
    }

    if (
        std::abs(sample.temperature_change_celsius_per_minute) >
        envelope.maximum_temperature_change_celsius_per_minute
    ) {
        return {
            ThermalAction::HoldConservativeSetpointAndEscalate,
            "Temperature is changing faster than the approved stability limit.",
            false
        };
    }

    if (sample.outdoor_air_quality == OutdoorAirQuality::EmergencyRestricted) {
        return {
            ThermalAction::HoldConservativeSetpointAndEscalate,
            "Outdoor air quality requires the approved emergency ventilation sequence.",
            false
        };
    }

    if (sample.outdoor_air_quality == OutdoorAirQuality::Unknown) {
        return {
            ThermalAction::RevertToApprovedMinimumVentilation,
            "Outdoor air quality status is unknown.",
            false
        };
    }

    return {
        ThermalAction::ApplyBoundedControl,
        "Thermal, humidity, carbon-dioxide, and outdoor-air-quality inputs permit bounded local control.",
        sample.outdoor_air_quality == OutdoorAirQuality::Acceptable
    };
}

inline double clamp_temperature_target(
    const ComfortEnvelope& envelope,
    double requested_target_celsius
) {
    if (!is_valid_envelope(envelope) || !std::isfinite(requested_target_celsius)) {
        return 22.0;
    }

    return std::clamp(
        requested_target_celsius,
        envelope.minimum_zone_temperature_celsius,
        envelope.maximum_zone_temperature_celsius
    );
}

inline double clamp_relative_humidity_target(
    const ComfortEnvelope& envelope,
    double requested_target_fraction
) {
    if (!is_valid_envelope(envelope) || !std::isfinite(requested_target_fraction)) {
        return 0.5;
    }

    return std::clamp(
        requested_target_fraction,
        envelope.minimum_relative_humidity_fraction,
        envelope.maximum_relative_humidity_fraction
    );
}

} // namespace augmented_hub::gathering_hub

#endif
