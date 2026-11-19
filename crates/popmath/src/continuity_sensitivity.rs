use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::continuity::{
    assess_continuity_expression, CapabilityExpression, CapabilityRequirement,
    CapabilityWindow, ContinuityAssessment, EvidenceStatus,
};
use crate::error::PopmathError;
use crate::time::TimeWindow;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContinuitySensitivityParameter {
    MinimumAvailability,
    MaximumGapSeconds,
    RequiredEvidence,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ContinuitySensitivityInput {
    pub minimum_availability_step: UnitInterval,
    pub maximum_gap_seconds_step: NonNegativeF64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ContinuitySensitivityResult {
    pub parameter: ContinuitySensitivityParameter,
    pub baseline_continuity_ratio: UnitInterval,
    pub lower_continuity_ratio: UnitInterval,
    pub upper_continuity_ratio: UnitInterval,
    pub derivative_estimate: f64,
    pub baseline_evidence: EvidenceStatus,
    pub lower_evidence: EvidenceStatus,
    pub upper_evidence: EvidenceStatus,
}

pub fn calculate_requirement_sensitivity(
    requested_window: TimeWindow,
    requirement: CapabilityRequirement,
    windows: &[CapabilityWindow],
    input: ContinuitySensitivityInput,
) -> Result<Vec<ContinuitySensitivityResult>, PopmathError> {
    if input.minimum_availability_step.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "minimum availability sensitivity step must be greater than zero",
        ));
    }

    if input.maximum_gap_seconds_step.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "maximum gap sensitivity step must be greater than zero",
        ));
    }

    let baseline = assess_requirement(
        requested_window,
        requirement,
        windows,
    )?;

    let availability_result = calculate_availability_sensitivity(
        requested_window,
        requirement,
        windows,
        baseline.availability_ratio,
        input.minimum_availability_step,
    )?;

    let gap_result = calculate_gap_sensitivity(
        requested_window,
        requirement,
        windows,
        baseline.availability_ratio,
        input.maximum_gap_seconds_step,
    )?;

    let evidence_result = calculate_evidence_sensitivity(
        requested_window,
        requirement,
        windows,
        baseline.availability_ratio,
    )?;

    Ok(vec![
        availability_result,
        gap_result,
        evidence_result,
    ])
}

fn calculate_availability_sensitivity(
    requested_window: TimeWindow,
    requirement: CapabilityRequirement,
    windows: &[CapabilityWindow],
    baseline_ratio: UnitInterval,
    step: UnitInterval,
) -> Result<ContinuitySensitivityResult, PopmathError> {
    let lower_requirement = CapabilityRequirement {
        minimum_availability: UnitInterval::new(
            (requirement.minimum_availability.value() - step.value())
                .max(0.0),
        )?,
        ..requirement
    };

    let upper_requirement = CapabilityRequirement {
        minimum_availability: UnitInterval::new(
            (requirement.minimum_availability.value() + step.value())
                .min(1.0),
        )?,
        ..requirement
    };

    let lower = assess_requirement(
        requested_window,
        lower_requirement,
        windows,
    )?;

    let upper = assess_requirement(
        requested_window,
        upper_requirement,
        windows,
    )?;

    let denominator = upper_requirement.minimum_availability.value()
        - lower_requirement.minimum_availability.value();

    let derivative_estimate = if denominator > 0.0 {
        (
            upper.availability_ratio.value()
                - lower.availability_ratio.value()
        ) / denominator
    } else {
        0.0
    };

    Ok(ContinuitySensitivityResult {
        parameter: ContinuitySensitivityParameter::MinimumAvailability,
        baseline_continuity_ratio: baseline_ratio,
        lower_continuity_ratio: lower.availability_ratio,
        upper_continuity_ratio: upper.availability_ratio,
        derivative_estimate,
        baseline_evidence: requirement.required_evidence,
        lower_evidence: lower_requirement.required_evidence,
        upper_evidence: upper_requirement.required_evidence,
    })
}

