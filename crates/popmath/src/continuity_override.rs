use alloc::string::String;

use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::continuity::{
    assess_continuity_expression, CapabilityExpression,
    CapabilityRequirement, CapabilityWindow, ContinuityAssessment,
};
use crate::error::PopmathError;
use crate::time::{TimeWindow, UtcTimestamp};

#[derive(Debug, Clone, PartialEq)]
pub struct ContinuityOverride {
    pub override_name: String,
    pub reason: String,
    pub review_reference: String,
    pub active_window: TimeWindow,
    pub relaxed_minimum_availability: UnitInterval,
    pub relaxed_maximum_gap_seconds: NonNegativeF64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EffectiveCapabilityRequirement {
    pub normal: CapabilityRequirement,
    pub effective: CapabilityRequirement,
    pub relaxed: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ContinuityOverrideAssessment {
    pub normal_assessment: ContinuityAssessment,
    pub effective_assessment: ContinuityAssessment,
    pub effective_requirement: EffectiveCapabilityRequirement,
    pub override_active: bool,
    pub explanation: String,
}

pub fn effective_requirement_at(
    normal: CapabilityRequirement,
    override_rule: &ContinuityOverride,
    timestamp: UtcTimestamp,
) -> Result<EffectiveCapabilityRequirement, PopmathError> {
    validate_override(normal, override_rule)?;

    let override_active = timestamp >= override_rule.active_window.start()
        && timestamp < override_rule.active_window.end();

    let effective = if override_active {
        CapabilityRequirement {
            minimum_availability: override_rule.relaxed_minimum_availability,
            maximum_gap_seconds: override_rule.relaxed_maximum_gap_seconds,
            ..normal
        }
    } else {
        normal
    };

    Ok(EffectiveCapabilityRequirement {
        normal,
        effective,
        relaxed: override_active,
    })
}

pub fn assess_with_continuity_override(
    requested_window: TimeWindow,
    normal: CapabilityRequirement,
    override_rule: &ContinuityOverride,
    windows: &[CapabilityWindow],
) -> Result<ContinuityOverrideAssessment, PopmathError> {
    validate_override(normal, override_rule)?;

    let normal_assessment = assess_continuity_expression(
        requested_window,
        &CapabilityExpression::requirement(normal),
        windows,
    )?;

    let overlap = intersect_windows(
        requested_window,
        override_rule.active_window,
    );

    let effective_assessment = if let Some(override_window) = overlap {
        assess_windowed_override(
            requested_window,
            override_window,
            normal,
            override_rule,
            windows,
        )?
    } else {
        normal_assessment.clone()
    };

    let override_active = overlap.is_some();

    Ok(ContinuityOverrideAssessment {
        normal_assessment,
        effective_assessment,
        effective_requirement: EffectiveCapabilityRequirement {
            normal,
            effective: CapabilityRequirement {
                minimum_availability: override_rule.relaxed_minimum_availability,
                maximum_gap_seconds: override_rule.relaxed_maximum_gap_seconds,
                ..normal
            },
            relaxed: override_active,
        },
        override_active,
        explanation: if override_active {
            String::from(
                "A time-bounded reviewed override was applied only within its declared active window; normal continuity requirements remain active outside that window.",
            )
        } else {
            String::from(
                "No override overlaps the requested continuity window; normal requirements remain active.",
            )
        },
    })
}

fn assess_windowed_override(
    requested_window: TimeWindow,
    override_window: TimeWindow,
    normal: CapabilityRequirement,
    override_rule: &ContinuityOverride,
    windows: &[CapabilityWindow],
) -> Result<ContinuityAssessment, PopmathError> {
    let before = TimeWindow::new(
        requested_window.start(),
        override_window.start(),
    )
    .ok();

    let after = TimeWindow::new(
        override_window.end(),
        requested_window.end(),
    )
    .ok();

    let mut assessments = alloc::vec::Vec::new();

    if let Some(window) = before {
        assessments.push((
            window,
            assess_continuity_expression(
                window,
                &CapabilityExpression::requirement(normal),
                windows,
            )?,
        ));
    }

    assessments.push((
        override_window,
        assess_continuity_expression(
            override_window,
            &CapabilityExpression::requirement(
                CapabilityRequirement {
                    minimum_availability: override_rule.relaxed_minimum_availability,
                    maximum_gap_seconds: override_rule.relaxed_maximum_gap_seconds,
                    ..normal
                },
            ),
            windows,
        )?,
    ));

    if let Some(window) = after {
        assessments.push((
            window,
            assess_continuity_expression(
                window,
                &CapabilityExpression::requirement(normal),
                windows,
            )?,
        ));
    }

    combine_window_assessments(requested_window, &assessments)
}

fn combine_window_assessments(
    requested_window: TimeWindow,
    assessments: &[(TimeWindow, ContinuityAssessment)],
) -> Result<ContinuityAssessment, PopmathError> {
    let total_seconds = duration_seconds(requested_window)?;
    let mut available_seconds = 0.0;
    let mut verified_seconds = 0.0;
    let mut unmet_seconds = 0.0;
    let mut longest_gap_seconds = 0.0;

    for (window, assessment) in assessments {
        let window_seconds = duration_seconds(*window)?;

        available_seconds +=
            assessment.availability_ratio.value() * window_seconds;

        verified_seconds +=
            assessment.verification_ratio.value() * window_seconds;

        unmet_seconds += assessment.unmet_seconds.value();
        longest_gap_seconds =
            longest_gap_seconds.max(assessment.longest_gap_seconds.value());
    }

    let availability_ratio =
        UnitInterval::new((available_seconds / total_seconds).clamp(0.0, 1.0))?;

    let verification_ratio =
        UnitInterval::new((verified_seconds / total_seconds).clamp(0.0, 1.0))?;

    let overall_status = if availability_ratio.value() < 1.0 {
        crate::continuity::ContinuityStatus::Unmet
    } else if verification_ratio.value() < 1.0 {
        crate::continuity::ContinuityStatus::ConditionallyMet
    } else {
        crate::continuity::ContinuityStatus::Met
    };

    Ok(ContinuityAssessment {
        availability_ratio,
        verification_ratio,
        unmet_seconds: NonNegativeF64::new(unmet_seconds)?,
        longest_gap_seconds: NonNegativeF64::new(longest_gap_seconds)?,
        overall_status,
        explanation: String::from(
            "Continuity was evaluated using normal requirements outside the override window and the reviewed temporary requirement inside the override window.",
        ),
    })
}

fn validate_override(
    normal: CapabilityRequirement,
    override_rule: &ContinuityOverride,
) -> Result<(), PopmathError> {
    if override_rule.override_name.trim().is_empty() {
        return Err(PopmathError::InvalidInput(
            "override name must be non-empty",
        ));
    }

    if override_rule.reason.trim().is_empty() {
        return Err(PopmathError::InvalidInput(
            "override reason must be non-empty",
        ));
    }

    if override_rule.review_reference.trim().is_empty() {
        return Err(PopmathError::InvalidInput(
            "override review reference must be non-empty",
        ));
    }

    if override_rule.relaxed_minimum_availability.value()
        > normal.minimum_availability.value()
    {
        return Err(PopmathError::InvalidInput(
            "override minimum availability must not be stricter than the normal requirement",
        ));
    }

    if override_rule.relaxed_maximum_gap_seconds.value()
        < normal.maximum_gap_seconds.value()
    {
        return Err(PopmathError::InvalidInput(
            "override maximum gap must not be shorter than the normal requirement",
        ));
    }

    Ok(())
}

fn intersect_windows(left: TimeWindow, right: TimeWindow) -> Option<TimeWindow> {
    let start = left.start().max(right.start());
    let end = left.end().min(right.end());

    if start >= end {
        return None;
    }

    TimeWindow::new(start, end).ok()
}

fn duration_seconds(window: TimeWindow) -> Result<f64, PopmathError> {
    let duration = window
        .end()
        .seconds_since_epoch()
        .checked_sub(window.start().seconds_since_epoch())
        .ok_or(PopmathError::InvalidTimeWindow)?;

    NonNegativeF64::new(duration as f64).map(|value| value.value())
}
