use governance_core::{
    EvidenceState,
    GovernanceFinding,
    RecommendationKind,
    RiskAxes,
    SafetyEnvelopeState,
    GLOBAL_ROH_CEILING,
};

use crate::{
    action_grid::BudgetAction,
    policy::{PolicyDecision, RiskBudgetPolicy},
    state::RealityState,
};

#[derive(Clone, Debug)]
pub struct RiskBudgetMdp {
    policy: RiskBudgetPolicy,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TransitionError {
    MissingModelInputs,
    EvidenceNotReady,
    EnvelopeNotReady,
    RoHCeilingExceeded,
    NonIncreasingResidualNotEstablished,
}

impl RiskBudgetMdp {
    pub fn new(policy: RiskBudgetPolicy) -> Self {
        Self { policy }
    }

    pub fn policy(&self) -> &RiskBudgetPolicy {
        &self.policy
    }

    pub fn evaluate(
        &self,
        current: RealityState,
        predicted_next: RealityState,
    ) -> PolicyDecision {
        let mut findings = Vec::new();

        if !current.has_required_model_inputs() || !predicted_next.has_required_model_inputs() {
            findings.push(GovernanceFinding::UnknownRequiredInput);

            return PolicyDecision {
                selected_action: None,
                recommendation: RecommendationKind::HoldForReview,
                findings,
                model_value_before: None,
                model_value_after: None,
                roh_budget: None,
            };
        }

        if !evidence_is_ready(current.evidence_state) ||
            !evidence_is_ready(predicted_next.evidence_state)
        {
            findings.push(GovernanceFinding::EvidenceIncomplete);

            return PolicyDecision {
                selected_action: None,
                recommendation: RecommendationKind::HoldForReview,
                findings,
                model_value_before: None,
                model_value_after: None,
                roh_budget: None,
            };
        }

        if !envelope_is_ready(current.envelope_state) ||
            !envelope_is_ready(predicted_next.envelope_state)
        {
            findings.push(GovernanceFinding::CorridorViolation);

            return PolicyDecision {
                selected_action: None,
                recommendation: RecommendationKind::HoldForReview,
                findings,
                model_value_before: None,
                model_value_after: None,
                roh_budget: None,
            };
        }

        let model_value_before = match self.policy.value_function.evaluate(current.risk_axes) {
            Ok(value) => value,
            Err(_) => {
                findings.push(GovernanceFinding::UnknownRequiredInput);

                return PolicyDecision {
                    selected_action: None,
                    recommendation: RecommendationKind::HoldForReview,
                    findings,
                    model_value_before: None,
                    model_value_after: None,
                    roh_budget: None,
                };
            }
        };

        let model_value_after = match self.policy.value_function.evaluate(predicted_next.risk_axes) {
            Ok(value) => value,
            Err(_) => {
                findings.push(GovernanceFinding::UnknownRequiredInput);

                return PolicyDecision {
                    selected_action: None,
                    recommendation: RecommendationKind::HoldForReview,
                    findings,
                    model_value_before: Some(model_value_before),
                    model_value_after: None,
                    roh_budget: None,
                };
            }
        };

        if model_value_after > model_value_before {
            findings.push(GovernanceFinding::CorridorViolation);

            return PolicyDecision {
                selected_action: None,
                recommendation: RecommendationKind::HoldForReview,
                findings,
                model_value_before: Some(model_value_before),
                model_value_after: Some(model_value_after),
                roh_budget: None,
            };
        }

        let selected_action = self
            .policy
            .action_grid
            .actions()
            .iter()
            .copied()
            .find(|action| {
                self.action_is_feasible(*action, current, predicted_next)
                    .is_ok()
            });

        match selected_action {
            Some(action) => PolicyDecision {
                selected_action: Some(action),
                recommendation: RecommendationKind::Observe,
                findings,
                model_value_before: Some(model_value_before),
                model_value_after: Some(model_value_after),
                roh_budget: Some(action.budget),
            },
            None => {
                findings.push(GovernanceFinding::RoHCeilingExceeded);

                PolicyDecision {
                    selected_action: None,
                    recommendation: RecommendationKind::HoldForReview,
                    findings,
                    model_value_before: Some(model_value_before),
                    model_value_after: Some(model_value_after),
                    roh_budget: None,
                }
            }
        }
    }

    pub fn action_is_feasible(
        &self,
        action: BudgetAction,
        current: RealityState,
        predicted_next: RealityState,
    ) -> Result<(), TransitionError> {
        if !current.has_required_model_inputs() || !predicted_next.has_required_model_inputs() {
            return Err(TransitionError::MissingModelInputs);
        }

        if !evidence_is_ready(current.evidence_state) ||
            !evidence_is_ready(predicted_next.evidence_state)
        {
            return Err(TransitionError::EvidenceNotReady);
        }

        if !envelope_is_ready(current.envelope_state) ||
            !envelope_is_ready(predicted_next.envelope_state)
        {
            return Err(TransitionError::EnvelopeNotReady);
        }

        if !risk_axes_within_budget(current.risk_axes, action.budget) ||
            !risk_axes_within_budget(predicted_next.risk_axes, action.budget)
        {
            return Err(TransitionError::RoHCeilingExceeded);
        }

        if action.budget.global_ceiling() > GLOBAL_ROH_CEILING {
            return Err(TransitionError::RoHCeilingExceeded);
        }

        let residual_non_increasing = self
            .policy
            .value_function
            .is_non_increasing(current.risk_axes, predicted_next.risk_axes)
            .map_err(|_| TransitionError::MissingModelInputs)?;

        if !residual_non_increasing {
            return Err(TransitionError::NonIncreasingResidualNotEstablished);
        }

        Ok(())
    }
}

fn evidence_is_ready(state: EvidenceState) -> bool {
    matches!(
        state,
        EvidenceState::VerifiedFact |
            EvidenceState::CalibratedEstimate |
            EvidenceState::ScreeningEstimate |
            EvidenceState::ModelOutput
    )
}

fn envelope_is_ready(state: SafetyEnvelopeState) -> bool {
    matches!(state, SafetyEnvelopeState::WithinEnvelope)
}

fn risk_axes_within_budget(risks: RiskAxes, budget: governance_core::RiskBudget) -> bool {
    risks.all_at_or_below(budget)
}
