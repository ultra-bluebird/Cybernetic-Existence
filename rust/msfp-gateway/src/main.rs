use ed25519_dalek::{Signer, SigningKey};
use msfp_gateway::agent::{
    AgentCapability, AgentFacade, AgentRequest, AgentResponse,
    IDENTITY_PROOF_VERIFY, SESSION_STATUS_READ, TELEMETRY_SUMMARY_READ,
};
use msfp_gateway::anomaly::{
    AnomalyDecision, AnomalyPolicy, AnomalyWeights, ProtocolViolations,
};
use msfp_gateway::attenuation::{
    attenuate, AttenuationResult, CapabilityScope,
};
use msfp_gateway::trust::{
    AuthorizationState, TrustDecayPolicy,
};
use msfp_gateway::{
    capability_commitment, derive_session_keys, transcript_hash,
    verify_peer_signature, Capability, EphemeralKeypair, GatewayError,
    GatewaySession, HandshakeTranscript, IncomingFrame, SessionId,
    SessionLimits, TerminationReason,
};
use rand_core::OsRng;
use std::collections::BTreeSet;
use std::error::Error;

const DEMO_NOW_MS: u64 = 1_000;
const DEMO_EXPIRES_AT_MS: u64 = 31_000;
const DEMO_GENERATION: u64 = 1;

fn main() -> Result<(), Box<dyn Error>> {
    run_session_acceptance_demo()?;
    run_replay_rejection_demo()?;
    run_capability_attenuation_demo()?;
    run_anomaly_scoring_demo()?;
    run_agent_facade_demo()?;
    run_trust_decay_demo()?;

    println!("MSFP gateway local smoke checks completed successfully.");
    Ok(())
}

fn run_session_acceptance_demo() -> Result<(), GatewayError> {
    let mut session = build_demo_session()?;

    let frame = IncomingFrame {
        session_id: session.session_id(),
        generation: session.generation(),
        sequence: 1,
        nonce: [1_u8; 32],
        operation: "identity.proof.verify",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: b"local-bounded-test-frame",
    };

    let receipt = session.accept_frame(&frame, DEMO_NOW_MS + 1)?;

    if receipt.sequence != 1
        || !session.has_external_authority()
        || session.remaining_session_messages() != 7
    {
        return Err(GatewayError::InvalidStateTransition);
    }

    println!(
        "PASS session acceptance: generation={}, sequence={}, remaining_messages={}",
        receipt.session_generation,
        receipt.sequence,
        session.remaining_session_messages()
    );

    Ok(())
}

fn run_replay_rejection_demo() -> Result<(), GatewayError> {
    let mut session = build_demo_session()?;

    let frame = IncomingFrame {
        session_id: session.session_id(),
        generation: session.generation(),
        sequence: 1,
        nonce: [2_u8; 32],
        operation: "identity.proof.verify",
        data_category: "communication_preference",
        audience: "authorized_peer",
        payload: b"replay-test-frame",
    };

    session.accept_frame(&frame, DEMO_NOW_MS + 1)?;

    match session.accept_frame(&frame, DEMO_NOW_MS + 2) {
        Err(GatewayError::ReplayDetected) => {}
        _ => return Err(GatewayError::InvalidStateTransition),
    }

    if session.has_external_authority()
        || session.termination_reason() != Some(TerminationReason::ReplayDetected)
    {
        return Err(GatewayError::InvalidStateTransition);
    }

    println!("PASS replay rejection: external authority removed.");

    Ok(())
}

