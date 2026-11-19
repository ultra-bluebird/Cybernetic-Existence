#include <algorithm>
#include <cmath>
#include <cstdint>

namespace augmented_hub::corridor_bot {

struct SafetyInputs {
    bool human_in_protected_zone;
    bool emergency_access_active;
    bool accessibility_path_blocked;
    bool reservation_present;
    bool reservation_expired;
    bool emergency_stop_active;
    float requested_speed_mps;
    float maximum_speed_mps;
    float maximum_acceleration_mps2;
    float stopping_distance_m;
    float clear_distance_m;
};

struct SafetyOutput {
    float permitted_speed_mps;
    bool stop_required;
    bool reservation_required;
};

SafetyOutput enforce_velocity_safety(const SafetyInputs& input) {
    const bool protected_access =
        input.human_in_protected_zone ||
        input.emergency_access_active ||
        input.accessibility_path_blocked ||
        input.emergency_stop_active;

    const bool valid_motion_limits =
        std::isfinite(input.requested_speed_mps) &&
        std::isfinite(input.maximum_speed_mps) &&
        std::isfinite(input.maximum_acceleration_mps2) &&
        std::isfinite(input.stopping_distance_m) &&
        std::isfinite(input.clear_distance_m) &&
        input.maximum_speed_mps >= 0.0F &&
        input.maximum_acceleration_mps2 > 0.0F &&
        input.stopping_distance_m >= 0.0F &&
        input.clear_distance_m >= 0.0F;

    if (
        protected_access ||
        !input.reservation_present ||
        input.reservation_expired ||
        !valid_motion_limits ||
        input.clear_distance_m < input.stopping_distance_m
    ) {
        return {
            .permitted_speed_mps = 0.0F,
            .stop_required = true,
            .reservation_required = true
        };
    }

    return {
        .permitted_speed_mps = std::clamp(
            input.requested_speed_mps,
            0.0F,
            input.maximum_speed_mps
        ),
        .stop_required = false,
        .reservation_required = true
    };
}

}
