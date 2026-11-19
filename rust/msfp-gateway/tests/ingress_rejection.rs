use msfp_gateway::{
    Capability, EphemeralKeypair, GatewayError, GatewaySession, HandshakeTranscript,
    IncomingFrame, SessionId, SessionLimits,
};
use std::collections::BTreeSet;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

struct ProtectedService {
    dispatch_count: AtomicUsize,
}

impl ProtectedService {
    fn new() -> Self {
        Self {
            dispatch_count: AtomicUsize::new(0),
        }
    }

    fn dispatch(&self, _payload: &[u8]) {
        self.dispatch_count.fetch_add(1, Ordering::AcqRel);
    }

    fn dispatch_count(&self) -> usize {
        self.dispatch_count.load(Ordering::Acquire)
    }
}

fn capability(generation: u64, expires_at_ms: u64) -> Capability {
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
        revocation_handle: "local-revocation".to_owned(),
        policy_version: "v1".to_owned(),
        session_generation: generation,
    }
}

fn limits() -> SessionLimits {
    SessionLimits {
        max_frame_bytes: 64,
        max_session_bytes: 256,
        max_session_messages: 4,
        max_replay_entries: 4,
    }
}

fn session() -> GatewaySession {
    let deck = EphemeralKeypair::generate().expect("deck key generation");
    let peer = EphemeralKeypair::generate().expect("peer key generation");
    let capability = capability(1, 10_000);

    let transcript = HandshakeTranscript {
        protocol_version: "v1".to_owned(),
        session_id: SessionId([7_u8; 16]),
        session_generation: 1,
        peer_ephemeral_public: peer.public_bytes(),
        deck_ephemeral_public: deck.public_bytes(),
        peer_identity_key_commitment: [1_u8; 32],
        deck_identity_key_commitment: [2_u8; 32],
        capability_commitment: msfp_gateway::capability_commitment(&capability)
            .expect("capability commitment"),
        policy_version: "v1".to_owned(),
        lease_expires_at_ms: 10_000,
    };

    let keys = msfp_gateway::derive_session_keys(
        &deck,
        peer.public_bytes(),
        &transcript,
    )
    .expect("key derivation");

    GatewaySession::new(
        SessionId([7_u8; 16]),
        1,
        capability,
        keys,
        limits(),
        1,
    )
    .expect("session creation")
}

fn dispatch_if_accepted(
    session: &mut GatewaySession,
    service: &ProtectedService,
    frame: &IncomingFrame<'_>,
    now_ms: u64,
) -> Result<(), GatewayError> {
    session.accept_frame(frame, now_ms)?;
    service.dispatch(frame.payload);
    Ok(())
}

#[test]
fn oversize_frame_never_reaches_protected_service() {
    let service = Arc::new(ProtectedService::new());
    let mut gateway = session();
    let payload = vec![0_u8; 65];

    let frame = IncomingFrame {
        session_id: SessionId([7_u8; 16]),
        generation: 1,
        sequence: 1,
        nonce: [1_u8; 32],
        operation: "identity.proof.verify",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: &payload,
    };

    let result = dispatch_if_accepted(
        &mut gateway,
        service.as_ref(),
        &frame,
        2,
    );

    assert!(matches!(result, Err(GatewayError::FrameTooLarge)));
    assert_eq!(service.dispatch_count(), 0);
    assert!(!gateway.has_external_authority());
}

#[test]
fn capability_escalation_never_reaches_protected_service() {
    let service = Arc::new(ProtectedService::new());
    let mut gateway = session();

    let frame = IncomingFrame {
        session_id: SessionId([7_u8; 16]),
        generation: 1,
        sequence: 1,
        nonce: [2_u8; 32],
        operation: "config.write",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: b"attempted-privilege-escalation",
    };

    let result = dispatch_if_accepted(
        &mut gateway,
        service.as_ref(),
        &frame,
        2,
    );

    assert!(matches!(result, Err(GatewayError::CapabilityDenied)));
    assert_eq!(service.dispatch_count(), 0);
    assert!(!gateway.has_external_authority());
}

#[test]
fn wrong_session_generation_never_reaches_protected_service() {
    let service = Arc::new(ProtectedService::new());
    let mut gateway = session();

    let frame = IncomingFrame {
        session_id: SessionId([7_u8; 16]),
        generation: 2,
        sequence: 1,
        nonce: [3_u8; 32],
        operation: "identity.proof.verify",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: b"wrong-generation",
    };

    let result = dispatch_if_accepted(
        &mut gateway,
        service.as_ref(),
        &frame,
        2,
    );

    assert!(matches!(result, Err(GatewayError::GenerationMismatch)));
    assert_eq!(service.dispatch_count(), 0);
    assert!(gateway.has_external_authority());
}

#[test]
fn replayed_frame_never_reaches_protected_service_twice() {
    let service = Arc::new(ProtectedService::new());
    let mut gateway = session();

    let frame = IncomingFrame {
        session_id: SessionId([7_u8; 16]),
        generation: 1,
        sequence: 1,
        nonce: [4_u8; 32],
        operation: "identity.proof.verify",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: b"first-frame",
    };

    dispatch_if_accepted(
        &mut gateway,
        service.as_ref(),
        &frame,
        2,
    )
    .expect("first frame accepted");

    let replay = dispatch_if_accepted(
        &mut gateway,
        service.as_ref(),
        &frame,
        3,
    );

    assert!(matches!(replay, Err(GatewayError::ReplayDetected)));
    assert_eq!(service.dispatch_count(), 1);
    assert!(!gateway.has_external_authority());
}