fn calculate_gap_sensitivity(
    requested_window: TimeWindow,
    requirement: CapabilityRequirement,
    windows: &[CapabilityWindow],
    baseline_ratio: UnitInterval,
    step: NonNegativeF64,
) -> Result<ContinuitySensitivityResult, PopmathError> {
    let lower_requirement = CapabilityRequirement {
        maximum_gap_seconds: NonNegativeF64::new(
            (requirement.maximum_gap_seconds.value() - step.value())
                .max(0.0),
        )?,
        ..requirement
    };

    let upper_requirement = CapabilityRequirement {
        maximum_gap_seconds: NonNegativeF64::new(
            requirement.maximum_gap_seconds.value() + step.value(),
        )?,
        ..requirement
    };

    let lower = assess_requirement(
        requested_window,
        lower_requirement,
        windows,
    )?;

    let upper = assess_requirement(
        requested_window,
        upper_requirement,
        windows,
    )?;

    let denominator = upper_requirement.maximum_gap_seconds.value()
        - lower_requirement.maximum_gap_seconds.value();

    let derivative_estimate = if denominator > 0.0 {
        (
            upper.availability_ratio.value()
                - lower.availability_ratio.value()
        ) / denominator
    } else {
        0.0
    };

    Ok(ContinuitySensitivityResult {
        parameter: ContinuitySensitivityParameter::MaximumGapSeconds,
        baseline_continuity_ratio: baseline_ratio,
        lower_continuity_ratio: lower.availability_ratio,
        upper_continuity_ratio: upper.availability_ratio,
        derivative_estimate,
        baseline_evidence: requirement.required_evidence,
        lower_evidence: lower_requirement.required_evidence,
        upper_evidence: upper_requirement.required_evidence,
    })
}

fn calculate_evidence_sensitivity(
    requested_window: TimeWindow,
    requirement: CapabilityRequirement,
    windows: &[CapabilityWindow],
    baseline_ratio: UnitInterval,
) -> Result<ContinuitySensitivityResult, PopmathError> {
    let lower_evidence = less_strict_evidence(requirement.required_evidence);
    let upper_evidence = stricter_evidence(requirement.required_evidence);

    let lower_requirement = CapabilityRequirement {
        required_evidence: lower_evidence,
        ..requirement
    };

    let upper_requirement = CapabilityRequirement {
        required_evidence: upper_evidence,
        ..requirement
    };

    let lower = assess_requirement(
        requested_window,
        lower_requirement,
        windows,
    )?;

    let upper = assess_requirement(
        requested_window,
        upper_requirement,
        windows,
    )?;

    let derivative_estimate =
        upper.availability_ratio.value() - lower.availability_ratio.value();

    Ok(ContinuitySensitivityResult {
        parameter: ContinuitySensitivityParameter::RequiredEvidence,
        baseline_continuity_ratio: baseline_ratio,
        lower_continuity_ratio: lower.availability_ratio,
        upper_continuity_ratio: upper.availability_ratio,
        derivative_estimate,
        baseline_evidence: requirement.required_evidence,
        lower_evidence,
        upper_evidence,
    })
}

fn assess_requirement(
    requested_window: TimeWindow,
    requirement: CapabilityRequirement,
    windows: &[CapabilityWindow],
) -> Result<ContinuityAssessment, PopmathError> {
    let expression = CapabilityExpression::requirement(requirement);

    assess_continuity_expression(
        requested_window,
        &expression,
        windows,
    )
}

fn less_strict_evidence(value: EvidenceStatus) -> EvidenceStatus {
    match value {
        EvidenceStatus::Unknown => EvidenceStatus::Unknown,
        EvidenceStatus::Assumed => EvidenceStatus::Unknown,
        EvidenceStatus::Verified => EvidenceStatus::Assumed,
    }
}

fn stricter_evidence(value: EvidenceStatus) -> EvidenceStatus {
    match value {
        EvidenceStatus::Unknown => EvidenceStatus::Assumed,
        EvidenceStatus::Assumed => EvidenceStatus::Verified,
        EvidenceStatus::Verified => EvidenceStatus::Verified,
    }
}
