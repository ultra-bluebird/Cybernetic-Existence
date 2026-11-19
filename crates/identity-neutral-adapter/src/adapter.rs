use governance_core::ValidationReport;
use risk_budget_mdp::{PolicyDecision, RiskBudgetMdp};

use crate::{
    request::AssessmentRequest,
    response::AssessmentResponse,
};

#[derive(Clone, Debug)]
pub struct IdentityNeutralAdapter {
    mdp: RiskBudgetMdp,
}

impl IdentityNeutralAdapter {
    pub fn new(mdp: RiskBudgetMdp) -> Self;

    pub fn assess(
        &self,
        request: AssessmentRequest,
    ) -> AssessmentResponse;

    fn combine_reports(
        request: &AssessmentRequest,
        governance_report: ValidationReport,
        policy_decision: PolicyDecision,
    ) -> AssessmentResponse;
}
