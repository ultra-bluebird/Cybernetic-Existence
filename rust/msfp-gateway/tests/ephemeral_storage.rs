use msfp_gateway::ephemeral::EphemeralSessionStore;
use msfp_gateway::{
    Capability, EphemeralKeypair, GatewaySession, HandshakeTranscript,
    SessionId, SessionLimits,
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
        revocation_handle: "CANARY_REVOCATION_HANDLE_DO_NOT_PERSIST".to_owned(),
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
fn ephemeral_store_discards_session_and_preserves_no_active_authority() {
    let mut store = EphemeralSessionStore::empty();

    store.insert(session())
        .expect("empty store accepts one session");

    assert!(store.snapshot().session_present);
    assert!(store.snapshot().external_authority_active);

    store.discard();

    assert!(store.is_empty());
    assert!(!store.snapshot().external_authority_active);
}

#[test]
fn teardown_receipt_does_not_contain_raw_canary_value() {
    let mut store = EphemeralSessionStore::empty();

    store.insert(session())
        .expect("session insertion");

    let session = store.session_mut()
        .expect("session present");

    let receipt = session
        .revoke(msfp_gateway::TerminationReason::ExplicitRevocation)
        .expect("teardown receipt");

    let rendered = format!("{receipt:?}");

    assert!(!rendered.contains("CANARY_REVOCATION_HANDLE_DO_NOT_PERSIST"));
}
