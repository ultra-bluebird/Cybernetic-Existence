#ifndef AUGMENTED_HUB_NON_BIOMETRIC_DOOR_CONTROLLER_HPP
#define AUGMENTED_HUB_NON_BIOMETRIC_DOOR_CONTROLLER_HPP

#include <cstdint>

namespace augmented_hub::door {

enum class DoorState : std::uint8_t {
    Closed,
    Opening,
    Open,
    Closing,
    FaultSafe
};

enum class Command : std::uint8_t {
    Hold,
    Open,
    Close,
    ReverseToOpen,
    EnterFaultSafe
};

struct SensorFrame {
    bool manual_activation;
    bool emergency_egress;
    bool approach_detected;
    bool occupancy_detected;
    bool obstruction_detected;
    bool activation_sensor_healthy;
    bool presence_sensor_healthy;
    bool operator_feedback_healthy;
    bool door_is_open;
    bool door_is_closed;
    bool minimum_open_time_elapsed;
};

struct ControllerConfig {
    bool hold_open_on_presence_sensor_fault;
    bool require_operator_feedback;
};

class DoorController final {
public:
    explicit DoorController(ControllerConfig config) noexcept;

    [[nodiscard]] Command update(const SensorFrame& frame) noexcept;

    [[nodiscard]] DoorState state() const noexcept;

private:
    [[nodiscard]] bool activation_healthy(const SensorFrame& frame) const noexcept;

    [[nodiscard]] bool safety_healthy(const SensorFrame& frame) const noexcept;

    [[nodiscard]] bool obstruction_present(const SensorFrame& frame) const noexcept;

    ControllerConfig config_;
    DoorState state_{DoorState::Closed};
};

}  // namespace augmented_hub::door

#endif
