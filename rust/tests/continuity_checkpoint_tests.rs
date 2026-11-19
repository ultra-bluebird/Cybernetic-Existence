use augmented_hub::continuity::checkpoint::{
    verify_checkpoint, ContinuityAssessment, ContinuityCheckpoint, ContinuityVerificationInput,
    RecoveryMode, UserAcknowledgmentState,
};

fn checkpoint() -> ContinuityCheckpoint {
    ContinuityCheckpoint {
        checkpoint_sequence: 7,
        created_at_unix_ms: 1_800_000_000_000,
        previous_checkpoint_hash: "prior-checkpoint-commitment".to_owned(),
        protected_state_commitment: "protected-state-commitment".to_owned(),
        encrypted_state_reference: "local-encrypted-state-reference".to_owned(),
        merkle_root: "merkle-root-commitment".to_owned(),
        policy_version: "continuity-policy-v1".to_owned(),
        recovery_mode: RecoveryMode::LocalFallback,
        user_acknowledgment_state: UserAcknowledgmentState::Confirmed,
        non_actuation_assertion: true,
    }
}

fn verification_input() -> ContinuityVerificationInput {
    ContinuityVerificationInput {
        expected_previous_checkpoint_hash: "prior-checkpoint-commitment".to_owned(),
        expected_policy_version: "continuity-policy-v1".to_owned(),
        checkpoint: checkpoint(),
        merkle_root_verified: true,
        signature_envelope_verified: true,
        local_state_reference_available: true,
        measured_recovery_ms: Some(150),
        maximum_recovery_ms: 200,
    }
}

#[test]
fn complete_evidence_and_confirmation_are_reported_as_available() {
    let report = verify_checkpoint(&verification_input());

    assert_eq!(
        report.assessment,
        ContinuityAssessment::IntegrityEvidenceAvailable
    );
    assert!(report.chain_link_valid);
    assert!(report.policy_version_valid);
    assert!(report.recovery_target_met);
}

#[test]
fn user_confirmation_is_required_before_continuity_confirmation() {
    let mut input = verification_input();
    input.checkpoint.user_acknowledgment_state = UserAcknowledgmentState::Requested;

    let report = verify_checkpoint(&input);

    assert_eq!(
        report.assessment,
        ContinuityAssessment::UserAcknowledgmentRequired
    );
}

#[test]
fn invalid_merkle_evidence_fails_closed() {
    let mut input = verification_input();
    input.merkle_root_verified = false;

    let report = verify_checkpoint(&input);

    assert_eq!(
        report.assessment,
        ContinuityAssessment::IntegrityEvidenceInsufficient
    );
    assert!(
        report
            .reasons
            .contains(&"merkle_root_verification_failed".to_owned())
    );
}

#[test]
fn recovery_duration_at_limit_is_not_a_pass() {
    let mut input = verification_input();
    input.measured_recovery_ms = Some(200);

    let report = verify_checkpoint(&input);

    assert_ne!(
        report.assessment,
        ContinuityAssessment::IntegrityEvidenceAvailable
    );
    assert!(!report.recovery_target_met);
}

#[test]
fn missing_non_actuation_assertion_fails_closed() {
    let mut input = verification_input();
    input.checkpoint.non_actuation_assertion = false;

    let report = verify_checkpoint(&input);

    assert_eq!(
        report.assessment,
        ContinuityAssessment::IntegrityEvidenceInsufficient
    );
}
