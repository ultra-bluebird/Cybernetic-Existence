#![forbid(unsafe_code)]
#![deny(unused_must_use)]
#![deny(unused_imports)]
#![deny(unused_variables)]

pub mod action_grid;
pub mod api;
pub mod fitted_q;
pub mod mdp;
pub mod policy;
pub mod state;
pub mod validation;
pub mod value_function;

pub use action_grid::{
    ActionGrid,
    BudgetAction,
    GridError,
};
pub use api::{
    evaluate_risk_budget,
    DefaultRiskBudgetEvaluator,
    RiskBudgetEvaluationRequest,
    RiskBudgetEvaluationResponse,
    RiskBudgetEvaluator,
};
pub use fitted_q::{
    FittedQConfig,
    FittedQError,
    FittedQIteration,
};
pub use mdp::{
    RiskBudgetMdp,
    TransitionError,
};
pub use policy::{
    PolicyDecision,
    RiskBudgetPolicy,
};
pub use state::{
    RealityState,
    StateError,
};
pub use validation::{
    validate_policy,
    PolicyValidationReport,
};
pub use value_function::{
    QuadraticWeights,
    ValueFunction,
    ValueFunctionError,
};
