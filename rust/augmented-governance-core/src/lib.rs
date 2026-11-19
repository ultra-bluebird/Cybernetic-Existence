#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

pub mod envelope;
pub mod integration;
pub mod rights;
pub mod scaling;

pub use envelope::{Envelope, EnvelopeState};
pub use integration::{
    evaluate_integration_update, integration_outcome_preserves_rights, IntegrationBounds,
    IntegrationDecision, IntegrationDecisionRecord, IntegrationDepth, IntegrationRequest,
};
pub use rights::{
    adverse_decision_is_contestable, data_minimization_holds, essential_service_is_independent,
    evaluate, ConsentStatus, DataClass, Decision, DecisionRecord, ProcessingPurpose,
    RecognitionState, Request, ReviewState, ServiceClass,
};
pub use scaling::{EvoMode, EvoModeScaling, ScalingError};
