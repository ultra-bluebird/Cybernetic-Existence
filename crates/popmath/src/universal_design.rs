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
pub enum UniversalDesignCriterion {
    AccessibleApproach,
    AccessibleEntrance,
    TactileOrientation,
    HighContrastVisualInformation,
    AudioFeedback,
    NonVisualStatusFeedback,
    ReachableControls,
    LowForceControls,
    EmergencyEgressContinuity,
    OfflineServiceFallback,
    ContinuousChargingAvailability,
    LowLatencyAssistanceConnectivity,
    ElectromagneticInterferenceCompatibility,
    EnvironmentalComfortContinuity,
    RepairAndMaintenanceContinuity,
}

#[derive(Debug, Clone, PartialEq)]
pub struct UniversalDesignRequirement {
    pub criterion: UniversalDesignCriterion,
    pub title: String,
    pub requirement: CapabilityRequirement,
}

#[derive(Debug, Clone, PartialEq)]
pub struct UniversalDesignAssessment {
    pub component_name: String,
    pub continuity: ContinuityAssessment,
    pub requirements: Vec<UniversalDesignRequirement>,
}

pub fn default_universal_design_requirements(
    required_evidence: EvidenceStatus,
) -> Result<Vec<UniversalDesignRequirement>, PopmathError> {
    let full_availability = UnitInterval::new(1.0)?;
    let no_gap = NonNegativeF64::new(0.0)?;
    let short_gap = NonNegativeF64::new(60.0)?;
    let support_gap = NonNegativeF64::new(300.0)?;

    Ok(vec![
        requirement(
            UniversalDesignCriterion::AccessibleApproach,
            "Accessible approach",
            CapabilityKind::AccessiblePath,
            full_availability,
            no_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::AccessibleEntrance,
            "Accessible entrance",
            CapabilityKind::AccessiblePath,
            full_availability,
            no_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::TactileOrientation,
            "Tactile orientation",
            CapabilityKind::EnvironmentalCompatibility,
            full_availability,
            short_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::HighContrastVisualInformation,
            "High-contrast visual information",
            CapabilityKind::EnvironmentalCompatibility,
            full_availability,
            short_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::AudioFeedback,
            "Audio feedback",
            CapabilityKind::HumanSupportAvailability,
            full_availability,
            short_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::NonVisualStatusFeedback,
            "Nonvisual status feedback",
            CapabilityKind::OfflineServiceAvailability,
            full_availability,
            short_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::ReachableControls,
            "Reachable controls",
            CapabilityKind::AccessiblePath,
            full_availability,
            no_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::LowForceControls,
            "Low-force controls",
            CapabilityKind::AccessiblePath,
            full_availability,
            no_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::EmergencyEgressContinuity,
            "Emergency egress continuity",
            CapabilityKind::AccessiblePath,
            full_availability,
            no_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::OfflineServiceFallback,
            "Offline service fallback",
            CapabilityKind::OfflineServiceAvailability,
            full_availability,
            support_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::ContinuousChargingAvailability,
            "Continuous charging availability",
            CapabilityKind::ChargingAvailability,
            full_availability,
            support_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::LowLatencyAssistanceConnectivity,
            "Low-latency assistance connectivity",
            CapabilityKind::LowLatencyConnectivity,
            full_availability,
            short_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::ElectromagneticInterferenceCompatibility,
            "Electromagnetic-interference compatibility",
            CapabilityKind::ElectromagneticInterferenceLow,
            full_availability,
            short_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::EnvironmentalComfortContinuity,
            "Environmental comfort continuity",
            CapabilityKind::EnvironmentalCompatibility,
            full_availability,
            support_gap,
            required_evidence,
        ),
        requirement(
            UniversalDesignCriterion::RepairAndMaintenanceContinuity,
            "Repair and maintenance continuity",
            CapabilityKind::HumanSupportAvailability,
            full_availability,
            support_gap,
            required_evidence,
        ),
    ])
}

pub fn assess_universal_design(
    component_name: String,
    requested_window: TimeWindow,
    requirements: Vec<UniversalDesignRequirement>,
    capability_windows: &[CapabilityWindow],
) -> Result<UniversalDesignAssessment, PopmathError> {
    if component_name.trim().is_empty() {
        return Err(PopmathError::InvalidInput(
            "component name must be non-empty",
        ));
    }

    if requirements.len() != 15 {
        return Err(PopmathError::InvalidInput(
            "a universal design assessment requires exactly fifteen criteria",
        ));
    }

    let expression = CapabilityExpression::all(
        requirements
            .iter()
            .map(|item| {
                CapabilityExpression::requirement(item.requirement)
            })
            .collect(),
    )?;

    let continuity = assess_continuity_expression(
        requested_window,
        &expression,
        capability_windows,
    )?;

    Ok(UniversalDesignAssessment {
        component_name,
        continuity,
        requirements,
    })
}

fn requirement(
    criterion: UniversalDesignCriterion,
    title: &str,
    kind: CapabilityKind,
    minimum_availability: UnitInterval,
    maximum_gap_seconds: NonNegativeF64,
    required_evidence: EvidenceStatus,
) -> UniversalDesignRequirement {
    UniversalDesignRequirement {
        criterion,
        title: String::from(title),
        requirement: CapabilityRequirement::new(
            kind,
            minimum_availability,
            maximum_gap_seconds,
            required_evidence,
        ),
    }
}
