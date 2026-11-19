#include "door_controller.hpp"

namespace augmented_hub::door {

DoorController::DoorController(ControllerConfig config) noexcept
    : config_(config) {}

Command DoorController::update(const SensorFrame& frame) noexcept {
    if (!safety_healthy(frame)) {
        state_ = DoorState::FaultSafe;
        return Command::EnterFaultSafe;
    }

    if (frame.emergency_egress || frame.manual_activation) {
        state_ = DoorState::Opening;
        return Command::Open;
    }

    if (obstruction_present(frame)) {
        state_ = DoorState::Open;
        return Command::ReverseToOpen;
    }

    switch (state_) {
        case DoorState::Closed:
            if (activation_healthy(frame) && frame.approach_detected) {
                state_ = DoorState::Opening;
                return Command::Open;
            }
            return Command::Hold;

        case DoorState::Opening:
            if (frame.door_is_open) {
                state_ = DoorState::Open;
            }
            return Command::Hold;

        case DoorState::Open:
            if (frame.minimum_open_time_elapsed && !frame.occupancy_detected) {
                state_ = DoorState::Closing;
                return Command::Close;
            }
            return Command::Hold;

        case DoorState::Closing:
            if (frame.door_is_closed) {
                state_ = DoorState::Closed;
                return Command::Hold;
            }
            return Command::Hold;

        case DoorState::FaultSafe:
            if (config_.hold_open_on_presence_sensor_fault) {
                return Command::Hold;
            }
            return Command::EnterFaultSafe;
    }

    state_ = DoorState::FaultSafe;
    return Command::EnterFaultSafe;
}

DoorState DoorController::state() const noexcept {
    return state_;
}

bool DoorController::activation_healthy(const SensorFrame& frame) const noexcept {
    return frame.activation_sensor_healthy;
}

bool DoorController::safety_healthy(const SensorFrame& frame) const noexcept {
    if (!frame.presence_sensor_healthy) {
        return false;
    }

    if (config_.require_operator_feedback && !frame.operator_feedback_healthy) {
        return false;
    }

    return true;
}

bool DoorController::obstruction_present(const SensorFrame& frame) const noexcept {
    return frame.occupancy_detected || frame.obstruction_detected;
}

}  // namespace augmented_hub::door
