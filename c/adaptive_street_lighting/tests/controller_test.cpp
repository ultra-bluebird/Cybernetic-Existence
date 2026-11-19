#include "../include/adaptive_street_lighting/controller.hpp"

#include <cassert>

using augmented_hub::adaptive_street_lighting::LightingPolicy;
using augmented_hub::adaptive_street_lighting::NonTrackingLightingController;
using augmented_hub::adaptive_street_lighting::PresenceState;
using augmented_hub::adaptive_street_lighting::SensorReading;

int main() {
    const LightingPolicy policy{
        .safe_baseline_power_w = 35.0,
        .boost_power_w = 80.0,
        .max_power_w = 100.0,
        .activity_threshold = 0.6,
        .hold_seconds = 30,
        .confirmation_seconds = 2,
    };

    const NonTrackingLightingController controller(policy);

    const SensorReading confirmed_activity{
        .pir_event = true,
        .ultrasonic_event = true,
        .pir_quality = 0.90,
        .ultrasonic_quality = 0.85,
        .weather_interference = false,
        .sensor_fault = false,
    };

    const auto active_decision = controller.decide(confirmed_activity, 1);

    assert(active_decision.presence_state == PresenceState::ActivityLikely);
    assert(active_decision.target_power_w == 80.0);
    assert(!active_decision.uses_safe_baseline);

    const SensorReading wind_like_interference{
        .pir_event = false,
        .ultrasonic_event = true,
        .pir_quality = 0.0,
        .ultrasonic_quality = 0.95,
        .weather_interference = true,
        .sensor_fault = false,
    };

    const auto uncertain_decision =
        controller.decide(wind_like_interference, 1);

    assert(
        uncertain_decision.presence_state ==
        PresenceState::SensorUncertain
    );
    assert(uncertain_decision.target_power_w == 35.0);
    assert(uncertain_decision.uses_safe_baseline);

    const SensorReading faulted_sensor{
        .pir_event = false,
        .ultrasonic_event = false,
        .pir_quality = 0.0,
        .ultrasonic_quality = 0.0,
        .weather_interference = false,
        .sensor_fault = true,
    };

    const auto fault_decision = controller.decide(faulted_sensor, 0);

    assert(fault_decision.presence_state == PresenceState::SensorFault);
    assert(fault_decision.target_power_w == 35.0);
    assert(fault_decision.uses_safe_baseline);

    const SensorReading sustained_pir{
        .pir_event = true,
        .ultrasonic_event = false,
        .pir_quality = 0.95,
        .ultrasonic_quality = 0.0,
        .weather_interference = false,
        .sensor_fault = false,
    };

    const auto sustained_decision = controller.decide(sustained_pir, 3);

    assert(sustained_decision.presence_state == PresenceState::NoActivityConfirmed);

    return 0;
}
