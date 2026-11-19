#![doc = include_str!("../README.md")]

pub mod agent;
pub mod anomaly;
pub mod attenuation;
pub mod audit;
pub mod consent;
pub mod disclosure;
pub mod enclosure;
pub mod ephemeral;
pub mod frame;
pub mod local_control;
pub mod provenance;
pub mod quorum;
pub mod swarm;
pub mod trust;
pub mod watchdog;

use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use getrandom::getrandom;
use hkdf::Hkdf;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;
use std::fmt;
use thiserror::Error;
use x25519_dalek::{PublicKey, StaticSecret};
use zeroize::{Zeroize, ZeroizeOnDrop};

pub const PROTOCOL_LABEL: &[u8] = b"MSFP-GATEWAY-v1";
pub const SESSION_KEY_BYTES: usize = 32;
pub const NONCE_BYTES: usize = 32;
pub const SESSION_ID_BYTES: usize = 16;

const TRANSCRIPT_VERSION: u16 = 1;
const MAX_TEXT_FIELD_BYTES: usize = 4096;

#[derive(Debug, Error)]
pub enum GatewayError {
    #[error("randomness source unavailable")]
    RandomnessUnavailable,
    #[error("invalid handshake transcript")]
    InvalidTranscript,
    #[error("handshake transcript does not match the admitted capability")]
    TranscriptCapabilityMismatch,
    #[error("handshake transcript is too large")]
    TranscriptTooLarge,
    #[error("handshake transcript contains an invalid text field")]
    InvalidTranscriptText,
    #[error("peer signature verification failed")]
    PeerSignatureInvalid,
    #[error("deck signature verification failed")]
    DeckSignatureInvalid,
    #[error("key derivation failed")]
    KeyDerivationFailed,
    #[error("session is not active")]
    SessionInactive,
    #[error("session lease has expired")]
    LeaseExpired,
    #[error("session capability does not permit the requested operation")]
    CapabilityDenied,
    #[error("session capability is malformed")]
    InvalidCapability,
    #[error("session generation does not match the active capability")]
    GenerationMismatch,
    #[error("replayed, duplicated, or stale message")]
    ReplayDetected,
    #[error("frame is larger than the configured bound")]
    FrameTooLarge,
    #[error("frame exceeds the configured session budget")]
    RateLimited,
    #[error("frame message count exceeds the configured session budget")]
    MessageLimitExceeded,
    #[error("frame sequence value is reserved")]
    InvalidSequence,
    #[error("session state transition is not permitted")]
    InvalidStateTransition,
    #[error("teardown reason code is invalid")]
    InvalidReasonCode,
    #[error("integer conversion failed")]
    IntegerConversion,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd, Hash, Serialize, Deserialize)]
pub struct SessionId(pub [u8; SESSION_ID_BYTES]);

impl SessionId {
    pub fn generate() -> Result<Self, GatewayError> {
        let mut bytes = [0_u8; SESSION_ID_BYTES];
        getrandom(&mut bytes).map_err(|_| GatewayError::RandomnessUnavailable)?;
        Ok(Self(bytes))
    }

    pub const fn as_bytes(&self) -> &[u8; SESSION_ID_BYTES] {
        &self.0
    }
}

impl fmt::Display for SessionId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        for byte in self.0 {
            write!(formatter, "{byte:02x}")?;
        }

        Ok(())
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum SessionState {
    Cold,
    Active,
    Revoked,
    Expired,
}

impl SessionState {
    pub const fn is_terminal(self) -> bool {
        matches!(self, Self::Cold | Self::Revoked | Self::Expired)
    }

