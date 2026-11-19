#![forbid(unsafe_code)]
#![deny(unused_must_use)]
#![deny(unused_imports)]
#![deny(unused_variables)]

pub mod api;
pub mod decision;
pub mod evidence;
pub mod mission;
pub mod risk;
pub mod safety_envelope;
pub mod status;
pub mod validation;

pub use api::{
    evaluate_governance,
    DefaultGovernanceEvaluator,
    GovernanceEvaluator,
    GovernanceEvaluationRequest,
    GovernanceEvaluationResponse,
};
pub use decision::{
    GovernanceDecision,
    GovernanceFinding,
    RecommendationKind,
};
pub use evidence::{
    EvidenceBundle,
    EvidenceTag,
    EvidenceTagError,
    EvidenceTagKind,
    REQUIRED_EVIDENCE_TAG_COUNT,
};
pub use mission::{
    MissionDescriptor,
    MissionKind,
    MissionScope,
};
pub use risk::{
    RiskAxes,
    RiskBudget,
    RiskError,
    RiskPlane,
    RiskValue,
    GLOBAL_ROH_CEILING,
};
pub use safety_envelope::{
    EnvelopeObservation,
    SafetyEnvelope,
    SafetyEnvelopeError,
    SafetyEnvelopeState,
};
pub use status::{
    EvidenceState,
    ReviewState,
};
pub use validation::{
    validate_mission,
    ValidationReport,
};
