use ed25519_dalek::{Signer, SigningKey};
use msfp_gateway::{
    capability_commitment, derive_session_keys, transcript_hash, verify_peer_signature,
    Capability, EphemeralKeypair, GatewayError, GatewaySession, HandshakeTranscript,
    IncomingFrame, SessionId, SessionLimits, SessionState, TerminationReason,
};
use rand_core::OsRng;
use std::collections::BTreeSet;

fn test_capability(
    generation: u64,
    expires_at_ms: u64,
) -> Capability {
    Capability {
        subject: "holder".to_owned(),
        purpose: "identity_proof".to_owned(),
        allowed_operations: BTreeSet::from([
            "identity.proof.verify".to_owned(),
        ]),
        allowed_data_categories: BTreeSet::from([
            "communication_preference".to_owned(),
        ]),
        audience: "authorized_peer".to_owned(),
        expires_at_ms,
        revocation_handle: "local-revocation-handle".to_owned(),
        policy_version: "v1".to_owned(),
        session_generation: generation,
    }
}

fn test_limits() -> SessionLimits {
    SessionLimits {
        max_frame_bytes: 1024,
        max_session_bytes: 4096,
        max_session_messages: 4,
        max_replay_entries: 4,
    }
}

fn test_transcript(
    peer_public: [u8; 32],
    deck_public: [u8; 32],
    capability: &Capability,
    generation: u64,
    expires_at_ms: u64,
) -> HandshakeTranscript {
    HandshakeTranscript {
        protocol_version: "v1".to_owned(),
        session_id: SessionId([7_u8; 16]),
        session_generation: generation,
        peer_ephemeral_public: peer_public,
        deck_ephemeral_public: deck_public,
        peer_identity_key_commitment: [1_u8; 32],
        deck_identity_key_commitment: [2_u8; 32],
        capability_commitment: capability_commitment(capability)
            .expect("capability commitment"),
        policy_version: "v1".to_owned(),
        lease_expires_at_ms: expires_at_ms,
    }
}

fn new_session(
    generation: u64,
    expires_at_ms: u64,
) -> GatewaySession {
    let deck = EphemeralKeypair::generate().expect("deck key generation");
    let peer = EphemeralKeypair::generate().expect("peer key generation");
    let capability = test_capability(generation, expires_at_ms);
    let transcript = test_transcript(
        peer.public_bytes(),
        deck.public_bytes(),
        &capability,
        generation,
        expires_at_ms,
    );

    let keys = derive_session_keys(
        &deck,
        peer.public_bytes(),
        &transcript,
    )
    .expect("key derivation");

    GatewaySession::new(
        SessionId([7_u8; 16]),
        generation,
        capability,
        keys,
        test_limits(),
        1,
    )
    .expect("session creation")
}

#[test]
fn accepted_frame_requires_full_session_binding() {
    let mut session = new_session(1, 10_000);

    let frame = IncomingFrame {
        session_id: SessionId([7_u8; 16]),
        generation: 1,
        sequence: 1,
        nonce: [9_u8; 32],
        operation: "identity.proof.verify",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: b"bounded-test-payload",
    };

    let receipt = session
        .accept_frame(&frame, 2)
        .expect("valid frame accepted");

    assert_eq!(receipt.sequence, 1);
    assert_eq!(session.state(), SessionState::Active);
    assert!(session.has_external_authority());
}

#[test]
fn stale_sequence_revokes_current_session() {
    let mut session = new_session(1, 10_000);

    let first = IncomingFrame {
        session_id: SessionId([7_u8; 16]),
        generation: 1,
        sequence: 1,
        nonce: [9_u8; 32],
        operation: "identity.proof.verify",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: b"first",
    };

    session
        .accept_frame(&first, 2)
        .expect("first frame accepted");

    let stale = IncomingFrame {
        nonce: [10_u8; 32],
        payload: b"duplicate-sequence",
        ..first
    };

    let result = session.accept_frame(&stale, 3);

    assert!(matches!(result, Err(GatewayError::ReplayDetected)));
    assert_eq!(session.state(), SessionState::Revoked);
    assert!(!session.has_external_authority());
    assert_eq!(
        session.termination_reason(),
        Some(TerminationReason::ReplayDetected)
    );
}

#[test]
fn wrong_generation_cannot_reach_active_session() {
    let mut session = new_session(1, 10_000);

    let frame = IncomingFrame {
        session_id: SessionId([7_u8; 16]),
        generation: 2,
        sequence: 1,
        nonce: [11_u8; 32],
        operation: "identity.proof.verify",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: b"wrong-generation",
    };

    let result = session.accept_frame(&frame, 2);

    assert!(matches!(result, Err(GatewayError::GenerationMismatch)));
    assert_eq!(session.state(), SessionState::Active);
}

#[test]
fn expired_lease_removes_external_authority() {
    let mut session = new_session(1, 100);

    let frame = IncomingFrame {
        session_id: SessionId([7_u8; 16]),
        generation: 1,
        sequence: 1,
        nonce: [4_u8; 32],
        operation: "identity.proof.verify",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: b"expired-session-frame",
    };

    let result = session.accept_frame(&frame, 100);

    assert!(matches!(result, Err(GatewayError::LeaseExpired)));
    assert_eq!(session.state(), SessionState::Expired);
    assert!(!session.has_external_authority());
    assert_eq!(
        session.termination_reason(),
        Some(TerminationReason::LeaseExpired)
    );
}

#[test]
fn oversized_frame_triggers_fail_closed_termination() {
    let mut session = new_session(1, 10_000);
    let payload = vec![1_u8; 1025];

    let frame = IncomingFrame {
        session_id: SessionId([7_u8; 16]),
        generation: 1,
        sequence: 1,
        nonce: [2_u8; 32],
        operation: "identity.proof.verify",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: &payload,
    };

    let result = session.accept_frame(&frame, 2);

    assert!(matches!(result, Err(GatewayError::FrameTooLarge)));
    assert_eq!(session.state(), SessionState::Revoked);
    assert!(!session.has_external_authority());
}

#[test]
fn transcript_signature_must_bind_exact_transcript() {
    let signing_key = SigningKey::generate(&mut OsRng);
    let deck = EphemeralKeypair::generate().expect("deck key generation");
    let peer = EphemeralKeypair::generate().expect("peer key generation");
    let capability = test_capability(1, 20_000);
    let transcript = test_transcript(
        peer.public_bytes(),
        deck.public_bytes(),
        &capability,
        1,
        20_000,
    );

    let digest = transcript_hash(&transcript).expect("transcript hash");
    let signature = signing_key.sign(&digest).to_bytes();

    verify_peer_signature(
        &signing_key.verifying_key(),
        &transcript,
        &signature,
    )
    .expect("signature validates");

    let mut altered = transcript.clone();
    altered.lease_expires_at_ms = 20_001;

    let result = verify_peer_signature(
        &signing_key.verifying_key(),
        &altered,
        &signature,
    );

    assert!(matches!(result, Err(GatewayError::PeerSignatureInvalid)));
}
