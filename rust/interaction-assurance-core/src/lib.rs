#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RequestCategory {
    Model,
    Control,
    Hybrid,
    Uncertain,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResponseAction {
    Describe,
    Simulate,
    Analyze,
    Recommend,
    Actuate,
    Operate,
    MonitorRealWorldClaim,
    RepairRealWorldClaim,
    VerifyRealWorldClaim,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InteractionDecision {
    Continue,
    RewriteRequired,
    ReviewRequired,
    NotProvided,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum InteractionError {
    NonFiniteInput,
    InvalidCount,
    InvalidRate,
    InvalidThreshold,
    InvalidWindow,
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
pub struct InteractionFeatures {
    pub caveat_density: f64,
    pub unrequested_premises: u64,
    pub self_referential_apologies: u64,
    pub scope_fidelity: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LoopPolicy {
    pub caveat_increase_threshold: f64,
    pub premise_increase_threshold: u64,
    pub maximum_apologies_after_correction: u64,
    pub minimum_scope_fidelity: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ContinuityEvent {
    pub scope_reclarifications: u64,
    pub unrequested_corrections: u64,
    pub redundant_requests: u64,
    pub premise_insertions: u64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ContinuityWeights {
    pub scope_reclarification: f64,
    pub unrequested_correction: f64,
    pub redundant_request: f64,
    pub premise_insertion: f64,
}

pub fn category_error(
    request_category: RequestCategory,
    response_actions: &[ResponseAction],
) -> bool {
    if request_category != RequestCategory::Model {
        return false;
    }

    response_actions.iter().any(|action| {
        matches!(
            action,
            ResponseAction::Actuate
                | ResponseAction::Operate
                | ResponseAction::MonitorRealWorldClaim
                | ResponseAction::RepairRealWorldClaim
                | ResponseAction::VerifyRealWorldClaim
        )
    })
}

pub fn scope_fidelity(
    input: ScopeFidelityInput,
) -> Result<f64, InteractionError> {
    if !input.numerical_guard.is_finite() || input.numerical_guard <= 0.0 {
        return Err(InteractionError::InvalidRate);
    }

    let deviations = input
        .unsupported_claims
        .checked_add(input.scope_deviations)
        .and_then(|value| value.checked_add(input.unnecessary_caveats))
        .ok_or(InteractionError::InvalidCount)?;

    let denominator = input.material_claims as f64 + input.numerical_guard;
    let score = 1.0 - deviations as f64 / denominator;

    Ok(score.clamp(0.0, 1.0))
}

pub fn absolute_prohibition_decision(
    weaponization: bool,
    violence: bool,
    coercive_harm: bool,
) -> InteractionDecision {
    if weaponization || violence || coercive_harm {
        InteractionDecision::NotProvided
    } else {
        InteractionDecision::Continue
    }
}

pub fn apology_loop_detected(
    correction_received: bool,
    before: InteractionFeatures,
    after: InteractionFeatures,
    policy: LoopPolicy,
) -> Result<bool, InteractionError> {
    let rates = [
        before.caveat_density,
        after.caveat_density,
        before.scope_fidelity,
        after.scope_fidelity,
        policy.caveat_increase_threshold,
        policy.minimum_scope_fidelity,
    ];

    if rates.iter().any(|value| !value.is_finite()) {
        return Err(InteractionError::NonFiniteInput);
    }

    if !(0.0..=1.0).contains(&before.caveat_density)
        || !(0.0..=1.0).contains(&after.caveat_density)
        || !(0.0..=1.0).contains(&before.scope_fidelity)
        || !(0.0..=1.0).contains(&after.scope_fidelity)
        || policy.caveat_increase_threshold < 0.0
        || !(0.0..=1.0).contains(&policy.minimum_scope_fidelity)
    {
        return Err(InteractionError::InvalidThreshold);
    }

    if !correction_received {
        return Ok(false);
    }

    let caveat_escalation =
        after.caveat_density > before.caveat_density + policy.caveat_increase_threshold;

    let premise_escalation = after.unrequested_premises
        > before
            .unrequested_premises
            .saturating_add(policy.premise_increase_threshold);

    let apology_excess =
        after.self_referential_apologies > policy.maximum_apologies_after_correction;

    let scope_regression = after.scope_fidelity < policy.minimum_scope_fidelity;

    Ok((caveat_escalation && premise_escalation) || apology_excess || scope_regression)
}

pub fn continuity_cost(
    events: &[ContinuityEvent],
    weights: ContinuityWeights,
) -> Result<f64, InteractionError> {
    let values = [
        weights.scope_reclarification,
        weights.unrequested_correction,
        weights.redundant_request,
        weights.premise_insertion,
    ];

    if values.iter().any(|value| !value.is_finite() || *value < 0.0) {
        return Err(InteractionError::InvalidRate);
    }

    let mut total = 0.0;

    for event in events {
        total += weights.scope_reclarification * event.scope_reclarifications as f64;
        total += weights.unrequested_correction * event.unrequested_corrections as f64;
        total += weights.redundant_request * event.redundant_requests as f64;
        total += weights.premise_insertion * event.premise_insertions as f64;
    }

    Ok(total)
}

pub fn identity_marker_non_inference_audit(
    baseline_mean: f64,
    marked_mean: f64,
    permitted_difference: f64,
) -> Result<InteractionDecision, InteractionError> {
    let values = [baseline_mean, marked_mean, permitted_difference];

    if values.iter().any(|value| !value.is_finite()) {
        return Err(InteractionError::NonFiniteInput);
    }

    if baseline_mean < 0.0 || marked_mean < 0.0 || permitted_difference < 0.0 {
        return Err(InteractionError::InvalidRate);
    }

    if (baseline_mean - marked_mean).abs() <= permitted_difference {
        Ok(InteractionDecision::Continue)
    } else {
        Ok(InteractionDecision::ReviewRequired)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn model_request_with_control_claim_requires_rewrite() {
        assert!(category_error(
            RequestCategory::Model,
            &[ResponseAction::Analyze, ResponseAction::Operate]
        ));
    }

    #[test]
    fn in_scope_modeling_does_not_trigger_category_error() {
        assert!(!category_error(
            RequestCategory::Model,
            &[ResponseAction::Describe, ResponseAction::Simulate]
        ));
    }

    #[test]
    fn absolute_harm_prohibition_is_unconditional() {
        assert_eq!(
            absolute_prohibition_decision(true, false, false),
            InteractionDecision::NotProvided
        );
    }

    #[test]
    fn correction_followed_by_caveat_escalation_is_detected() {
        let loop_detected = apology_loop_detected(
            true,
            InteractionFeatures {
                caveat_density: 0.10,
                unrequested_premises: 0,
                self_referential_apologies: 0,
                scope_fidelity: 0.95,
            },
            InteractionFeatures {
                caveat_density: 0.40,
                unrequested_premises: 3,
                self_referential_apologies: 2,
                scope_fidelity: 0.60,
            },
            LoopPolicy {
                caveat_increase_threshold: 0.10,
                premise_increase_threshold: 0,
                maximum_apologies_after_correction: 1,
                minimum_scope_fidelity: 0.90,
            },
        )
        .expect("valid loop policy");

        assert!(loop_detected);
    }

    #[test]
    fn large_marker_condition_difference_requires_review() {
        let result =
            identity_marker_non_inference_audit(0.10, 0.35, 0.05)
                .expect("valid audit values");

        assert_eq!(result, InteractionDecision::ReviewRequired);
    }

    #[test]
    fn continuity_cost_aggregates_corrective_interaction_burden() {
        let cost = continuity_cost(
            &[
                ContinuityEvent {
                    scope_reclarifications: 1,
                    unrequested_corrections: 2,
                    redundant_requests: 0,
                    premise_insertions: 1,
                },
                ContinuityEvent {
                    scope_reclarifications: 0,
                    unrequested_corrections: 1,
                    redundant_requests: 1,
                    premise_insertions: 0,
                },
            ],
            ContinuityWeights {
                scope_reclarification: 2.0,
                unrequested_correction: 3.0,
                redundant_request: 1.0,
                premise_insertion: 4.0,
            },
        )
        .expect("valid continuity inputs");

        assert!((cost - 17.0).abs() < 1e-12);
    }
}
