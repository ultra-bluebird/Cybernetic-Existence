#include <algorithm>
#include <array>
#include <cstdint>
#include <optional>

namespace augmented_hub::door {

enum class DoorState : std::uint8_t {
    Closed,
    Opening,
    Open,
    Closing,
    FaultLockedOpen
};

enum class FaultCode : std::uint8_t {
    None,
    LidarUnavailable,
    UltrasonicUnavailable,
    PressureMatActive,
    SensorDisagreement,
    MotorFeedbackMismatch,
    CommunicationTimeout
};

struct LidarObservation {
    bool healthy;
    bool protected_zone_occupied;
    bool travel_zone_occupied;
    bool doorway_clear;
    float nearest_range_m;
};

struct UltrasonicObservation {
    std::array<bool, 6> healthy;
    std::array<float, 6> range_m;
};

struct PressureMatObservation {
    bool healthy;
    bool occupied;
};

struct MotorObservation {
    bool healthy;
    bool moving;
    bool position_closed;
    bool position_open;
    bool obstruction_detected;
};

struct DoorCommand {
    DoorState state;
    FaultCode fault;
    float speed_ratio;
    float opening_width_ratio;
    bool motor_enable;
    bool request_reverse;
    bool audible_alert;
};

class AutomaticDoorFusionController {
public:
    DoorCommand step(
        const LidarObservation& lidar,
        const UltrasonicObservation& ultrasonic,
        const PressureMatObservation& pressure_mat,
        const MotorObservation& motor,
        bool accessibility_open_request,
        std::uint32_t now_ms
    ) {
        update_watchdog(now_ms);

        const bool ultrasonic_healthy = count_healthy(ultrasonic.healthy) >= 4;
        const bool ultrasonic_close_obstruction = any_range_below(ultrasonic.range_m, ultrasonic.healthy, 0.45F);
        const bool ultrasonic_approach = any_range_below(ultrasonic.range_m, ultrasonic.healthy, 1.20F);

        const bool lidar_close_obstruction =
            lidar.healthy && (lidar.protected_zone_occupied || lidar.travel_zone_occupied);

        const bool safety_obstruction =
            pressure_mat.occupied ||
            motor.obstruction_detected ||
            lidar_close_obstruction ||
            ultrasonic_close_obstruction;

        const bool approach_detected =
            accessibility_open_request ||
            (lidar.healthy && lidar.protected_zone_occupied) ||
            ultrasonic_approach;

        const bool sensor_disagreement =
            lidar.healthy &&
            ultrasonic_healthy &&
            lidar.doorway_clear &&
            ultrasonic_close_obstruction;

        const bool heartbeat_expired = now_ms - last_heartbeat_ms_ > communication_timeout_ms_;

        if (
            !motor.healthy ||
            heartbeat_expired ||
            !pressure_mat.healthy ||
            sensor_disagreement
        ) {
            state_ = DoorState::FaultLockedOpen;
            fault_ = !motor.healthy ? FaultCode::MotorFeedbackMismatch :
                     heartbeat_expired ? FaultCode::CommunicationTimeout :
                     !pressure_mat.healthy ? FaultCode::PressureMatActive :
                     FaultCode::SensorDisagreement;
        }

        if (state_ == DoorState::FaultLockedOpen) {
            return {
                .state = state_,
                .fault = fault_,
                .speed_ratio = 0.0F,
                .opening_width_ratio = 1.0F,
                .motor_enable = false,
                .request_reverse = false,
                .audible_alert = true
            };
        }

        if (!lidar.healthy && !ultrasonic_healthy) {
            state_ = DoorState::FaultLockedOpen;
            fault_ = FaultCode::LidarUnavailable;
            return {
                .state = state_,
                .fault = fault_,
                .speed_ratio = 0.0F,
                .opening_width_ratio = 1.0F,
                .motor_enable = false,
                .request_reverse = false,
                .audible_alert = true
            };
        }

        if (safety_obstruction && state_ == DoorState::Closing) {
            state_ = DoorState::Opening;
            fault_ = pressure_mat.occupied ? FaultCode::PressureMatActive : FaultCode::None;
            return {
                .state = state_,
                .fault = fault_,
                .speed_ratio = 0.25F,
                .opening_width_ratio = 1.0F,
                .motor_enable = true,
                .request_reverse = true,
                .audible_alert = true
            };
        }

        switch (state_) {
            case DoorState::Closed:
                if (approach_detected) {
                    state_ = DoorState::Opening;
                }
                break;

            case DoorState::Opening:
                if (motor.position_open) {
                    state_ = DoorState::Open;
                    open_since_ms_ = now_ms;
                }
                break;

            case DoorState::Open:
                if (!safety_obstruction && now_ms - open_since_ms_ >= hold_open_ms_) {
                    state_ = DoorState::Closing;
                }
                break;

            case DoorState::Closing:
                if (motor.position_closed) {
                    state_ = DoorState::Closed;
                }
                break;

            case DoorState::FaultLockedOpen:
                break;
        }

        const float nearest_obstacle_m = nearest_valid_range(lidar, ultrasonic);
        const float speed_ratio = speed_for_state(state_, nearest_obstacle_m, safety_obstruction);
        const float width_ratio = width_for_request(accessibility_open_request, lidar, ultrasonic);

        return {
            .state = state_,
            .fault = fault_,
            .speed_ratio = speed_ratio,
            .opening_width_ratio = width_ratio,
            .motor_enable = state_ == DoorState::Opening || state_ == DoorState::Closing,
            .request_reverse = false,
            .audible_alert = state_ == DoorState::Opening || state_ == DoorState::Closing
        };
    }

