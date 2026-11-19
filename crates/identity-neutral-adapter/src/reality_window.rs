use governance_core::{EvidenceState, SafetyEnvelope};
use risk_budget_mdp::RealityState;

#[derive(Clone, Debug, PartialEq)]
pub struct RealityWindow {
    pub state: RealityState,
    pub envelope: SafetyEnvelope,
    pub observation_reference: String,
    pub evidence_state: EvidenceState,
    pub uncertainty_stated: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RealityWindowError {
    EmptyObservationReference,
    IdentityBearingReference,
    MissingUncertainty,
}

impl RealityWindow {
    pub fn new(
        state: RealityState,
        envelope: SafetyEnvelope,
        observation_reference: String,
        evidence_state: EvidenceState,
        uncertainty_stated: bool,
    ) -> Result<Self, RealityWindowError>;
}
