#![forbid(unsafe_code)]
#![doc = include_str!("../README.md")]

use std::time::SystemTime;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DisclosureMode {
    None,
    ExplicitStatement,
    SelfCommitmentProof,
    AttestationProof,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProofPredicate {
    CommitmentExistsBeforeThreshold,
    IssuerAttestedDurationExceedsThreshold,
    IssuerAttestedUserSelectedClaim,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DisclosureRequest {
    pub subject_ref: String,
    pub recipient_ref: String,
    pub mode: DisclosureMode,
    pub purpose: String,
    pub requested_at: SystemTime,
    pub user_initiated: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DisclosurePresentation {
    pub presentation_ref: String,
    pub mode: DisclosureMode,
    pub predicate: Option<ProofPredicate>,
    pub expires_at: Option<SystemTime>,
    pub recovery_status_inference_allowed: bool,
    pub matching_use_allowed: bool,
    pub ranking_use_allowed: bool,
    pub public_visibility_allowed: bool,
    pub central_registry_entry_created: bool,
    pub external_action_authorized: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DisclosureError {
    EmptySubjectReference,
    EmptyRecipientReference,
    EmptyPurpose,
    UserInitiationRequired,
    ProofRequired,
    PredicateRequired,
    ForbiddenInferenceFlag,
    ForbiddenUseFlag,
}

pub trait ProofPresentationProvider {
    fn create_self_commitment_presentation(
        &self,
        request: &DisclosureRequest,
        threshold: SystemTime,
    ) -> Result<DisclosurePresentation, DisclosureError>;

    fn create_attestation_presentation(
        &self,
        request: &DisclosureRequest,
        predicate: ProofPredicate,
    ) -> Result<DisclosurePresentation, DisclosureError>;
}

pub fn validate_request(request: &DisclosureRequest) -> Result<(), DisclosureError> {
    if request.subject_ref.trim().is_empty() {
        return Err(DisclosureError::EmptySubjectReference);
    }

    if request.recipient_ref.trim().is_empty() {
        return Err(DisclosureError::EmptyRecipientReference);
    }

    if request.purpose.trim().is_empty() {
        return Err(DisclosureError::EmptyPurpose);
    }

    if !request.user_initiated {
        return Err(DisclosureError::UserInitiationRequired);
    }

    Ok(())
}

pub fn validate_presentation(
    presentation: &DisclosurePresentation,
) -> Result<(), DisclosureError> {
    if presentation.recovery_status_inference_allowed {
        return Err(DisclosureError::ForbiddenInferenceFlag);
    }

    if presentation.matching_use_allowed
        || presentation.ranking_use_allowed
        || presentation.public_visibility_allowed
        || presentation.central_registry_entry_created
        || presentation.external_action_authorized
    {
        return Err(DisclosureError::ForbiddenUseFlag);
    }

    match presentation.mode {
        DisclosureMode::None | DisclosureMode::ExplicitStatement => {
            if presentation.predicate.is_some() {
                return Err(DisclosureError::PredicateRequired);
            }
        }
        DisclosureMode::SelfCommitmentProof | DisclosureMode::AttestationProof => {
            if presentation.predicate.is_none() {
                return Err(DisclosureError::PredicateRequired);
            }
        }
    }

    Ok(())
}