    pub const fn has_external_authority(self) -> bool {
        matches!(self, Self::Active)
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum TerminationReason {
    LeaseExpired,
    ExplicitRevocation,
    PolicyRevocation,
    IntegrityFailure,
    ReplayDetected,
    CapabilityDenied,
    FrameBoundExceeded,
    BudgetExceeded,
    WatchdogExpiry,
    LocalShutdown,
}

impl TerminationReason {
    pub const fn as_reason_code(self) -> &'static str {
        match self {
            Self::LeaseExpired => "lease_expired",
            Self::ExplicitRevocation => "explicit_revocation",
            Self::PolicyRevocation => "policy_revocation",
            Self::IntegrityFailure => "integrity_failure",
            Self::ReplayDetected => "replay_detected",
            Self::CapabilityDenied => "capability_denied",
            Self::FrameBoundExceeded => "frame_bound_exceeded",
            Self::BudgetExceeded => "budget_exceeded",
            Self::WatchdogExpiry => "watchdog_expiry",
            Self::LocalShutdown => "local_shutdown",
        }
    }

    pub const fn results_in_expiry(self) -> bool {
        matches!(self, Self::LeaseExpired | Self::WatchdogExpiry)
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct Capability {
    pub subject: String,
    pub purpose: String,
    pub allowed_operations: BTreeSet<String>,
    pub allowed_data_categories: BTreeSet<String>,
    pub audience: String,
    pub expires_at_ms: u64,
    pub revocation_handle: String,
    pub policy_version: String,
    pub session_generation: u64,
}

impl Capability {
    pub fn validate(
        &self,
        expected_generation: u64,
    ) -> Result<(), GatewayError> {
        if self.subject.is_empty()
            || self.purpose.is_empty()
            || self.audience.is_empty()
            || self.revocation_handle.is_empty()
            || self.policy_version.is_empty()
            || self.allowed_operations.is_empty()
            || self.allowed_data_categories.is_empty()
        {
            return Err(GatewayError::InvalidCapability);
        }

        if self.session_generation == 0 || self.session_generation != expected_generation {
            return Err(GatewayError::GenerationMismatch);
        }

        validate_text(&self.subject)?;
        validate_text(&self.purpose)?;
        validate_text(&self.audience)?;
        validate_text(&self.revocation_handle)?;
        validate_text(&self.policy_version)?;

        for operation in &self.allowed_operations {
            validate_text(operation)?;
        }

        for data_category in &self.allowed_data_categories {
            validate_text(data_category)?;
        }

        Ok(())
    }

    pub fn permits(
        &self,
        generation: u64,
        operation: &str,
        data_category: &str,
        audience: &str,
        now_ms: u64,
    ) -> Result<(), GatewayError> {
        self.validate(generation)?;

        if now_ms >= self.expires_at_ms {
            return Err(GatewayError::LeaseExpired);
        }

        if generation != self.session_generation {
            return Err(GatewayError::GenerationMismatch);
        }

        if audience != self.audience
            || !self.allowed_operations.contains(operation)
            || !self.allowed_data_categories.contains(data_category)
        {
            return Err(GatewayError::CapabilityDenied);
        }

        Ok(())
    }

    pub fn clear_sensitive_runtime_fields(&mut self) {
        self.allowed_operations.clear();
        self.allowed_data_categories.clear();
        self.revocation_handle.zeroize();
        self.revocation_handle.clear();
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct HandshakeTranscript {
    pub protocol_version: String,
    pub session_id: SessionId,
    pub session_generation: u64,
    pub peer_ephemeral_public: [u8; SESSION_KEY_BYTES],
    pub deck_ephemeral_public: [u8; SESSION_KEY_BYTES],
    pub peer_identity_key_commitment: [u8; SESSION_KEY_BYTES],
    pub deck_identity_key_commitment: [u8; SESSION_KEY_BYTES],
    pub capability_commitment: [u8; SESSION_KEY_BYTES],
    pub policy_version: String,
    pub lease_expires_at_ms: u64,
}

impl HandshakeTranscript {
    pub fn validate(&self) -> Result<(), GatewayError> {
        if self.protocol_version.is_empty()
            || self.policy_version.is_empty()
            || self.session_generation == 0
            || self.lease_expires_at_ms == 0
        {
            return Err(GatewayError::InvalidTranscript);
        }

        validate_text(&self.protocol_version)?;
        validate_text(&self.policy_version)?;

        if self.peer_ephemeral_public == [0_u8; SESSION_KEY_BYTES]
            || self.deck_ephemeral_public == [0_u8; SESSION_KEY_BYTES]
            || self.peer_identity_key_commitment == [0_u8; SESSION_KEY_BYTES]
            || self.deck_identity_key_commitment == [0_u8; SESSION_KEY_BYTES]
            || self.capability_commitment == [0_u8; SESSION_KEY_BYTES]
        {
            return Err(GatewayError::InvalidTranscript);
        }

        Ok(())
    }

    pub fn validate_capability(
        &self,
        capability: &Capability,
    ) -> Result<(), GatewayError> {
        capability.validate(self.session_generation)?;

        if self.session_generation != capability.session_generation
            || self.policy_version != capability.policy_version
            || self.lease_expires_at_ms != capability.expires_at_ms
            || self.capability_commitment != capability_commitment(capability)?
        {
            return Err(GatewayError::TranscriptCapabilityMismatch);
        }

        Ok(())
    }
}

#[derive(Debug, Zeroize, ZeroizeOnDrop)]
pub struct SessionKeys {
    transport_key: [u8; SESSION_KEY_BYTES],
    audit_key: [u8; SESSION_KEY_BYTES],
    replay_key: [u8; SESSION_KEY_BYTES],
    capability_binding_key: [u8; SESSION_KEY_BYTES],
}

impl SessionKeys {
    pub const fn transport_key(&self) -> &[u8; SESSION_KEY_BYTES] {
        &self.transport_key
    }

    pub const fn audit_key(&self) -> &[u8; SESSION_KEY_BYTES] {
        &self.audit_key
    }

    pub const fn replay_key(&self) -> &[u8; SESSION_KEY_BYTES] {
        &self.replay_key
    }

    pub const fn capability_binding_key(&self) -> &[u8; SESSION_KEY_BYTES] {
        &self.capability_binding_key
    }
}

#[derive(Debug, Zeroize, ZeroizeOnDrop)]
pub struct EphemeralKeypair {
    secret: StaticSecret,
    #[zeroize(skip)]
    public: PublicKey,
}

impl EphemeralKeypair {
    pub fn generate() -> Result<Self, GatewayError> {
        let mut secret_bytes = [0_u8; SESSION_KEY_BYTES];

        getrandom(&mut secret_bytes).map_err(|_| GatewayError::RandomnessUnavailable)?;

        let secret = StaticSecret::from(secret_bytes);
        secret_bytes.zeroize();

        let public = PublicKey::from(&secret);

        Ok(Self { secret, public })
    }

    pub const fn public_bytes(&self) -> [u8; SESSION_KEY_BYTES] {
        self.public.to_bytes()
    }

    fn shared_secret(
        &self,
        peer_public: [u8; SESSION_KEY_BYTES],
    ) -> Result<[u8; SESSION_KEY_BYTES], GatewayError> {
        if peer_public == [0_u8; SESSION_KEY_BYTES] {
            return Err(GatewayError::InvalidTranscript);
        }

        let peer = PublicKey::from(peer_public);
        let shared = self.secret.diffie_hellman(&peer).to_bytes();

        if shared == [0_u8; SESSION_KEY_BYTES] {
            return Err(GatewayError::KeyDerivationFailed);
        }

        Ok(shared)
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SessionLimits {
    pub max_frame_bytes: usize,
    pub max_session_bytes: u64,
    pub max_session_messages: u64,
    pub max_replay_entries: usize,
}

impl SessionLimits {
    pub fn validate(&self) -> Result<(), GatewayError> {
        if self.max_frame_bytes == 0
            || self.max_session_bytes == 0
            || self.max_session_messages == 0
            || self.max_replay_entries == 0
        {
            return Err(GatewayError::RateLimited);
        }

        let max_frame_bytes =
            u64::try_from(self.max_frame_bytes).map_err(|_| GatewayError::IntegerConversion)?;

        if max_frame_bytes > self.max_session_bytes {
            return Err(GatewayError::RateLimited);
        }

        Ok(())
    }
}

#[derive(Debug)]
pub struct GatewaySession {
    session_id: SessionId,
    generation: u64,
    capability: Capability,
    state: SessionState,
    last_received_sequence: Option<u64>,
    seen_nonce_commitments: BTreeSet<[u8; SESSION_KEY_BYTES]>,
    consumed_bytes: u64,
    consumed_messages: u64,
    limits: SessionLimits,
    keys: SessionKeys,
    termination_reason: Option<TerminationReason>,
}

#[derive(Clone, Debug)]
pub struct IncomingFrame<'a> {
    pub session_id: SessionId,
    pub generation: u64,
    pub sequence: u64,
    pub nonce: [u8; NONCE_BYTES],
    pub operation: &'a str,
    pub data_category: &'a str,
    pub audience: &'a str,
    pub payload: &'a [u8],
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct AcceptanceReceipt {
    pub session_id_commitment: [u8; SESSION_KEY_BYTES],
    pub session_generation: u64,
    pub sequence: u64,
    pub policy_version: String,
    pub consumed_bytes: u64,
    pub consumed_messages: u64,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct TeardownReceipt {
    pub session_id_commitment: [u8; SESSION_KEY_BYTES],
    pub session_generation: u64,
    pub reason_code: String,
    pub key_handles_invalidated: bool,
    pub capability_revoked: bool,
    pub policy_version: String,
}

pub fn canonical_transcript_bytes(
    transcript: &HandshakeTranscript,
) -> Result<Vec<u8>, GatewayError> {
    transcript.validate()?;

    let protocol_version = transcript.protocol_version.as_bytes();
    let policy_version = transcript.policy_version.as_bytes();

    if protocol_version.len() > u16::MAX as usize || policy_version.len() > u16::MAX as usize {
        return Err(GatewayError::TranscriptTooLarge);
    }

    let capacity = PROTOCOL_LABEL
        .len()
        .checked_add(2)
        .and_then(|value| value.checked_add(2))
        .and_then(|value| value.checked_add(protocol_version.len()))
        .and_then(|value| value.checked_add(SESSION_ID_BYTES))
        .and_then(|value| value.checked_add(8))
        .and_then(|value| value.checked_add(SESSION_KEY_BYTES * 5))
        .and_then(|value| value.checked_add(2))
        .and_then(|value| value.checked_add(policy_version.len()))
        .and_then(|value| value.checked_add(8))
        .ok_or(GatewayError::TranscriptTooLarge)?;

    let mut encoded = Vec::with_capacity(capacity);

    encoded.extend_from_slice(PROTOCOL_LABEL);
    encoded.extend_from_slice(&TRANSCRIPT_VERSION.to_be_bytes());
    append_length_prefixed(&mut encoded, protocol_version)?;
    encoded.extend_from_slice(transcript.session_id.as_bytes());
    encoded.extend_from_slice(&transcript.session_generation.to_be_bytes());
    encoded.extend_from_slice(&transcript.peer_ephemeral_public);
    encoded.extend_from_slice(&transcript.deck_ephemeral_public);
    encoded.extend_from_slice(&transcript.peer_identity_key_commitment);
    encoded.extend_from_slice(&transcript.deck_identity_key_commitment);
    encoded.extend_from_slice(&transcript.capability_commitment);
    append_length_prefixed(&mut encoded, policy_version)?;
    encoded.extend_from_slice(&transcript.lease_expires_at_ms.to_be_bytes());

    Ok(encoded)
}

pub fn transcript_hash(
    transcript: &HandshakeTranscript,
) -> Result<[u8; SESSION_KEY_BYTES], GatewayError> {
    let encoded = canonical_transcript_bytes(transcript)?;
    Ok(Sha256::digest(encoded).into())
}

pub fn capability_commitment(
    capability: &Capability,
) -> Result<[u8; SESSION_KEY_BYTES], GatewayError> {
    capability.validate(capability.session_generation)?;

    let mut encoded = Vec::new();

    encoded.extend_from_slice(PROTOCOL_LABEL);
    encoded.extend_from_slice(b":capability:v1:");
    append_length_prefixed(&mut encoded, capability.subject.as_bytes())?;
    append_length_prefixed(&mut encoded, capability.purpose.as_bytes())?;
    append_string_set(&mut encoded, &capability.allowed_operations)?;
    append_string_set(&mut encoded, &capability.allowed_data_categories)?;
    append_length_prefixed(&mut encoded, capability.audience.as_bytes())?;
    encoded.extend_from_slice(&capability.expires_at_ms.to_be_bytes());
    append_length_prefixed(&mut encoded, capability.revocation_handle.as_bytes())?;
    append_length_prefixed(&mut encoded, capability.policy_version.as_bytes())?;
    encoded.extend_from_slice(&capability.session_generation.to_be_bytes());

    Ok(Sha256::digest(encoded).into())
}

pub fn verify_peer_signature(
    peer_identity_key: &VerifyingKey,
    transcript: &HandshakeTranscript,
    signature_bytes: &[u8; 64],
) -> Result<(), GatewayError> {
    verify_transcript_signature(
        peer_identity_key,
        transcript,
        signature_bytes,
        GatewayError::PeerSignatureInvalid,
    )
}

pub fn verify_deck_signature(
    deck_identity_key: &VerifyingKey,
    transcript: &HandshakeTranscript,
    signature_bytes: &[u8; 64],
) -> Result<(), GatewayError> {
    verify_transcript_signature(
        deck_identity_key,
        transcript,
        signature_bytes,
        GatewayError::DeckSignatureInvalid,
    )
}

pub fn derive_session_keys(
    deck_ephemeral: &EphemeralKeypair,
    peer_ephemeral_public: [u8; SESSION_KEY_BYTES],
    transcript: &HandshakeTranscript,
) -> Result<SessionKeys, GatewayError> {
    transcript.validate()?;

    if deck_ephemeral.public_bytes() != transcript.deck_ephemeral_public
        || peer_ephemeral_public != transcript.peer_ephemeral_public
    {
        return Err(GatewayError::InvalidTranscript);
    }

    let mut shared_secret = deck_ephemeral.shared_secret(peer_ephemeral_public)?;
    let transcript_digest = transcript_hash(transcript)?;
    let session_context = canonical_transcript_bytes(transcript)?;

    let hkdf = Hkdf::<Sha256>::new(Some(&transcript_digest), &shared_secret);
    shared_secret.zeroize();

    let mut transport_key = [0_u8; SESSION_KEY_BYTES];
    let mut audit_key = [0_u8; SESSION_KEY_BYTES];
    let mut replay_key = [0_u8; SESSION_KEY_BYTES];
    let mut capability_binding_key = [0_u8; SESSION_KEY_BYTES];

    expand_label(
        &hkdf,
        b"transport",
        &session_context,
        &mut transport_key,
    )?;
    expand_label(
        &hkdf,
        b"audit",
        &session_context,
        &mut audit_key,
    )?;
    expand_label(
        &hkdf,
        b"replay",
        &session_context,
        &mut replay_key,
    )?;
    expand_label(
        &hkdf,
        b"capability-binding",
        &session_context,
        &mut capability_binding_key,
    )?;

    Ok(SessionKeys {
        transport_key,
        audit_key,
        replay_key,
        capability_binding_key,
    })
}

impl GatewaySession {
    pub fn new(
        session_id: SessionId,
        generation: u64,
        capability: Capability,
        keys: SessionKeys,
        limits: SessionLimits,
        now_ms: u64,
    ) -> Result<Self, GatewayError> {
        if generation == 0 {
            return Err(GatewayError::GenerationMismatch);
        }

        limits.validate()?;
        capability.validate(generation)?;

        if capability.expires_at_ms <= now_ms {
            return Err(GatewayError::LeaseExpired);
        }

        Ok(Self {
            session_id,
            generation,
            capability,
            state: SessionState::Active,
            last_received_sequence: None,
            seen_nonce_commitments: BTreeSet::new(),
            consumed_bytes: 0,
            consumed_messages: 0,
            limits,
            keys,
            termination_reason: None,
        })
    }

    pub fn new_bound(
        transcript: &HandshakeTranscript,
        capability: Capability,
        keys: SessionKeys,
        limits: SessionLimits,
        now_ms: u64,
    ) -> Result<Self, GatewayError> {
        transcript.validate_capability(&capability)?;

        Self::new(
            transcript.session_id,
            transcript.session_generation,
            capability,
            keys,
            limits,
            now_ms,
        )
    }

    pub const fn session_id(&self) -> SessionId {
        self.session_id
    }

    pub const fn generation(&self) -> u64 {
        self.generation
    }

    pub const fn state(&self) -> SessionState {
        self.state
    }

    pub const fn has_external_authority(&self) -> bool {
        self.state.has_external_authority()
    }

    pub const fn is_active(&self) -> bool {
        self.state == SessionState::Active
    }

    pub const fn termination_reason(&self) -> Option<TerminationReason> {
        self.termination_reason
    }

    pub const fn remaining_session_bytes(&self) -> u64 {
        self.limits
            .max_session_bytes
            .saturating_sub(self.consumed_bytes)
    }

    pub const fn remaining_session_messages(&self) -> u64 {
        self.limits
            .max_session_messages
            .saturating_sub(self.consumed_messages)
    }

    pub fn accept_frame(
        &mut self,
        frame: &IncomingFrame<'_>,
        now_ms: u64,
    ) -> Result<AcceptanceReceipt, GatewayError> {
        self.ensure_active()?;

        if now_ms >= self.capability.expires_at_ms {
            self.terminate(TerminationReason::LeaseExpired);
            return Err(GatewayError::LeaseExpired);
        }

        self.validate_frame_binding(frame)?;
        self.validate_frame_bounds(frame)?;
        self.validate_capability(frame, now_ms)?;
        self.validate_sequence(frame)?;
        self.validate_budget(frame)?;

        let nonce_commitment = nonce_commitment(
            self.keys.replay_key(),
            &self.session_id,
            self.generation,
            frame.sequence,
            &frame.nonce,
        );

        if self.seen_nonce_commitments.contains(&nonce_commitment) {
            self.terminate(TerminationReason::ReplayDetected);
            return Err(GatewayError::ReplayDetected);
        }

        let frame_bytes =
            u64::try_from(frame.payload.len()).map_err(|_| GatewayError::IntegerConversion)?;

        self.last_received_sequence = Some(frame.sequence);
        self.seen_nonce_commitments.insert(nonce_commitment);
        self.consumed_bytes = self
            .consumed_bytes
            .checked_add(frame_bytes)
            .ok_or(GatewayError::RateLimited)?;
        self.consumed_messages = self
            .consumed_messages
            .checked_add(1)
            .ok_or(GatewayError::MessageLimitExceeded)?;

        Ok(AcceptanceReceipt {
            session_id_commitment: self.session_id_commitment(),
            session_generation: self.generation,
            sequence: frame.sequence,
            policy_version: self.capability.policy_version.clone(),
            consumed_bytes: self.consumed_bytes,
            consumed_messages: self.consumed_messages,
        })
    }

    pub fn revoke(
        &mut self,
        reason: TerminationReason,
    ) -> Result<TeardownReceipt, GatewayError> {
        if matches!(
            reason,
            TerminationReason::LeaseExpired | TerminationReason::WatchdogExpiry
        ) {
            return Err(GatewayError::InvalidReasonCode);
        }

        self.terminate(reason);
        Ok(self.teardown_receipt())
    }

    pub fn expire_if_needed(
        &mut self,
        now_ms: u64,
    ) -> Option<TeardownReceipt> {
        if self.state != SessionState::Active || now_ms < self.capability.expires_at_ms {
            return None;
        }

        self.terminate(TerminationReason::LeaseExpired);
        Some(self.teardown_receipt())
    }

    pub fn watchdog_expire(
        &mut self,
    ) -> Option<TeardownReceipt> {
        if self.state != SessionState::Active {
            return None;
        }

        self.terminate(TerminationReason::WatchdogExpiry);
        Some(self.teardown_receipt())
    }

    pub fn teardown_receipt(&self) -> TeardownReceipt {
        TeardownReceipt {
            session_id_commitment: self.session_id_commitment(),
            session_generation: self.generation,
            reason_code: self
                .termination_reason
                .unwrap_or(TerminationReason::LocalShutdown)
                .as_reason_code()
                .to_owned(),
            key_handles_invalidated: self.state.is_terminal(),
            capability_revoked: self.state.is_terminal(),
            policy_version: self.capability.policy_version.clone(),
        }
    }

    pub fn capability_policy_version(&self) -> &str {
        &self.capability.policy_version
    }

    fn ensure_active(&self) -> Result<(), GatewayError> {
        if self.state != SessionState::Active {
            return Err(GatewayError::SessionInactive);
        }

        Ok(())
    }

    fn validate_frame_binding(
        &self,
        frame: &IncomingFrame<'_>,
    ) -> Result<(), GatewayError> {
        if frame.session_id != self.session_id || frame.generation != self.generation {
            return Err(GatewayError::GenerationMismatch);
        }

        if frame.sequence == 0 {
            return Err(GatewayError::InvalidSequence);
        }

        validate_text(frame.operation)?;
        validate_text(frame.data_category)?;
        validate_text(frame.audience)?;

        Ok(())
    }

    fn validate_frame_bounds(
        &mut self,
        frame: &IncomingFrame<'_>,
    ) -> Result<(), GatewayError> {
        if frame.payload.len() > self.limits.max_frame_bytes {
            self.terminate(TerminationReason::FrameBoundExceeded);
            return Err(GatewayError::FrameTooLarge);
        }

        Ok(())
    }

    fn validate_capability(
        &mut self,
        frame: &IncomingFrame<'_>,
        now_ms: u64,
    ) -> Result<(), GatewayError> {
        match self.capability.permits(
            self.generation,
            frame.operation,
            frame.data_category,
            frame.audience,
            now_ms,
        ) {
            Ok(()) => Ok(()),
            Err(GatewayError::LeaseExpired) => {
                self.terminate(TerminationReason::LeaseExpired);
                Err(GatewayError::LeaseExpired)
            }
            Err(error) => {
                self.terminate(TerminationReason::CapabilityDenied);
                Err(error)
            }
        }
    }

    fn validate_sequence(
        &mut self,
        frame: &IncomingFrame<'_>,
    ) -> Result<(), GatewayError> {
        if let Some(last_sequence) = self.last_received_sequence {
            if frame.sequence <= last_sequence {
                self.terminate(TerminationReason::ReplayDetected);
                return Err(GatewayError::ReplayDetected);
            }
        }

        Ok(())
    }

    fn validate_budget(
        &mut self,
        frame: &IncomingFrame<'_>,
    ) -> Result<(), GatewayError> {
        let frame_bytes =
            u64::try_from(frame.payload.len()).map_err(|_| GatewayError::IntegerConversion)?;

        let next_byte_total = self
            .consumed_bytes
            .checked_add(frame_bytes)
            .ok_or(GatewayError::RateLimited)?;

        if next_byte_total > self.limits.max_session_bytes {
            self.terminate(TerminationReason::BudgetExceeded);
            return Err(GatewayError::RateLimited);
        }

        let next_message_total = self
            .consumed_messages
            .checked_add(1)
            .ok_or(GatewayError::MessageLimitExceeded)?;

        if next_message_total > self.limits.max_session_messages {
            self.terminate(TerminationReason::BudgetExceeded);
            return Err(GatewayError::MessageLimitExceeded);
        }

        if self.seen_nonce_commitments.len() >= self.limits.max_replay_entries {
            self.terminate(TerminationReason::BudgetExceeded);
            return Err(GatewayError::RateLimited);
        }

        Ok(())
    }

    fn terminate(
        &mut self,
        reason: TerminationReason,
    ) {
        if self.state != SessionState::Active {
            return;
        }

        let policy_version = self.capability.policy_version.clone();

        self.state = if reason.results_in_expiry() {
            SessionState::Expired
        } else {
            SessionState::Revoked
        };
        self.termination_reason = Some(reason);
        self.last_received_sequence = None;
        self.seen_nonce_commitments.clear();
        self.consumed_bytes = 0;
        self.consumed_messages = 0;
        self.capability.clear_sensitive_runtime_fields();
        self.capability.policy_version = policy_version;
        self.keys.zeroize();
    }

    fn session_id_commitment(&self) -> [u8; SESSION_KEY_BYTES] {
        let mut hasher = Sha256::new();
        hasher.update(PROTOCOL_LABEL);
        hasher.update(b":session-receipt:v1:");
        hasher.update(self.session_id.as_bytes());
        hasher.update(self.generation.to_be_bytes());
        hasher.finalize().into()
    }
}

impl Zeroize for GatewaySession {
    fn zeroize(&mut self) {
        let policy_version = self.capability.policy_version.clone();

        self.state = SessionState::Cold;
        self.last_received_sequence = None;
        self.seen_nonce_commitments.clear();
        self.consumed_bytes = 0;
        self.consumed_messages = 0;
        self.capability.clear_sensitive_runtime_fields();
        self.capability.policy_version = policy_version;
        self.keys.zeroize();
        self.termination_reason = Some(TerminationReason::LocalShutdown);
    }
}

pub fn nonce_commitment(
    replay_key: &[u8; SESSION_KEY_BYTES],
    session_id: &SessionId,
    generation: u64,
    sequence: u64,
    nonce: &[u8; NONCE_BYTES],
) -> [u8; SESSION_KEY_BYTES] {
    let mut hasher = Sha256::new();
    hasher.update(PROTOCOL_LABEL);
    hasher.update(b":replay:v1:");
    hasher.update(replay_key);
    hasher.update(session_id.as_bytes());
    hasher.update(generation.to_be_bytes());
    hasher.update(sequence.to_be_bytes());
    hasher.update(nonce);
    hasher.finalize().into()
}

fn verify_transcript_signature(
    identity_key: &VerifyingKey,
    transcript: &HandshakeTranscript,
    signature_bytes: &[u8; 64],
    error: GatewayError,
) -> Result<(), GatewayError> {
    let digest = transcript_hash(transcript)?;
    let signature = Signature::from_bytes(signature_bytes);

    identity_key.verify(&digest, &signature).map_err(|_| error)
}

fn expand_label(
    hkdf: &Hkdf<Sha256>,
    label: &[u8],
    context: &[u8],
    output: &mut [u8; SESSION_KEY_BYTES],
) -> Result<(), GatewayError> {
    let capacity = PROTOCOL_LABEL
        .len()
        .checked_add(1)
        .and_then(|value| value.checked_add(label.len()))
        .and_then(|value| value.checked_add(1))
        .and_then(|value| value.checked_add(context.len()))
        .ok_or(GatewayError::TranscriptTooLarge)?;

    let mut info = Vec::with_capacity(capacity);
    info.extend_from_slice(PROTOCOL_LABEL);
    info.push(b':');
    info.extend_from_slice(label);
    info.push(b':');
    info.extend_from_slice(context);

    hkdf.expand(&info, output)
        .map_err(|_| GatewayError::KeyDerivationFailed)
}

fn append_length_prefixed(
    output: &mut Vec<u8>,
    value: &[u8],
) -> Result<(), GatewayError> {
    let length = u16::try_from(value.len()).map_err(|_| GatewayError::TranscriptTooLarge)?;

    output.extend_from_slice(&length.to_be_bytes());
    output.extend_from_slice(value);

    Ok(())
}

fn append_string_set(
    output: &mut Vec<u8>,
    values: &BTreeSet<String>,
) -> Result<(), GatewayError> {
    let count = u16::try_from(values.len()).map_err(|_| GatewayError::TranscriptTooLarge)?;

    output.extend_from_slice(&count.to_be_bytes());

    for value in values {
        validate_text(value)?;
        append_length_prefixed(output, value.as_bytes())?;
    }

    Ok(())
}

fn validate_text(
    value: &str,
) -> Result<(), GatewayError> {
    if value.is_empty()
        || value.len() > MAX_TEXT_FIELD_BYTES
        || value.as_bytes().contains(&0)
        || !value.is_ascii()
    {
        return Err(GatewayError::InvalidTranscriptText);
    }

    Ok(())
}
