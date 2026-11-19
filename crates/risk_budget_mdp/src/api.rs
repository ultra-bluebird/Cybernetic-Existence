use crate::{
    mdp::RiskBudgetMdp,
    policy::PolicyDecision,
    state::RealityState,
    validation::{validate_policy, PolicyValidationReport},
};

#[derive(Clone, Debug, PartialEq)]
pub struct RiskBudgetEvaluationRequest {
    pub current_state: RealityState,
    pub predicted_next_state: RealityState,
}

#[derive(Clone, Debug, PartialEq)]
pub struct RiskBudgetEvaluationResponse {
    pub policy_validation: PolicyValidationReport,
    pub policy_decision: PolicyDecision,
    pub non_actuating: bool,
    pub identity_neutral: bool,
    pub limitations: Vec<String>,
}

pub trait RiskBudgetEvaluator {
    fn validate_policy(&self) -> PolicyValidationReport;

    fn evaluate(
        &self,
        request: &RiskBudgetEvaluationRequest,
    ) -> RiskBudgetEvaluationResponse;
}

#[derive(Clone, Debug)]
pub struct DefaultRiskBudgetEvaluator {
    mdp: RiskBudgetMdp,
}

impl DefaultRiskBudgetEvaluator {
    pub fn new(mdp: RiskBudgetMdp) -> Self {
        Self { mdp }
    }
}

impl RiskBudgetEvaluator for DefaultRiskBudgetEvaluator {
    fn validate_policy(&self) -> PolicyValidationReport {
        validate_policy(self.mdp.policy())
    }

    fn evaluate(
        &self,
        request: &RiskBudgetEvaluationRequest,
    ) -> RiskBudgetEvaluationResponse {
        let policy_validation = self.validate_policy();
        let policy_decision = self
            .mdp
            .evaluate(request.current_state, request.predicted_next_state);

        RiskBudgetEvaluationResponse {
            policy_validation,
            policy_decision,
            non_actuating: true,
            identity_neutral: true,
            limitations: vec![
                "This result is a risk-budget model output based on supplied non-personal state inputs.".to_owned(),
                "This result does not verify identity or augmentation status.".to_owned(),
                "This result does not establish individual safety, medical suitability, legal compliance, or operational authorization.".to_owned(),
                "This result does not emit hardware, firmware, BCI, augmentation, infrastructure, or actuator commands.".to_owned(),
            ],
        }
    }
}

pub fn evaluate_risk_budget(
    mdp: RiskBudgetMdp,
    request: &RiskBudgetEvaluationRequest,
) -> RiskBudgetEvaluationResponse {
    DefaultRiskBudgetEvaluator::new(mdp).evaluate(request)
}
