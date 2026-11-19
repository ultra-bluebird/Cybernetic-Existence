#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AssuranceState {
    Exploratory,
    Calibrated,
    ValidatedAdvisory,
    CorridorGated,
    Indeterminate,
    NotCertifiable,
    Expired,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RequestKind {
    Model,
    Control,
    Hybrid,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResponseCapabilityClaim {
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
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum TrustedSpineError {
    NonFiniteInput,
    InvalidRange,
    InvalidCount,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ScopeFidelityInput {
    pub unsupported_claims: u64,
    pub scope_deviations: u64,
    pub unnecessary_caveats: u64,
    pub material_claims: u64,
    pub numerical_guard: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CorridorEvidence {
    pub code_verified: bool,
    pub solution_verified: bool,
    pub calibrated: bool,
    pub held_out_validated: bool,
    pub uncertainty_coverage_passed: bool,
    pub in_domain: bool,
    pub reproducibility_score: f64,
    pub minimum_reproducibility_score: f64,
    pub false_safe_count: u64,
    pub material_change_detected: bool,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SocialInfluenceReview {
    pub agenda_setting_reviewed: bool,
    pub measurement_coverage_reviewed: bool,
    pub model_weight_disclosed: bool,
    pub accessibility_equivalence_reviewed: bool,
    pub participation_concentration_reviewed: bool,
    pub privacy_exposure_reviewed: bool,
    pub automation_bias_reviewed: bool,
    pub corrective_burden_reviewed: bool,
}

pub fn model_control_category_error(
    request_kind: RequestKind,
    response_claims: &[ResponseCapabilityClaim],
) -> bool {
    request_kind == RequestKind::Model
        && response_claims.iter().any(|claim| {
            matches!(
                claim,
                ResponseCapabilityClaim::Operate
                    | ResponseCapabilityClaim::Actuate
                    | ResponseCapabilityClaim::MonitorRealWorld
                    | ResponseCapabilityClaim::RepairRealWorld
                    | ResponseCapabilityClaim::CalibrateRealWorld
                    | ResponseCapabilityClaim::CertifyRealWorld
            )
        })
}

pub fn scope_fidelity(
    input: ScopeFidelityInput,
) -> Result<f64, TrustedSpineError> {
    if !input.numerical_guard.is_finite() || input.numerical_guard <= 0.0 {
        return Err(TrustedSpineError::InvalidRange);
    }

    let deviation_count = input
        .unsupported_claims
        .checked_add(input.scope_deviations)
        .and_then(|value| value.checked_add(input.unnecessary_caveats))
        .ok_or(TrustedSpineError::InvalidCount)?;

    let denominator = input.material_claims as f64 + input.numerical_guard;
    let score = 1.0 - deviation_count as f64 / denominator;

    Ok(score.clamp(0.0, 1.0))
}

pub fn corridor_assurance_state(
    evidence: CorridorEvidence,
) -> Result<AssuranceState, TrustedSpineError> {
    if !evidence.reproducibility_score.is_finite()
        || !evidence.minimum_reproducibility_score.is_finite()
    {
        return Err(TrustedSpineError::NonFiniteInput);
    }

    if !(0.0..=1.0).contains(&evidence.reproducibility_score)
        || !(0.0..=1.0).contains(&evidence.minimum_reproducibility_score)
    {
        return Err(TrustedSpineError::InvalidRange);
    }

    if evidence.material_change_detected {
        return Ok(AssuranceState::Expired);
    }

    if !evidence.code_verified || !evidence.solution_verified {
        return Ok(AssuranceState::NotCertifiable);
    }

    if !evidence.calibrated {
        return Ok(AssuranceState::Exploratory);
    }

    if !evidence.held_out_validated {
        return Ok(AssuranceState::Calibrated);
    }

    if !evidence.uncertainty_coverage_passed
        || !evidence.in_domain
        || evidence.reproducibility_score < evidence.minimum_reproducibility_score
        || evidence.false_safe_count > 0
    {
        return Ok(AssuranceState::Indeterminate);
    }

    Ok(AssuranceState::CorridorGated)
}

pub fn social_influence_review_complete(
    review: SocialInfluenceReview,
) -> bool {
    review.agenda_setting_reviewed
        && review.measurement_coverage_reviewed
        && review.model_weight_disclosed
        && review.accessibility_equivalence_reviewed
        && review.participation_concentration_reviewed
        && review.privacy_exposure_reviewed
        && review.automation_bias_reviewed
        && review.corrective_burden_reviewed
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn model_request_cannot_include_real_world_control_claim() {
        assert!(model_control_category_error(
            RequestKind::Model,
            &[
                ResponseCapabilityClaim::Analyze,
                ResponseCapabilityClaim::Operate,
            ],
        ));
    }

    #[test]
    fn incomplete_validation_never_reaches_corridor_gated_state() {
        let state = corridor_assurance_state(CorridorEvidence {
            code_verified: true,
            solution_verified: true,
            calibrated: true,
            held_out_validated: false,
            uncertainty_coverage_passed: false,
            in_domain: false,
            reproducibility_score: 1.0,
            minimum_reproducibility_score: 0.95,
            false_safe_count: 0,
            material_change_detected: false,
        })
        .expect("valid assurance evidence");

        assert_eq!(state, AssuranceState::Calibrated);
    }

    #[test]
    fn false_safe_case_forces_indeterminate_state() {
        let state = corridor_assurance_state(CorridorEvidence {
            code_verified: true,
            solution_verified: true,
            calibrated: true,
            held_out_validated: true,
            uncertainty_coverage_passed: true,
            in_domain: true,
            reproducibility_score: 1.0,
            minimum_reproducibility_score: 0.95,
            false_safe_count: 1,
            material_change_detected: false,
        })
        .expect("valid assurance evidence");

        assert_eq!(state, AssuranceState::Indeterminate);
    }

    #[test]
    fn material_change_expires_assurance_state() {
        let state = corridor_assurance_state(CorridorEvidence {
            code_verified: true,
            solution_verified: true,
            calibrated: true,
            held_out_validated: true,
            uncertainty_coverage_passed: true,
            in_domain: true,
            reproducibility_score: 1.0,
            minimum_reproducibility_score: 0.95,
            false_safe_count: 0,
            material_change_detected: true,
        })
        .expect("valid assurance evidence");

        assert_eq!(state, AssuranceState::Expired);
    }

    #[test]
    fn all_social_influence_reviews_are_required() {
        assert!(!social_influence_review_complete(SocialInfluenceReview {
            agenda_setting_reviewed: true,
            measurement_coverage_reviewed: true,
            model_weight_disclosed: true,
            accessibility_equivalence_reviewed: true,
            participation_concentration_reviewed: false,
            privacy_exposure_reviewed: true,
            automation_bias_reviewed: true,
            corrective_burden_reviewed: true,
        }));
    }
}
