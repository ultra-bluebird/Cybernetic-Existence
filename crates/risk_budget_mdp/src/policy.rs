use governance_core::{
    GovernanceFinding,
    RecommendationKind,
    RiskBudget,
};

use crate::{
    action_grid::{ActionGrid, BudgetAction},
    value_function::ValueFunction,
};

#[derive(Clone, Debug, PartialEq)]
pub struct RiskBudgetPolicy {
    pub policy_id: String,
    pub epoch: u64,
    pub action_grid: ActionGrid,
    pub value_function: ValueFunction,
}

#[derive(Clone, Debug, PartialEq)]
pub struct PolicyDecision {
    pub selected_action: Option<BudgetAction>,
    pub recommendation: RecommendationKind,
    pub findings: Vec<GovernanceFinding>,
    pub model_value_before: Option<f64>,
    pub model_value_after: Option<f64>,
    pub roh_budget: Option<RiskBudget>,
}
