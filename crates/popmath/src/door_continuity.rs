use alloc::string::String;
use alloc::vec;
use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::continuity::{
    assess_continuity_expression, CapabilityExpression, CapabilityKind,
    CapabilityRequirement, CapabilityWindow, ContinuityAssessment, EvidenceStatus,
};
use crate::error::PopmathError;
use crate::time::TimeWindow;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DoorFailureMode {
    ControlPowerLoss,
    ElectromagneticInterferenceReset,
    PresenceSensorUnavailable,
    ObstructionDetectionFailure,
    ActuatorMotorUnavailable,
    ManualReleaseUnavailable,
    NetworkControlDelay,
    AccessControlInterfaceUnavailable,
    EnvironmentalInterference,
    MaintenanceOutageExceeded,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DoorFailureModeRequirement {
    pub failure_mode: DoorFailureMode,
    pub title: String,
    pub requirement: CapabilityRequirement,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DoorContinuityAssessment {
    pub door_name: String,
    pub annual_window: TimeWindow,
    pub continuity: ContinuityAssessment,
    pub requirements: Vec<DoorFailureModeRequirement>,
}

pub fn default_door_requirements(
    required_evidence: EvidenceStatus,
) -> Result<Vec<DoorFailureModeRequirement>, PopmathError> {
    let full_availability = UnitInterval::new(1.0)?;
    let no_gap = NonNegativeF64::new(0.0)?;
    let short_gap = NonNegativeF64::new(60.0)?;
    let maintenance_gap = NonNegativeF64::new(300.0)?;

    Ok(vec![
        requirement(
            DoorFailureMode::ControlPowerLoss,
            "Control power continuity",
            CapabilityKind::ContinuousPower,
            full_availability,
            no_gap,
            required_evidence,
        ),
        requirement(
            DoorFailureMode::ElectromagneticInterferenceReset,
            "Low electromagnetic interference",
            CapabilityKind::ElectromagneticInterferenceLow,
            full_availability,
            short_gap,
            required_evidence,
        ),
        requirement(
            DoorFailureMode::PresenceSensorUnavailable,
            "Presence sensing or local assistance",
            CapabilityKind::HumanSupportAvailability,
            full_availability,
            short_gap,
            required_evidence,
        ),
        requirement(
            DoorFailureMode::ObstructionDetectionFailure,
            "Verified accessible passage",
            CapabilityKind::AccessiblePath,
            full_availability,
            no_gap,
            required_evidence,
        ),
        requirement(
            DoorFailureMode::ActuatorMotorUnavailable,
            "Actuator assistance continuity",
            CapabilityKind::HumanSupportAvailability,
            full_availability,
            maintenance_gap,
            required_evidence,
        ),
        requirement(
            DoorFailureMode::ManualReleaseUnavailable,
            "Manual release or local fallback",
            CapabilityKind::OfflineServiceAvailability,
            full_availability,
            no_gap,
            required_evidence,
        ),
        requirement(
            DoorFailureMode::NetworkControlDelay,
            "Low-latency local control path",
            CapabilityKind::LowLatencyConnectivity,
            full_availability,
            short_gap,
            required_evidence,
        ),
        requirement(
            DoorFailureMode::AccessControlInterfaceUnavailable,
            "Local access fallback",
            CapabilityKind::OfflineServiceAvailability,
            full_availability,
            short_gap,
            required_evidence,
        ),
        requirement(
            DoorFailureMode::EnvironmentalInterference,
            "Environmental operating compatibility",
            CapabilityKind::EnvironmentalCompatibility,
            full_availability,
            maintenance_gap,
            required_evidence,
        ),
        requirement(
            DoorFailureMode::MaintenanceOutageExceeded,
            "Maintenance support continuity",
            CapabilityKind::HumanSupportAvailability,
            full_availability,
            maintenance_gap,
            required_evidence,
        ),
    ])
}

pub fn assess_automatic_door_continuity(
    door_name: String,
    annual_window: TimeWindow,
    requirements: Vec<DoorFailureModeRequirement>,
    capability_windows: &[CapabilityWindow],
) -> Result<DoorContinuityAssessment, PopmathError> {
    if door_name.trim().is_empty() {
        return Err(PopmathError::InvalidInput(
            "door name must be non-empty",
        ));
    }

    if requirements.len() != 10 {
        return Err(PopmathError::InvalidInput(
            "automatic door continuity assessment requires exactly ten failure-mode requirements",
        ));
    }

    let expression = CapabilityExpression::all(
        requirements
            .iter()
            .map(|item| CapabilityExpression::requirement(item.requirement))
            .collect(),
    )?;

    let continuity = assess_continuity_expression(
        annual_window,
        &expression,
        capability_windows,
    )?;

    Ok(DoorContinuityAssessment {
        door_name,
        annual_window,
        continuity,
        requirements,
    })
}

fn requirement(
    failure_mode: DoorFailureMode,
    title: &str,
    kind: CapabilityKind,
    minimum_availability: UnitInterval,
    maximum_gap_seconds: NonNegativeF64,
    required_evidence: EvidenceStatus,
) -> DoorFailureModeRequirement {
    DoorFailureModeRequirement {
        failure_mode,
        title: String::from(title),
        requirement: CapabilityRequirement::new(
            kind,
            minimum_availability,
            maximum_gap_seconds,
            required_evidence,
        ),
    }
}
