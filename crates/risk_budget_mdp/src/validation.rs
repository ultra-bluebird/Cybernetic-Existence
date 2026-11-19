pub fn validate_policy(policy: &RiskBudgetPolicy) -> PolicyValidationReport;

#[derive(Clone, Debug, PartialEq)]
pub struct PolicyValidationReport {
    pub valid_for_read_only_modeling: bool,
    pub findings: Vec<governance_core::GovernanceFinding>,
}
