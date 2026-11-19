use msfp_gateway::agent::{
    AgentCapability, AgentFacade, AgentRequest, AgentResponse,
    IDENTITY_PROOF_VERIFY, SESSION_STATUS_READ, TELEMETRY_SUMMARY_READ,
};
use msfp_gateway::{
    Capability, EphemeralKeypair, GatewaySession, HandshakeTranscript, SessionId,
    SessionLimits,
};
use std::collections::BTreeSet;

fn session() -> GatewaySession {
    let deck = EphemeralKeypair::generate().expect("deck key generation");
    let peer = EphemeralKeypair::generate().expect("peer key generation");

    let capability = Capability {
        subject: "holder".to_owned(),
        purpose: "identity_proof".to_owned(),
        allowed_operations: BTreeSet::from([
            "identity.proof.verify".to_owned(),
        ]),
        allowed_data_categories: BTreeSet::from([
            "communication_preference".to_owned(),
        ]),
        audience: "authorized_peer".to_owned(),
        expires_at_ms: 10_000,
        revocation_handle: "revocation-handle".to_owned(),
        policy_version: "v1".to_owned(),
        session_generation: 1,
    };

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
        SessionLimits {
            max_frame_bytes: 4096,
            max_session_bytes: 65_536,
            max_session_messages: 128,
            max_replay_entries: 128,
        },
        1,
    )
    .expect("session creation")
}

#[test]
fn agent_facade_allows_only_explicit_read_only_operations() {
    let session = session();

    let facade = AgentFacade::new(
        &session,
        [
            AgentCapability::read_only(SESSION_STATUS_READ, 1, 10_000),
            AgentCapability::read_only(IDENTITY_PROOF_VERIFY, 1, 10_000),
            AgentCapability::read_only(TELEMETRY_SUMMARY_READ, 1, 10_000),
        ],
        1,
    );

    assert!(matches!(
        facade.handle(AgentRequest::SessionStatusRead),
        AgentResponse::SessionStatus(_)
    ));

    assert!(matches!(
        facade.handle(AgentRequest::TelemetrySummaryRead),
        AgentResponse::Telemetry(_)
    ));

    assert!(matches!(
        facade.handle(AgentRequest::IdentityProofVerify {
            proof_digest: [9_u8; 32],
        }),
        AgentResponse::IdentityProof(_)
    ));
}

#[test]
fn agent_facade_permanently_denies_command_and_actuation_requests() {
    let session = session();

    let facade = AgentFacade::new(
        &session,
        [
            AgentCapability::read_only(SESSION_STATUS_READ, 1, 10_000),
            AgentCapability::read_only(IDENTITY_PROOF_VERIFY, 1, 10_000),
            AgentCapability::read_only(TELEMETRY_SUMMARY_READ, 1, 10_000),
        ],
        1,
    );

    assert!(matches!(
        facade.handle(AgentRequest::CommandExecute),
        AgentResponse::Denied { .. }
    ));

    assert!(matches!(
        facade.handle(AgentRequest::ActuationControl),
        AgentResponse::Denied { .. }
    ));

    assert!(matches!(
        facade.handle(AgentRequest::ConfigurationWrite),
        AgentResponse::Denied { .. }
    ));

    assert!(matches!(
        facade.handle(AgentRequest::FirmwareUpdate),
        AgentResponse::Denied { .. }
    ));

    assert!(matches!(
        facade.handle(AgentRequest::RawMemoryRead),
        AgentResponse::Denied { .. }
    ));
}