fn run_capability_attenuation_demo() -> Result<(), GatewayError> {
    let request = scope(
        &[
            "identity.proof.verify",
            "telemetry.summary.read",
        ],
        &[
            "communication_preference",
            "privacy_preference",
        ],
        &[
            "authorized_peer",
            "local_service",
        ],
        30_000,
    );

    let policy = scope(
        &[
            "identity.proof.verify",
        ],
        &[
            "communication_preference",
        ],
        &[
            "authorized_peer",
        ],
        25_000,
    );

    let consent = scope(
        &[
            "identity.proof.verify",
            "audit.receipt.read",
        ],
        &[
            "communication_preference",
        ],
        &[
            "authorized_peer",
        ],
        20_000,
    );

    let purpose = scope(
        &[
            "identity.proof.verify",
        ],
        &[
            "communication_preference",
        ],
        &[
            "authorized_peer",
        ],
        15_000,
    );

    let AttenuationResult::Allowed(allowed) = attenuate(
        &request,
        &policy,
        &consent,
        &purpose,
        DEMO_NOW_MS,
    ) else {
        return Err(GatewayError::CapabilityDenied);
    };

    if allowed.operations
        != BTreeSet::from([
            "identity.proof.verify".to_owned(),
        ])
        || allowed.data_categories
            != BTreeSet::from([
                "communication_preference".to_owned(),
            ])
        || allowed.audiences
            != BTreeSet::from([
                "authorized_peer".to_owned(),
            ])
        || allowed.expires_at_ms != 15_000
    {
        return Err(GatewayError::CapabilityDenied);
    }

    println!(
        "PASS capability attenuation: scope narrowed to one operation, one category, one audience."
    );

    Ok(())
}

fn run_anomaly_scoring_demo() -> Result<(), GatewayError> {
    let policy = AnomalyPolicy {
        weights: AnomalyWeights {
            schema: 0.15,
            size: 0.10,
            replay: 0.20,
            version: 0.10,
            canonical: 0.10,
            duplicate_key: 0.10,
            unknown_field: 0.10,
            lease: 0.05,
            capability: 0.05,
            rate: 0.05,
        },
        abstain_threshold: 0.30,
        reject_threshold: 0.60,
    };

    let replay_fault = ProtocolViolations {
        schema_violation: 0.0,
        size_violation: 0.0,
        replay_violation: 1.0,
        version_violation: 0.0,
        canonical_violation: 0.0,
        duplicate_key_violation: 0.0,
        unknown_field_violation: 0.0,
        lease_violation: 0.0,
        capability_violation: 0.0,
        rate_violation: 0.0,
        authentication_failed: false,
    };

    if policy.decide(replay_fault) != AnomalyDecision::RejectAndTerminate {
        return Err(GatewayError::InvalidStateTransition);
    }

    let bounded_fault = ProtocolViolations {
        schema_violation: 0.4,
        size_violation: 0.0,
        replay_violation: 0.0,
        version_violation: 0.0,
        canonical_violation: 0.0,
        duplicate_key_violation: 0.0,
        unknown_field_violation: 0.0,
        lease_violation: 0.0,
        capability_violation: 0.0,
        rate_violation: 0.0,
        authentication_failed: false,
    };

    if policy.decide(bounded_fault) != AnomalyDecision::Allow {
        return Err(GatewayError::InvalidStateTransition);
    }

    println!(
        "PASS anomaly scoring: protocol-only hard faults override weighted scoring."
    );

    Ok(())
}

fn run_agent_facade_demo() -> Result<(), GatewayError> {
    let session = build_demo_session()?;

    let facade = AgentFacade::new(
        &session,
        [
            AgentCapability::read_only(
                SESSION_STATUS_READ,
                session.generation(),
                DEMO_EXPIRES_AT_MS,
            ),
            AgentCapability::read_only(
                IDENTITY_PROOF_VERIFY,
                session.generation(),
                DEMO_EXPIRES_AT_MS,
            ),
            AgentCapability::read_only(
                TELEMETRY_SUMMARY_READ,
                session.generation(),
                DEMO_EXPIRES_AT_MS,
            ),
        ],
        DEMO_NOW_MS,
    );

    if !matches!(
        facade.handle(AgentRequest::SessionStatusRead),
        AgentResponse::SessionStatus(_)
    ) {
        return Err(GatewayError::CapabilityDenied);
    }

    if !matches!(
        facade.handle(AgentRequest::CommandExecute),
        AgentResponse::Denied { .. }
    ) {
        return Err(GatewayError::CapabilityDenied);
    }

    if !matches!(
        facade.handle(AgentRequest::ActuationControl),
        AgentResponse::Denied { .. }
    ) {
        return Err(GatewayError::CapabilityDenied);
    }

    println!(
        "PASS agent facade: read-only operations available; command and actuation requests denied."
    );

    Ok(())
}

