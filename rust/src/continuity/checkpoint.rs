use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryMode {
    GracefulDegradation,
    LocalFallback,
    IntegrityReview,
    AuthorizedRollbackReview,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UserAcknowledgmentState {
    NotRequested,
    Requested,
    Confirmed,
    Declined,
    Unavailable,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContinuityAssessment {
    IntegrityEvidenceAvailable,
    RecoveryReviewRequired,
    IntegrityEvidenceInsufficient,
    UserAcknowledgmentRequired,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContinuityCheckpoint {
    pub checkpoint_sequence: u64,
    pub created_at_unix_ms: u64,
    pub previous_checkpoint_hash: String,
    pub protected_state_commitment: String,
    pub encrypted_state_reference: String,
    pub merkle_root: String,
    pub policy_version: String,
    pub recovery_mode: RecoveryMode,
    pub user_acknowledgment_state: UserAcknowledgmentState,
    pub non_actuation_assertion: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContinuityVerificationInput {
    pub expected_previous_checkpoint_hash: String,
    pub expected_policy_version: String,
    pub checkpoint: ContinuityCheckpoint,
    pub merkle_root_verified: bool,
    pub signature_envelope_verified: bool,
    pub local_state_reference_available: bool,
    pub measured_recovery_ms: Option<u32>,
    pub maximum_recovery_ms: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContinuityVerificationReport {
    pub checkpoint_sequence: u64,
    pub assessment: ContinuityAssessment,
    pub chain_link_valid: bool,
    pub policy_version_valid: bool,
    pub recovery_target_met: bool,
    pub reasons: Vec<String>,
}

fn non_empty(value: &str) -> bool {
    !value.trim().is_empty()
}

pub fn verify_checkpoint(
    input: &ContinuityVerificationInput,
) -> ContinuityVerificationReport {
    let checkpoint = &input.checkpoint;
    let mut reasons = Vec::new();

    let chain_link_valid =
        non_empty(&checkpoint.previous_checkpoint_hash)
            && checkpoint.previous_checkpoint_hash == input.expected_previous_checkpoint_hash;

    let policy_version_valid =
        non_empty(&checkpoint.policy_version)
            && checkpoint.policy_version == input.expected_policy_version;

    let recovery_target_met = input
        .measured_recovery_ms
        .is_some_and(|elapsed| elapsed < input.maximum_recovery_ms);

    if !checkpoint.non_actuation_assertion {
        reasons.push("checkpoint_is_missing_non_actuation_assertion".to_owned());
    }

    if !chain_link_valid {
        reasons.push("checkpoint_chain_link_does_not_match_expected_predecessor".to_owned());
    }

    if !policy_version_valid {
        reasons.push("checkpoint_policy_version_is_not_accepted".to_owned());
    }

    if !input.merkle_root_verified {
        reasons.push("merkle_root_verification_failed".to_owned());
    }

    if !input.signature_envelope_verified {
        reasons.push("signature_envelope_verification_failed".to_owned());
    }

    if !input.local_state_reference_available {
        reasons.push("local_encrypted_state_reference_is_unavailable".to_owned());
    }

    if !recovery_target_met {
        reasons.push("recovery_target_not_met_or_not_measured".to_owned());
    }

    let integrity_evidence_complete =
        checkpoint.non_actuation_assertion
            && chain_link_valid
            && policy_version_valid
            && input.merkle_root_verified
            && input.signature_envelope_verified
            && input.local_state_reference_available;

    let assessment = match checkpoint.user_acknowledgment_state {
        UserAcknowledgmentState::NotRequested
        | UserAcknowledgmentState::Requested
        | UserAcknowledgmentState::Unavailable
            if integrity_evidence_complete =>
        {
            reasons.push("user_acknowledgment_is_required_before_continuity_confirmation".to_owned());
            ContinuityAssessment::UserAcknowledgmentRequired
        }
        UserAcknowledgmentState::Declined => {
            reasons.push("user_declined_continuity_acknowledgment".to_owned());
            ContinuityAssessment::RecoveryReviewRequired
        }
        UserAcknowledgmentState::Confirmed if integrity_evidence_complete && recovery_target_met => {
            ContinuityAssessment::IntegrityEvidenceAvailable
        }
        _ if integrity_evidence_complete => ContinuityAssessment::RecoveryReviewRequired,
        _ => ContinuityAssessment::IntegrityEvidenceInsufficient,
    };

    ContinuityVerificationReport {
        checkpoint_sequence: checkpoint.checkpoint_sequence,
        assessment,
        chain_link_valid,
        policy_version_valid,
        recovery_target_met,
        reasons,
    }
}
