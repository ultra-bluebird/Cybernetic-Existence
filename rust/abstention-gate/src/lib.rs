#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct AbstentionInputs {
    pub calibrated_confidence: f64,
    pub false_output_loss: f64,
    pub abstention_loss: f64,
    pub delay_loss: f64,
    pub context_risk_multiplier: f64,
    pub reversible: bool,
    pub human_fallback_available: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Decision {
    Present,
    Confirm,
    Abstain,
    DeferToHumanReview,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DecisionReport {
    pub decision: Decision,
    pub expected_output_loss: f64,
    pub expected_abstention_loss: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AbstentionError {
    InvalidUnitInterval,
    InvalidNonNegativeValue,
}

pub fn decide(inputs: AbstentionInputs) -> Result<DecisionReport, AbstentionError> {
    validate_unit_interval(inputs.calibrated_confidence)?;
    validate_non_negative(inputs.false_output_loss)?;
    validate_non_negative(inputs.abstention_loss)?;
    validate_non_negative(inputs.delay_loss)?;
    validate_non_negative(inputs.context_risk_multiplier)?;

    let expected_output_loss = (1.0 - inputs.calibrated_confidence)
        * inputs.false_output_loss
        * inputs.context_risk_multiplier;

    let expected_abstention_loss = inputs.abstention_loss + inputs.delay_loss;

    let decision = if expected_output_loss <= expected_abstention_loss {
        if inputs.calibrated_confidence >= 0.90 || inputs.reversible {
            Decision::Present
        } else {
            Decision::Confirm
        }
    } else if inputs.human_fallback_available {
        Decision::DeferToHumanReview
    } else {
        Decision::Abstain
    };

    Ok(DecisionReport {
        decision,
        expected_output_loss,
        expected_abstention_loss,
    })
}

fn validate_unit_interval(value: f64) -> Result<(), AbstentionError> {
    if !value.is_finite() || !(0.0..=1.0).contains(&value) {
        return Err(AbstentionError::InvalidUnitInterval);
    }

    Ok(())
}

fn validate_non_negative(value: f64) -> Result<(), AbstentionError> {
    if !value.is_finite() || value < 0.0 {
        return Err(AbstentionError::InvalidNonNegativeValue);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn presents_a_high_confidence_reversible_output() {
        let report = decide(AbstentionInputs {
            calibrated_confidence: 0.95,
            false_output_loss: 1.0,
            abstention_loss: 2.0,
            delay_loss: 0.5,
            context_risk_multiplier: 1.0,
            reversible: true,
            human_fallback_available: true,
        })
        .expect("valid inputs");

        assert_eq!(report.decision, Decision::Present);
    }

    #[test]
    fn asks_for_confirmation_when_output_is_not_reversible() {
        let report = decide(AbstentionInputs {
            calibrated_confidence: 0.85,
            false_output_loss: 1.0,
            abstention_loss: 2.0,
            delay_loss: 0.5,
            context_risk_multiplier: 1.0,
            reversible: false,
            human_fallback_available: true,
        })
        .expect("valid inputs");

        assert_eq!(report.decision, Decision::Confirm);
    }

    #[test]
    fn defers_high_risk_low_confidence_decision_to_human_review() {
        let report = decide(AbstentionInputs {
            calibrated_confidence: 0.30,
            false_output_loss: 10.0,
            abstention_loss: 1.0,
            delay_loss: 1.0,
            context_risk_multiplier: 2.0,
            reversible: false,
            human_fallback_available: true,
        })
        .expect("valid inputs");

        assert_eq!(report.decision, Decision::DeferToHumanReview);
    }

    #[test]
    fn abstains_when_human_review_is_unavailable() {
        let report = decide(AbstentionInputs {
            calibrated_confidence: 0.20,
            false_output_loss: 10.0,
            abstention_loss: 1.0,
            delay_loss: 1.0,
            context_risk_multiplier: 2.0,
            reversible: false,
            human_fallback_available: false,
        })
        .expect("valid inputs");

        assert_eq!(report.decision, Decision::Abstain);
    }
}
