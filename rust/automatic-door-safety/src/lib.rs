#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DoorCommand {
    HoldOpen,
    Reopen,
    PermitClose,
    EnterSafeState,
    RequestMaintenance,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DoorSafetyInputs {
    pub activation_active: bool,
    pub clearance_confirmed: bool,
    pub obstruction_detected: bool,
    pub primary_sensor_healthy: bool,
    pub secondary_sensor_healthy: bool,
    pub controller_self_test_passed: bool,
    pub power_state_safe_for_motion: bool,
    pub manual_accessible_fallback_available: bool,
}

pub fn select_door_command(inputs: DoorSafetyInputs) -> DoorCommand {
    let sensors_healthy =
        inputs.primary_sensor_healthy && inputs.secondary_sensor_healthy;

    let safety_system_healthy =
        sensors_healthy
        && inputs.controller_self_test_passed
        && inputs.power_state_safe_for_motion;

    if !inputs.manual_accessible_fallback_available {
        return DoorCommand::RequestMaintenance;
    }

    if !safety_system_healthy {
        return DoorCommand::EnterSafeState;
    }

    if inputs.activation_active {
        return DoorCommand::HoldOpen;
    }

    if inputs.obstruction_detected {
        return DoorCommand::Reopen;
    }

    if !inputs.clearance_confirmed {
        return DoorCommand::HoldOpen;
    }

    DoorCommand::PermitClose
}

#[cfg(test)]
mod tests {
    use super::{select_door_command, DoorCommand, DoorSafetyInputs};

    fn safe_inputs() -> DoorSafetyInputs {
        DoorSafetyInputs {
            activation_active: false,
            clearance_confirmed: true,
            obstruction_detected: false,
            primary_sensor_healthy: true,
            secondary_sensor_healthy: true,
            controller_self_test_passed: true,
            power_state_safe_for_motion: true,
            manual_accessible_fallback_available: true,
        }
    }

    #[test]
    fn permits_close_only_when_clear_and_healthy() {
        assert_eq!(
            select_door_command(safe_inputs()),
            DoorCommand::PermitClose
        );
    }

    #[test]
    fn holds_open_when_clearance_is_not_confirmed() {
        let mut inputs = safe_inputs();
        inputs.clearance_confirmed = false;

        assert_eq!(
            select_door_command(inputs),
            DoorCommand::HoldOpen
        );
    }

    #[test]
    fn reopens_when_obstruction_is_detected() {
        let mut inputs = safe_inputs();
        inputs.obstruction_detected = true;

        assert_eq!(
            select_door_command(inputs),
            DoorCommand::Reopen
        );
    }

    #[test]
    fn enters_safe_state_for_sensor_failure() {
        let mut inputs = safe_inputs();
        inputs.primary_sensor_healthy = false;

        assert_eq!(
            select_door_command(inputs),
            DoorCommand::EnterSafeState
        );
    }

    #[test]
    fn requests_maintenance_when_fallback_is_missing() {
        let mut inputs = safe_inputs();
        inputs.manual_accessible_fallback_available = false;

        assert_eq!(
            select_door_command(inputs),
            DoorCommand::RequestMaintenance
        );
    }
}