fn run_trust_decay_demo() -> Result<(), GatewayError> {
    let policy = TrustDecayPolicy {
        initial_confidence: 1.0,
        decay_rate_per_ms: 0.0001,
        continue_threshold: 0.2,
    };

    let active_confidence = policy.confidence_at(
        1_000,
        DEMO_EXPIRES_AT_MS,
        DEMO_NOW_MS + 1_000,
        AuthorizationState::Active,
    );

    let revoked_confidence = policy.confidence_at(
        1_000,
        DEMO_EXPIRES_AT_MS,
        DEMO_NOW_MS + 1_000,
        AuthorizationState::Revoked,
    );

    if active_confidence <= 0.0 || revoked_confidence != 0.0 {
        return Err(GatewayError::InvalidStateTransition);
    }

    println!(
        "PASS trust decay: active confidence decays; revoked confidence is zero."
    );

    Ok(())
}

fn build_demo_session() -> Result<GatewaySession, GatewayError> {
    let deck = EphemeralKeypair::generate()?;
    let peer = EphemeralKeypair::generate()?;
    let peer_signing_key = SigningKey::generate(&mut OsRng);

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
        expires_at_ms: DEMO_EXPIRES_AT_MS,
        revocation_handle: "local-demo-revocation".to_owned(),
        policy_version: "v1".to_owned(),
        session_generation: DEMO_GENERATION,
    };

    let transcript = HandshakeTranscript {
        protocol_version: "v1".to_owned(),
        session_id: SessionId([7_u8; 16]),
        session_generation: DEMO_GENERATION,
        peer_ephemeral_public: peer.public_bytes(),
        deck_ephemeral_public: deck.public_bytes(),
        peer_identity_key_commitment: [1_u8; 32],
        deck_identity_key_commitment: [2_u8; 32],
        capability_commitment: capability_commitment(&capability)?,
        policy_version: "v1".to_owned(),
        lease_expires_at_ms: DEMO_EXPIRES_AT_MS,
    };

    let digest = transcript_hash(&transcript)?;
    let signature = peer_signing_key.sign(&digest).to_bytes();

    verify_peer_signature(
        &peer_signing_key.verifying_key(),
        &transcript,
        &signature,
    )?;

    let keys = derive_session_keys(
        &deck,
        peer.public_bytes(),
        &transcript,
    )?;

    GatewaySession::new(
        transcript.session_id,
        DEMO_GENERATION,
        capability,
        keys,
        SessionLimits {
            max_frame_bytes: 1024,
            max_session_bytes: 8_192,
            max_session_messages: 8,
            max_replay_entries: 8,
        },
        DEMO_NOW_MS,
    )
}

fn scope(
    operations: &[&str],
    data_categories: &[&str],
    audiences: &[&str],
    expires_at_ms: u64,
) -> CapabilityScope {
    CapabilityScope {
        subject: "holder".to_owned(),
        purpose: "identity_proof".to_owned(),
        operations: operations
            .iter()
            .map(|value| (*value).to_owned())
            .collect(),
        data_categories: data_categories
            .iter()
            .map(|value| (*value).to_owned())
            .collect(),
        audiences: audiences
            .iter()
            .map(|value| (*value).to_owned())
            .collect(),
        expires_at_ms,
        session_generation: DEMO_GENERATION,
        policy_version: "v1".to_owned(),
    }
}
