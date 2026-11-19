use governance_core::{EvidenceBundle, MissionDescriptor};
use crate::reality_window::RealityWindow;

#[derive(Clone, Debug, PartialEq)]
pub struct AssessmentRequest {
    pub request_id: String,
    pub mission: MissionDescriptor,
    pub evidence_bundle: EvidenceBundle,
    pub current_window: RealityWindow,
    pub predicted_window: RealityWindow,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AssessmentRequestError {
    EmptyRequestId,
    IdentityBearingRequest,
    CredentialBearingRequest,
    ActuationSemanticRequest,
}
