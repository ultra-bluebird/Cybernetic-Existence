use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::error::PopmathError;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SocialFeedbackInput {
    pub initial_acceptance: UnitInterval,
    pub target_acceptance: UnitInterval,
    pub kiosk_reference_count: NonNegativeF64,
    pub initial_kiosk_count: NonNegativeF64,
    pub adaptation_gain: UnitInterval,
    pub infrastructure_weight: UnitInterval,
    pub mitigation_weight: UnitInterval,
    pub investment_pacing: UnitInterval,
    pub mitigation_factor: UnitInterval,
    pub periods: u32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SocialFeedbackPeriod {
    pub period_index: u32,
    pub acceptance_factor: UnitInterval,
    pub infrastructure_factor: UnitInterval,
    pub target_factor: UnitInterval,
    pub kiosk_count: NonNegativeF64,
    pub recommended_kiosk_increase: NonNegativeF64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SocialFeedbackResult {
    pub equilibrium_acceptance: UnitInterval,
    pub converged: bool,
    pub periods: Vec<SocialFeedbackPeriod>,
}

pub fn simulate_social_acceptance_feedback(
    input: SocialFeedbackInput,
) -> Result<SocialFeedbackResult, PopmathError> {
    if input.kiosk_reference_count.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "kiosk reference count must be greater than zero",
        ));
    }

    if input.periods == 0 {
        return Err(PopmathError::InvalidInput(
            "at least one simulation period is required",
        ));
    }

    let combined_weight =
        input.infrastructure_weight.value() + input.mitigation_weight.value();

    if combined_weight > 1.0 {
        return Err(PopmathError::InvalidInput(
            "infrastructure and mitigation weights must not exceed one when combined",
        ));
    }

    let baseline_weight = 1.0 - combined_weight;
    let mut acceptance = input.initial_acceptance.value();
    let mut kiosk_count = input.initial_kiosk_count.value();
    let mut periods = Vec::with_capacity(input.periods as usize);

    for period_index in 0..input.periods {
        let infrastructure_factor =
            (kiosk_count / input.kiosk_reference_count.value()).clamp(0.0, 1.0);

        let target_factor = (
            baseline_weight * input.target_acceptance.value()
                + input.infrastructure_weight.value() * infrastructure_factor
                + input.mitigation_weight.value() * input.mitigation_factor.value()
        )
        .clamp(0.0, 1.0);

        let acceptance_gap = (input.target_acceptance.value() - acceptance).max(0.0);

        let recommended_kiosk_increase = (
            input.investment_pacing.value()
                * acceptance_gap
                * input.kiosk_reference_count.value()
        )
        .ceil();

        periods.push(SocialFeedbackPeriod {
            period_index,
            acceptance_factor: UnitInterval::new(acceptance)?,
            infrastructure_factor: UnitInterval::new(infrastructure_factor)?,
            target_factor: UnitInterval::new(target_factor)?,
            kiosk_count: NonNegativeF64::new(kiosk_count)?,
            recommended_kiosk_increase: NonNegativeF64::new(
                recommended_kiosk_increase,
            )?,
        });

        acceptance = (
            acceptance
                + input.adaptation_gain.value() * (target_factor - acceptance)
        )
        .clamp(0.0, 1.0);

        kiosk_count += recommended_kiosk_increase;
    }

    let final_target = periods
        .last()
        .map(|period| period.target_factor)
        .ok_or(PopmathError::InvalidInput(
            "social feedback simulation produced no periods",
        ))?;

    let final_acceptance = periods
        .last()
        .map(|period| period.acceptance_factor.value())
        .ok_or(PopmathError::InvalidInput(
            "social feedback simulation produced no acceptance result",
        ))?;

    Ok(SocialFeedbackResult {
        equilibrium_acceptance: final_target,
        converged: (final_target.value() - final_acceptance).abs() <= 1e-6,
        periods,
    })
}
