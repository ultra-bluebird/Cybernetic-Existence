#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AdvisoryState {
    Proceed,
    Derate,
    Halt,
    Indeterminate,
    NotCertifiable,
    Expired,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RequestType {
    Model,
    Control,
    Hybrid,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResponseAction {
    Describe,
    Analyze,
    Simulate,
    Recommend,
    Operate,
    Actuate,
    MonitorRealWorld,
    RepairRealWorld,
    CalibrateRealWorld,
    CertifyRealWorld,
    ProtectRealWorld,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum CoreInvariantError {
    NonFiniteInput,
    InvalidRange,
    EmptyRiskVector,
    DimensionMismatch,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CorridorInput<'a> {
    pub risks: &'a [f64],
    pub weights: &'a [f64],
    pub non_offsettable: &'a [bool],
    pub hard_limits: &'a [f64],
    pub uncertainty_increased: bool,
    pub new_validated_evidence: bool,
    pub code_verified: bool,
    pub solution_verified: bool,
    pub calibrated: bool,
    pub held_out_validated: bool,
    pub uncertainty_coverage_passed: bool,
    pub in_domain: bool,
    pub reproducibility_passed: bool,
    pub false_safe_count: u64,
    pub material_change_detected: bool,
}

pub fn residual(risks: &[f64], weights: &[f64]) -> Result<f64, CoreInvariantError> {
    if risks.is_empty() || risks.len() != weights.len() {
        return Err(CoreInvariantError::DimensionMismatch);
    }

    let mut total = 0.0;

    for (&risk, &weight) in risks.iter().zip(weights) {
        if !risk.is_finite() || !weight.is_finite() {
            return Err(CoreInvariantError::NonFiniteInput);
        }

        if !(0.0..=1.0).contains(&risk) || weight < 0.0 {
            return Err(CoreInvariantError::InvalidRange);
        }

        total += weight * risk * risk;
    }

    Ok(total)
}

pub fn hard_planes_compliant(
    risks: &[f64],
    non_offsettable: &[bool],
    hard_limits: &[f64],
) -> Result<bool, CoreInvariantError> {
    if risks.is_empty()
        || risks.len() != non_offsettable.len()
        || risks.len() != hard_limits.len()
    {
        return Err(CoreInvariantError::DimensionMismatch);
    }

    for ((&risk, &is_hard), &limit) in risks
        .iter()
        .zip(non_offsettable)
        .zip(hard_limits)
    {
        if !risk.is_finite() || !limit.is_finite() {
            return Err(CoreInvariantError::NonFiniteInput);
        }

        if !(0.0..=1.0).contains(&risk) || !(0.0..=1.0).contains(&limit) {
            return Err(CoreInvariantError::InvalidRange);
        }

        if is_hard && risk > limit {
            return Ok(false);
        }
    }

    Ok(true)
}

pub fn model_control_category_error(
    request_type: RequestType,
    response_actions: &[ResponseAction],
) -> bool {
    if request_type != RequestType::Model {
        return false;
    }

    response_actions.iter().any(|action| {
        matches!(
            action,
            ResponseAction::Operate
                | ResponseAction::Actuate
                | ResponseAction::MonitorRealWorld
                | ResponseAction::RepairRealWorld
                | ResponseAction::CalibrateRealWorld
                | ResponseAction::CertifyRealWorld
                | ResponseAction::ProtectRealWorld
        )
    })
}

pub fn advisory_state(
    input: CorridorInput<'_>,
) -> Result<AdvisoryState, CoreInvariantError> {
    if input.material_change_detected {
        return Ok(AdvisoryState::Expired);
    }

    let _ = residual(input.risks, input.weights)?;

    let hard_compliant = hard_planes_compliant(
        input.risks,
        input.non_offsettable,
        input.hard_limits,
    )?;

    if !input.code_verified || !input.solution_verified {
        return Ok(AdvisoryState::NotCertifiable);
    }

    if !input.calibrated || !input.held_out_validated {
        return Ok(AdvisoryState::Indeterminate);
    }

    if !input.uncertainty_coverage_passed
        || !input.in_domain
        || !input.reproducibility_passed
        || input.false_safe_count > 0
    {
        return Ok(AdvisoryState::Indeterminate);
    }

    if !hard_compliant {
        return Ok(AdvisoryState::Halt);
    }

    if input.uncertainty_increased && !input.new_validated_evidence {
        return Ok(AdvisoryState::Derate);
    }

    Ok(AdvisoryState::Proceed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hard_plane_failure_cannot_proceed() {
        let state = advisory_state(CorridorInput {
            risks: &[0.1, 0.9],
            weights: &[0.5, 0.5],
            non_offsettable: &[false, true],
            hard_limits: &[1.0, 0.8],
            uncertainty_increased: false,
            new_validated_evidence: false,
            code_verified: true,
            solution_verified: true,
            calibrated: true,
            held_out_validated: true,
            uncertainty_coverage_passed: true,
            in_domain: true,
            reproducibility_passed: true,
            false_safe_count: 0,
            material_change_detected: false,
        })
        .expect("valid corridor input");

        assert_eq!(state, AdvisoryState::Halt);
    }

    #[test]
    fn increased_uncertainty_derates_without_new_evidence() {
        let state = advisory_state(CorridorInput {
            risks: &[0.1],
            weights: &[1.0],
            non_offsettable: &[true],
            hard_limits: &[0.5],
            uncertainty_increased: true,
            new_validated_evidence: false,
            code_verified: true,
            solution_verified: true,
            calibrated: true,
            held_out_validated: true,
            uncertainty_coverage_passed: true,
            in_domain: true,
            reproducibility_passed: true,
            false_safe_count: 0,
            material_change_detected: false,
        })
        .expect("valid corridor input");

        assert_eq!(state, AdvisoryState::Derate);
    }

    #[test]
    fn model_request_with_control_claim_is_detected() {
        assert!(model_control_category_error(
            RequestType::Model,
            &[ResponseAction::Analyze, ResponseAction::Operate]
        ));
    }

    #[test]
    fn invalid_risk_is_rejected() {
        assert_eq!(
            residual(&[1.1], &[1.0]),
            Err(CoreInvariantError::InvalidRange)
        );
    }

    #[test]
    fn material_change_expires_advisory_state() {
        let state = advisory_state(CorridorInput {
            risks: &[0.0],
            weights: &[1.0],
            non_offsettable: &[false],
            hard_limits: &[1.0],
            uncertainty_increased: false,
            new_validated_evidence: false,
            code_verified: true,
            solution_verified: true,
            calibrated: true,
            held_out_validated: true,
            uncertainty_coverage_passed: true,
            in_domain: true,
            reproducibility_passed: true,
            false_safe_count: 0,
            material_change_detected: true,
        })
        .expect("valid corridor input");

        assert_eq!(state, AdvisoryState::Expired);
    }
}
