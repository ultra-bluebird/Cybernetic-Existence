#ifndef AUGMENTED_HUB_ADAPTIVE_STREET_LIGHTING_CONTROLLER_HPP
#define AUGMENTED_HUB_ADAPTIVE_STREET_LIGHTING_CONTROLLER_HPP

#include <algorithm>
#include <cstdint>
#include <stdexcept>

namespace augmented_hub::adaptive_street_lighting {

enum class PresenceState {
    NoActivityConfirmed,
    ActivityLikely,
    SensorUncertain,
    SensorFault,
};

struct SensorReading {
    bool pir_event{};
    bool ultrasonic_event{};
    double pir_quality{};
    double ultrasonic_quality{};
    bool weather_interference{};
    bool sensor_fault{};

    void validate() const {
        if (pir_quality < 0.0 || pir_quality > 1.0) {
            throw std::invalid_argument("pir_quality must be in the range [0, 1].");
        }

        if (ultrasonic_quality < 0.0 || ultrasonic_quality > 1.0) {
            throw std::invalid_argument(
                "ultrasonic_quality must be in the range [0, 1]."
            );
        }
    }
};

struct LightingPolicy {
    double safe_baseline_power_w{};
    double boost_power_w{};
    double max_power_w{};
    double activity_threshold{0.6};
    std::uint32_t hold_seconds{30};
    std::uint32_t confirmation_seconds{2};

    void validate() const {
        if (safe_baseline_power_w < 0.0) {
            throw std::invalid_argument(
                "safe_baseline_power_w must be non-negative."
            );
        }

        if (boost_power_w < safe_baseline_power_w) {
            throw std::invalid_argument(
                "boost_power_w must not be lower than safe_baseline_power_w."
            );
        }

        if (max_power_w < boost_power_w) {
            throw std::invalid_argument(
                "max_power_w must not be lower than boost_power_w."
            );
        }

        if (activity_threshold < 0.0 || activity_threshold > 1.0) {
            throw std::invalid_argument(
                "activity_threshold must be in the range [0, 1]."
            );
        }

        if (hold_seconds == 0U || confirmation_seconds == 0U) {
            throw std::invalid_argument(
                "hold_seconds and confirmation_seconds must be positive."
            );
        }
    }
};

struct LightingDecision {
    PresenceState presence_state{};
    double target_power_w{};
    bool uses_safe_baseline{};
};

class NonTrackingLightingController {
public:
    explicit NonTrackingLightingController(LightingPolicy policy)
        : policy_(policy) {
        policy_.validate();
    }

    [[nodiscard]] LightingDecision decide(
        const SensorReading& reading,
        std::uint32_t consecutive_active_seconds
    ) const {
        reading.validate();

        if (reading.sensor_fault) {
            return safe_baseline(PresenceState::SensorFault);
        }

        if (reading.weather_interference &&
            !reading.pir_event &&
            reading.ultrasonic_event) {
            return safe_baseline(PresenceState::SensorUncertain);
        }

        const double activity_score = fused_activity_score(reading);

        const bool both_sensors_agree =
            reading.pir_event && reading.ultrasonic_event;

        const bool sustained_single_sensor_activity =
            consecutive_active_seconds >= policy_.confirmation_seconds &&
            activity_score >= policy_.activity_threshold;

        if (both_sensors_agree || sustained_single_sensor_activity) {
            return LightingDecision{
                .presence_state = PresenceState::ActivityLikely,
                .target_power_w = policy_.boost_power_w,
                .uses_safe_baseline = false,
            };
        }

        return safe_baseline(PresenceState::NoActivityConfirmed);
    }

    [[nodiscard]] double fused_activity_score(
        const SensorReading& reading
    ) const {
        reading.validate();

        const double pir_component =
            reading.pir_event ? reading.pir_quality : 0.0;
        const double ultrasonic_component =
            reading.ultrasonic_event ? reading.ultrasonic_quality : 0.0;

        return std::clamp(
            0.5 * pir_component + 0.5 * ultrasonic_component,
            0.0,
            1.0
        );
    }

private:
    [[nodiscard]] LightingDecision safe_baseline(
        PresenceState state
    ) const {
        return LightingDecision{
            .presence_state = state,
            .target_power_w = policy_.safe_baseline_power_w,
            .uses_safe_baseline = true,
        };
    }

    LightingPolicy policy_;
};

}  // namespace augmented_hub::adaptive_street_lighting

#endif