    void record_heartbeat(std::uint32_t now_ms) {
        last_heartbeat_ms_ = now_ms;
    }

private:
    static constexpr std::uint32_t hold_open_ms_ = 4000;
    static constexpr std::uint32_t communication_timeout_ms_ = 1000;

    DoorState state_ = DoorState::Closed;
    FaultCode fault_ = FaultCode::None;
    std::uint32_t open_since_ms_ = 0;
    std::uint32_t last_heartbeat_ms_ = 0;

    static std::size_t count_healthy(const std::array<bool, 6>& healthy) {
        return static_cast<std::size_t>(std::count(healthy.begin(), healthy.end(), true));
    }

    static bool any_range_below(
        const std::array<float, 6>& ranges,
        const std::array<bool, 6>& healthy,
        float threshold_m
    ) {
        for (std::size_t index = 0; index < ranges.size(); ++index) {
            if (healthy[index] && ranges[index] > 0.0F && ranges[index] < threshold_m) {
                return true;
            }
        }
        return false;
    }

    static float nearest_valid_range(
        const LidarObservation& lidar,
        const UltrasonicObservation& ultrasonic
    ) {
        float nearest = lidar.healthy && lidar.nearest_range_m > 0.0F
            ? lidar.nearest_range_m
            : 5.0F;

        for (std::size_t index = 0; index < ultrasonic.range_m.size(); ++index) {
            if (ultrasonic.healthy[index] && ultrasonic.range_m[index] > 0.0F) {
                nearest = std::min(nearest, ultrasonic.range_m[index]);
            }
        }

        return nearest;
    }

    static float speed_for_state(DoorState state, float nearest_obstacle_m, bool safety_obstruction) {
        if (state != DoorState::Opening && state != DoorState::Closing) {
            return 0.0F;
        }
        if (safety_obstruction || nearest_obstacle_m < 0.45F) {
            return 0.20F;
        }
        if (nearest_obstacle_m < 1.20F) {
            return 0.45F;
        }
        return 0.75F;
    }

    static float width_for_request(
        bool accessibility_open_request,
        const LidarObservation& lidar,
        const UltrasonicObservation& ultrasonic
    ) {
        const bool multi_person_approach =
            lidar.healthy && lidar.protected_zone_occupied &&
            any_range_below(ultrasonic.range_m, ultrasonic.healthy, 1.20F);

        if (accessibility_open_request || multi_person_approach) {
            return 1.0F;
        }
        return 0.70F;
    }

    void update_watchdog(std::uint32_t now_ms) {
        if (last_heartbeat_ms_ == 0U) {
            last_heartbeat_ms_ = now_ms;
        }
    }
};

}
