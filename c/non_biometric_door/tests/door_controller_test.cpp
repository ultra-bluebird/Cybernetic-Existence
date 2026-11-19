#include "door_controller.hpp"

#include <cassert>

using augmented_hub::door::Command;
using augmented_hub::door::ControllerConfig;
using augmented_hub::door::DoorController;
using augmented_hub::door::DoorState;
using augmented_hub::door::SensorFrame;

namespace {

SensorFrame safe_frame() {
    return SensorFrame{
        .manual_activation = false,
        .emergency_egress = false,
        .approach_detected = false,
        .occupancy_detected = false,
        .obstruction_detected = false,
        .activation_sensor_healthy = true,
        .presence_sensor_healthy = true,
        .operator_feedback_healthy = true,
        .door_is_open = false,
        .door_is_closed = true,
        .minimum_open_time_elapsed = false,
    };
}

}  // namespace

int main() {
    DoorController controller(
        ControllerConfig{
            .hold_open_on_presence_sensor_fault = true,
            .require_operator_feedback = true,
        }
    );

    SensorFrame frame = safe_frame();
    frame.approach_detected = true;

    assert(controller.update(frame) == Command::Open);
    assert(controller.state() == DoorState::Opening);

    frame.approach_detected = false;
    frame.door_is_open = true;

    assert(controller.update(frame) == Command::Hold);
    assert(controller.state() == DoorState::Open);

    frame.door_is_open = false;
    frame.occupancy_detected = true;
    frame.minimum_open_time_elapsed = true;

    assert(controller.update(frame) == Command::ReverseToOpen);
    assert(controller.state() == DoorState::Open);

    frame.occupancy_detected = false;
    frame.presence_sensor_healthy = false;

    assert(controller.update(frame) == Command::EnterFaultSafe);
    assert(controller.state() == DoorState::FaultSafe);

    return 0;
}
