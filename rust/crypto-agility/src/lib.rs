#![forbid(unsafe_code)]
#![deny(missing_docs)]

//! Cipher-suite policy, anti-downgrade negotiation, and key-rotation validation.
//!
//! This crate is intentionally cryptographic-library agnostic. It does not encrypt,
//! decrypt, sign, generate keys, or manage private key material. It selects and
//! validates policy-approved suites so a caller can dispatch to a separately
//! reviewed implementation.

use std::collections::{BTreeMap, BTreeSet};
use std::fmt::{Display, Formatter};

/// Stable identifier for a cipher suite.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct SuiteId(String);

impl SuiteId {
    /// Creates a validated suite identifier.
    pub fn new(value: impl Into<String>) -> Result<Self, CryptoPolicyError> {
        let value = value.into();

        if value.len() < 4 || value.len() > 128 {
            return Err(CryptoPolicyError::InvalidSuiteId);
        }

        if !value
            .bytes()
            .all(|byte| byte.is_ascii_uppercase() || byte.is_ascii_digit() || matches!(byte, b'_' | b':' | b'-'))
        {
            return Err(CryptoPolicyError::InvalidSuiteId);
        }

        Ok(Self(value))
    }

    /// Returns the suite identifier as a string slice.
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Display for SuiteId {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(&self.0)
    }
}

/// Lifecycle status for a cipher suite.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum SuiteStatus {
    /// Approved for new encryption and decryption.
    Active,
    /// Allowed only to decrypt retained ciphertext during a bounded migration.
    DecryptOnly,
    /// No longer approved for new use and scheduled for retirement.
    Deprecated,
    /// Disallowed due to a vulnerability, integrity failure, or policy withdrawal.
    Revoked,
    /// Available for controlled test environments but never production selection.
    Candidate,
    /// Not understood or supported by the current implementation.
    Unsupported,
}

impl SuiteStatus {
    /// Returns whether a suite can be selected for a new encryption session.
    pub const fn selectable_for_new_sessions(self) -> bool {
        matches!(self, Self::Active)
    }

    /// Returns whether a suite can be used to decrypt retained data.
    pub const fn usable_for_decryption(self) -> bool {
        matches!(self, Self::Active | Self::DecryptOnly)
    }
}

/// Purpose separating distinct cryptographic contexts.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum KeyPurpose {
    /// Protects data in transit.
    TransportEncryption,
    /// Protects data at rest.
    StorageEncryption,
    /// Authenticates audit checkpoints or protocol records.
    AuditAuthentication,
    /// Authenticates protocol control messages.
    ControlAuthentication,
}

impl KeyPurpose {
    /// Returns the stable domain label for this purpose.
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::TransportEncryption => "transport_encryption",
            Self::StorageEncryption => "storage_encryption",
            Self::AuditAuthentication => "audit_authentication",
            Self::ControlAuthentication => "control_authentication",
        }
    }
}

/// A versioned, policy-defined cipher suite.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CipherSuite {
    /// Stable suite identifier.
    pub suite_id: SuiteId,
    /// Protocol version understood by the suite.
    pub protocol_version: u32,
    /// Name of the AEAD primitive required by the suite.
    pub aead_algorithm: String,
    /// Name of the hash or XOF primitive required by the suite.
    pub hash_algorithm: String,
    /// Symmetric-key size in bits.
    pub key_bits: u16,
    /// Nonce size in bits.
    pub nonce_bits: u16,
    /// Policy-defined ordering value. Higher is preferred only among allowed suites.
    pub security_rank: u16,
    /// Lifecycle status.
    pub status: SuiteStatus,
    /// First policy epoch at which the suite may be selected.
    pub activation_epoch: u64,
    /// Optional epoch after which the suite cannot be selected.
    pub sunset_epoch: Option<u64>,
    /// SHA-256 digest of the reviewed implementation artifact.
    pub implementation_digest_sha256: String,
    /// Opaque SBOM reference binding this suite to its supply-chain record.
    pub sbom_reference: String,
    /// Opaque evidence-manifest reference documenting review and policy basis.
    pub evidence_manifest_reference: String,
}

impl CipherSuite {
    /// Validates structural and policy-independent suite fields.
    pub fn validate(&self) -> Result<(), CryptoPolicyError> {
        if self.protocol_version == 0 {
            return Err(CryptoPolicyError::InvalidProtocolVersion);
        }

        if self.aead_algorithm.trim().is_empty() {
            return Err(CryptoPolicyError::EmptyField("aead_algorithm"));
        }

        if self.hash_algorithm.trim().is_empty() {
            return Err(CryptoPolicyError::EmptyField("hash_algorithm"));
        }

        if self.key_bits < 128 {
            return Err(CryptoPolicyError::InvalidKeyLength);
        }

        if self.nonce_bits < 64 {
            return Err(CryptoPolicyError::InvalidNonceLength);
        }

        if self
            .sunset_epoch
            .is_some_and(|sunset_epoch| sunset_epoch <= self.activation_epoch)
        {
            return Err(CryptoPolicyError::InvalidEpochWindow);
        }

        validate_sha256_hex(&self.implementation_digest_sha256)?;
        require_non_empty("sbom_reference", &self.sbom_reference)?;
        require_non_empty(
            "evidence_manifest_reference",
            &self.evidence_manifest_reference,
        )?;

        Ok(())
    }

    /// Returns whether the suite is eligible for a new session at `current_epoch`.
    pub fn allowed_for_new_session(
        &self,
        current_epoch: u64,
        minimum_security_rank: u16,
    ) -> bool {
        self.status.selectable_for_new_sessions()
            && self.activation_epoch <= current_epoch
            && self
                .sunset_epoch
                .is_none_or(|sunset_epoch| current_epoch < sunset_epoch)
            && self.security_rank >= minimum_security_rank
    }
}

/// A policy registry containing versioned suites and a monotonic policy epoch.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CipherSuiteRegistry {
    /// Registry schema version.
    pub registry_version: String,
    /// Opaque policy version label.
    pub policy_version: String,
    /// Monotonic policy epoch. Nodes reject policy epochs lower than accepted state.
    pub policy_epoch: u64,
    /// Lowest permitted rank for new-session negotiation.
    pub minimum_security_rank: u16,
    /// Suites indexed by their stable identifier.
    pub suites: BTreeMap<SuiteId, CipherSuite>,
}

impl CipherSuiteRegistry {
    /// Creates and validates a registry.
    pub fn new(
        registry_version: impl Into<String>,
        policy_version: impl Into<String>,
        policy_epoch: u64,
        minimum_security_rank: u16,
        suites: impl IntoIterator<Item = CipherSuite>,
    ) -> Result<Self, CryptoPolicyError> {
        let registry_version = registry_version.into();
        let policy_version = policy_version.into();

        if registry_version != "CipherSuiteRegistry.v1" {
            return Err(CryptoPolicyError::UnsupportedRegistryVersion);
        }

        require_non_empty("policy_version", &policy_version)?;

        let mut indexed_suites = BTreeMap::new();

        for suite in suites {
            suite.validate()?;

            if indexed_suites
                .insert(suite.suite_id.clone(), suite)
                .is_some()
            {
                return Err(CryptoPolicyError::DuplicateSuiteId);
            }
        }

        if indexed_suites.is_empty() {
            return Err(CryptoPolicyError::EmptyRegistry);
        }

        Ok(Self {
            registry_version,
            policy_version,
            policy_epoch,
            minimum_security_rank,
            suites: indexed_suites,
        })
    }

    /// Rejects a registry older than the last accepted epoch.
    pub fn enforce_anti_rollback(
        &self,
        last_accepted_policy_epoch: u64,
    ) -> Result<(), CryptoPolicyError> {
        if self.policy_epoch < last_accepted_policy_epoch {
            return Err(CryptoPolicyError::PolicyRollbackDetected {
                received_epoch: self.policy_epoch,
                last_accepted_epoch: last_accepted_policy_epoch,
            });
        }

        Ok(())
    }

    /// Returns the suite identified by `suite_id`.
    pub fn suite(&self, suite_id: &SuiteId) -> Option<&CipherSuite> {
        self.suites.get(suite_id)
    }

    /// Selects the strongest mutually supported allowed suite for a new session.
    ///
    /// Selection only considers `Active` suites, policy epochs within their
    /// activation/sunset window, ranks at or above the registry minimum, and IDs
    /// offered by the peer. A revoked, deprecated, candidate, unsupported, or
    /// decrypt-only suite is never chosen for a new session.
    pub fn select_new_session_suite(
        &self,
        peer_offered_suite_ids: impl IntoIterator<Item = SuiteId>,
        current_epoch: u64,
        last_accepted_policy_epoch: u64,
    ) -> Result<NegotiatedSuite, CryptoPolicyError> {
        self.enforce_anti_rollback(last_accepted_policy_epoch)?;

        let peer_set = peer_offered_suite_ids.into_iter().collect::<BTreeSet<_>>();

        let selected = self
            .suites
            .values()
            .filter(|suite| peer_set.contains(&suite.suite_id))
            .filter(|suite| {
                suite.allowed_for_new_session(current_epoch, self.minimum_security_rank)
            })
            .max_by(|left, right| {
                left.security_rank
                    .cmp(&right.security_rank)
                    .then_with(|| left.protocol_version.cmp(&right.protocol_version))
                    .then_with(|| right.suite_id.cmp(&left.suite_id))
            })
            .cloned()
            .ok_or(CryptoPolicyError::NoMutuallyAllowedSuite)?;

        Ok(NegotiatedSuite {
            suite: selected,
            registry_policy_epoch: self.policy_epoch,
            selected_at_epoch: current_epoch,
        })
    }

    /// Validates whether a suite may decrypt retained content at `current_epoch`.
    pub fn validate_decryption_suite(
        &self,
        suite_id: &SuiteId,
        current_epoch: u64,
    ) -> Result<&CipherSuite, CryptoPolicyError> {
        let suite = self
            .suite(suite_id)
            .ok_or(CryptoPolicyError::UnknownSuite)?;

        suite.validate()?;

        if !suite.status.usable_for_decryption() {
            return Err(CryptoPolicyError::SuiteNotAllowedForDecryption);
        }

        if suite.activation_epoch > current_epoch {
            return Err(CryptoPolicyError::SuiteNotYetActive);
        }

        Ok(suite)
    }
}

/// A suite selected for a specific policy and time epoch.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NegotiatedSuite {
    /// Selected active suite.
    pub suite: CipherSuite,
    /// Registry policy epoch that authorized selection.
    pub registry_policy_epoch: u64,
    /// Current cryptographic policy epoch at selection time.
    pub selected_at_epoch: u64,
}

/// A key epoch associated with an approved cipher suite and one narrow purpose.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KeyEpoch {
    /// Selected suite identifier.
    pub suite_id: SuiteId,
    /// Purpose-specific key identifier; never contains key material.
    pub key_id: String,
    /// Key purpose boundary.
    pub purpose: KeyPurpose,
    /// Monotonic key epoch.
    pub epoch: u64,
    /// First protocol epoch at which the key may be used.
    pub activated_at_epoch: u64,
    /// Last protocol epoch for new encryption; `None` means policy has not set one.
    pub encrypt_until_epoch: Option<u64>,
    /// Whether compromise is suspected or confirmed.
    pub compromised: bool,
    /// Whether the key is revoked.
    pub revoked: bool,
}

impl KeyEpoch {
    /// Validates structural key-epoch metadata.
    pub fn validate(&self) -> Result<(), CryptoPolicyError> {
        require_non_empty("key_id", &self.key_id)?;

        if self
            .encrypt_until_epoch
            .is_some_and(|until_epoch| until_epoch <= self.activated_at_epoch)
        {
            return Err(CryptoPolicyError::InvalidKeyEpochWindow);
        }

        Ok(())
    }

    /// Returns whether this key epoch is allowed for new encryption.
    pub fn allowed_for_new_encryption(&self, current_epoch: u64) -> bool {
        !self.compromised
            && !self.revoked
            && self.activated_at_epoch <= current_epoch
            && self
                .encrypt_until_epoch
                .is_none_or(|until_epoch| current_epoch < until_epoch)
    }
}

/// Documents why a key transition occurs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RotationReason {
    /// Scheduled cryptoperiod expiry.
    CryptoperiodExpired,
    /// Suspected or confirmed compromise.
    CompromiseSuspected,
    /// Cipher suite changed.
    SuiteChanged,
    /// Custody, role, or authorization boundary changed.
    CustodyOrRoleChanged,
    /// A material policy change requires new keys.
    MaterialPolicyChange,
}

/// Validates a forward-only transition from an old key epoch to a new key epoch.
pub fn validate_key_rotation(
    previous: &KeyEpoch,
    next: &KeyEpoch,
    reason: RotationReason,
) -> Result<(), CryptoPolicyError> {
    previous.validate()?;
    next.validate()?;

    if previous.purpose != next.purpose {
        return Err(CryptoPolicyError::KeyPurposeMismatch);
    }

    if next.epoch <= previous.epoch {
        return Err(CryptoPolicyError::KeyEpochNotForwardOnly);
    }

    if next.key_id == previous.key_id {
        return Err(CryptoPolicyError::KeyIdentifierReused);
    }

    if next.activated_at_epoch < previous.activated_at_epoch {
        return Err(CryptoPolicyError::KeyActivationRollbackDetected);
    }

    if next.revoked || next.compromised {
        return Err(CryptoPolicyError::ReplacementKeyUnavailable);
    }

    match reason {
        RotationReason::SuiteChanged if next.suite_id == previous.suite_id => {
            Err(CryptoPolicyError::SuiteChangeNotObserved)
        }
        RotationReason::CompromiseSuspected if !previous.compromised && !previous.revoked => {
            Err(CryptoPolicyError::CompromiseStateNotRecorded)
        }
        _ => Ok(()),
    }
}

/// Context bound to protected message associated data.
///
/// This struct contains no plaintext payload, private key, or biometric/neural
/// information. A caller may serialize these fields in a deterministic protocol
/// framing before supplying them as AEAD associated data.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AssociatedDataContext {
    /// Protocol version.
    pub protocol_version: u32,
    /// Selected cipher suite.
    pub suite_id: SuiteId,
    /// Selected key epoch.
    pub key_epoch: u64,
    /// Sender pseudonymous protocol identifier.
    pub sender_id: String,
    /// Receiver pseudonymous protocol identifier.
    pub receiver_id: String,
    /// Monotonic message sequence within the key epoch and direction.
    pub message_sequence: u64,
    /// Approved purpose boundary.
    pub purpose: KeyPurpose,
}

impl AssociatedDataContext {
    /// Validates that message context is bounded and unambiguous.
    pub fn validate(&self) -> Result<(), CryptoPolicyError> {
        if self.protocol_version == 0 {
            return Err(CryptoPolicyError::InvalidProtocolVersion);
        }

        require_non_empty("sender_id", &self.sender_id)?;
        require_non_empty("receiver_id", &self.receiver_id)?;

        if self.sender_id == self.receiver_id {
            return Err(CryptoPolicyError::SenderReceiverMustDiffer);
        }

        Ok(())
    }

    /// Returns deterministic textual associated-data bytes for protocol framing.
    ///
    /// Callers must use exactly this stable representation or another versioned,
    /// independently specified canonical format on both endpoints.
    pub fn canonical_bytes(&self) -> Result<Vec<u8>, CryptoPolicyError> {
        self.validate()?;

        Ok(format!(
            "augmented-hub.crypto-agility.v1|protocol={}|suite={}|key_epoch={}|sender={}|receiver={}|sequence={}|purpose={}",
            self.protocol_version,
            self.suite_id,
            self.key_epoch,
            self.sender_id,
            self.receiver_id,
            self.message_sequence,
            self.purpose.as_str(),
        )
        .into_bytes())
    }
}

/// Errors returned by registry, suite, rotation, and context validation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CryptoPolicyError {
    /// Registry schema version is unsupported.
    UnsupportedRegistryVersion,
    /// Suite ID is invalid.
    InvalidSuiteId,
    /// Registry contains no suites.
    EmptyRegistry,
    /// Registry contains duplicate suite IDs.
    DuplicateSuiteId,
    /// A required field is empty.
    EmptyField(&'static str),
    /// Protocol version must be positive.
    InvalidProtocolVersion,
    /// Key size is below policy minimum.
    InvalidKeyLength,
    /// Nonce size is below policy minimum.
    InvalidNonceLength,
    /// SHA-256 artifact digest is malformed.
    InvalidImplementationDigest,
    /// Activation and sunset epochs are inconsistent.
    InvalidEpochWindow,
    /// Incoming policy epoch is older than accepted policy.
    PolicyRollbackDetected {
        /// Received policy epoch.
        received_epoch: u64,
        /// Locally accepted highest policy epoch.
        last_accepted_epoch: u64,
    },
    /// No peer-offered suite is active and policy-allowed.
    NoMutuallyAllowedSuite,
    /// Suite ID is not in the registry.
    UnknownSuite,
    /// Suite is not allowed for retained-data decryption.
    SuiteNotAllowedForDecryption,
    /// Suite activation epoch is in the future.
    SuiteNotYetActive,
    /// Key epoch window is invalid.
    InvalidKeyEpochWindow,
    /// Key purposes must match across rotation.
    KeyPurposeMismatch,
    /// Key epochs must strictly increase.
    KeyEpochNotForwardOnly,
    /// Replacement key identifier cannot equal prior key identifier.
    KeyIdentifierReused,
    /// Replacement activation epoch cannot move backward.
    KeyActivationRollbackDetected,
    /// Replacement key is already compromised or revoked.
    ReplacementKeyUnavailable,
    /// A suite-change reason requires a distinct suite.
    SuiteChangeNotObserved,
    /// A compromise rotation requires compromise or revocation state on prior key.
    CompromiseStateNotRecorded,
    /// Sender and receiver identifiers must differ.
    SenderReceiverMustDiffer,
}

impl Display for CryptoPolicyError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UnsupportedRegistryVersion => {
                formatter.write_str("unsupported cipher-suite registry version")
            }
            Self::InvalidSuiteId => formatter.write_str("invalid cipher suite identifier"),
            Self::EmptyRegistry => formatter.write_str("cipher-suite registry must not be empty"),
            Self::DuplicateSuiteId => formatter.write_str("duplicate cipher suite identifier"),
            Self::EmptyField(field) => write!(formatter, "{field} must not be empty"),
            Self::InvalidProtocolVersion => {
                formatter.write_str("protocol version must be greater than zero")
            }
            Self::InvalidKeyLength => {
                formatter.write_str("cipher suite key length must be at least 128 bits")
            }
            Self::InvalidNonceLength => {
                formatter.write_str("cipher suite nonce length must be at least 64 bits")
            }
            Self::InvalidImplementationDigest => {
                formatter.write_str("implementation digest must be a SHA-256 hexadecimal value")
            }
            Self::InvalidEpochWindow => {
                formatter.write_str("suite sunset epoch must be after activation epoch")
            }
            Self::PolicyRollbackDetected {
                received_epoch,
                last_accepted_epoch,
            } => write!(
                formatter,
                "policy rollback detected: received epoch {received_epoch}, accepted epoch {last_accepted_epoch}"
            ),
            Self::NoMutuallyAllowedSuite => {
                formatter.write_str("no mutually supported active cipher suite is allowed")
            }
            Self::UnknownSuite => formatter.write_str("unknown cipher suite"),
            Self::SuiteNotAllowedForDecryption => {
                formatter.write_str("cipher suite is not allowed for decryption")
            }
            Self::SuiteNotYetActive => formatter.write_str("cipher suite is not active yet"),
            Self::InvalidKeyEpochWindow => {
                formatter.write_str("key encryption window must end after activation")
            }
            Self::KeyPurposeMismatch => {
                formatter.write_str("key rotation cannot change key purpose")
            }
            Self::KeyEpochNotForwardOnly => {
                formatter.write_str("key rotation epoch must strictly increase")
            }
            Self::KeyIdentifierReused => {
                formatter.write_str("key rotation cannot reuse a prior key identifier")
            }
            Self::KeyActivationRollbackDetected => {
                formatter.write_str("replacement key activation cannot move backward")
            }
            Self::ReplacementKeyUnavailable => {
                formatter.write_str("replacement key must not be compromised or revoked")
            }
            Self::SuiteChangeNotObserved => {
                formatter.write_str("suite-change rotation requires a different suite")
            }
            Self::CompromiseStateNotRecorded => {
                formatter.write_str("compromise rotation requires prior compromise or revocation state")
            }
            Self::SenderReceiverMustDiffer => {
                formatter.write_str("sender and receiver identifiers must differ")
            }
        }
    }
}

impl std::error::Error for CryptoPolicyError {}

fn require_non_empty(
    field: &'static str,
    value: &str,
) -> Result<(), CryptoPolicyError> {
    if value.trim().is_empty() {
        Err(CryptoPolicyError::EmptyField(field))
    } else {
        Ok(())
    }
}

fn validate_sha256_hex(value: &str) -> Result<(), CryptoPolicyError> {
    if value.len() != 64 || !value.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(CryptoPolicyError::InvalidImplementationDigest);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn suite(
        id: &str,
        rank: u16,
        status: SuiteStatus,
        activation_epoch: u64,
        sunset_epoch: Option<u64>,
    ) -> CipherSuite {
        CipherSuite {
            suite_id: SuiteId::new(id).expect("valid suite ID"),
            protocol_version: 1,
            aead_algorithm: "Ascon-AEAD128".to_owned(),
            hash_algorithm: "Ascon-Hash256".to_owned(),
            key_bits: 128,
            nonce_bits: 128,
            security_rank: rank,
            status,
            activation_epoch,
            sunset_epoch,
            implementation_digest_sha256: "a".repeat(64),
            sbom_reference: "sbom-crypto-agility-v1".to_owned(),
            evidence_manifest_reference: "evidence-crypto-agility-v1".to_owned(),
        }
    }

    fn registry(suites: Vec<CipherSuite>, policy_epoch: u64) -> CipherSuiteRegistry {
        CipherSuiteRegistry::new(
            "CipherSuiteRegistry.v1",
            "crypto-policy-v1",
            policy_epoch,
            100,
            suites,
        )
        .expect("valid registry")
    }

    #[test]
    fn selects_highest_ranked_active_mutually_supported_suite() {
        let selection = registry(
            vec![
                suite("ASCON_AEAD128_V1", 100, SuiteStatus::Active, 1, None),
                suite("ASCON_AEAD128_V2", 120, SuiteStatus::Active, 2, None),
            ],
            2,
        )
        .select_new_session_suite(
            [
                SuiteId::new("ASCON_AEAD128_V1").expect("valid ID"),
                SuiteId::new("ASCON_AEAD128_V2").expect("valid ID"),
            ],
            2,
            2,
        )
        .expect("selection should succeed");

        assert_eq!(selection.suite.suite_id.as_str(), "ASCON_AEAD128_V2");
    }

    #[test]
    fn refuses_revoked_deprecated_candidate_and_decrypt_only_suites() {
        let registry = registry(
            vec![
                suite("ASCON_AEAD128_R", 200, SuiteStatus::Revoked, 1, None),
                suite("ASCON_AEAD128_D", 190, SuiteStatus::Deprecated, 1, None),
                suite("ASCON_AEAD128_C", 180, SuiteStatus::Candidate, 1, None),
                suite("ASCON_AEAD128_O", 170, SuiteStatus::DecryptOnly, 1, None),
            ],
            1,
        );

        let result = registry.select_new_session_suite(
            [
                SuiteId::new("ASCON_AEAD128_R").expect("valid ID"),
                SuiteId::new("ASCON_AEAD128_D").expect("valid ID"),
                SuiteId::new("ASCON_AEAD128_C").expect("valid ID"),
                SuiteId::new("ASCON_AEAD128_O").expect("valid ID"),
            ],
            1,
            1,
        );

        assert_eq!(result, Err(CryptoPolicyError::NoMutuallyAllowedSuite));
    }

    #[test]
    fn detects_policy_epoch_rollback() {
        let registry = registry(
            vec![suite(
                "ASCON_AEAD128_V1",
                100,
                SuiteStatus::Active,
                1,
                None,
            )],
            4,
        );

        assert_eq!(
            registry.enforce_anti_rollback(5),
            Err(CryptoPolicyError::PolicyRollbackDetected {
                received_epoch: 4,
                last_accepted_epoch: 5,
            })
        );
    }

    #[test]
    fn permits_decrypt_only_for_retained_data_but_not_new_sessions() {
        let decrypt_only = suite(
            "ASCON_AEAD128_LEGACY",
            100,
            SuiteStatus::DecryptOnly,
            1,
            None,
        );

        let registry = registry(vec![decrypt_only.clone()], 1);
        let suite_id = decrypt_only.suite_id.clone();

        assert_eq!(
            registry
                .validate_decryption_suite(&suite_id, 1)
                .map(|suite| suite.status),
            Ok(SuiteStatus::DecryptOnly)
        );

        assert_eq!(
            registry.select_new_session_suite([suite_id], 1, 1),
            Err(CryptoPolicyError::NoMutuallyAllowedSuite)
        );
    }

    #[test]
    fn rejects_suite_after_sunset_epoch() {
        let registry = registry(
            vec![suite(
                "ASCON_AEAD128_V1",
                100,
                SuiteStatus::Active,
                1,
                Some(5),
            )],
            5,
        );

        let result = registry.select_new_session_suite(
            [SuiteId::new("ASCON_AEAD128_V1").expect("valid ID")],
            5,
            5,
        );

        assert_eq!(result, Err(CryptoPolicyError::NoMutuallyAllowedSuite));
    }

    #[test]
    fn validates_forward_only_key_rotation() {
        let previous = KeyEpoch {
            suite_id: SuiteId::new("ASCON_AEAD128_V1").expect("valid ID"),
            key_id: "transport-key-epoch-1".to_owned(),
            purpose: KeyPurpose::TransportEncryption,
            epoch: 1,
            activated_at_epoch: 10,
            encrypt_until_epoch: Some(20),
            compromised: false,
            revoked: false,
        };

        let next = KeyEpoch {
            suite_id: SuiteId::new("ASCON_AEAD128_V1").expect("valid ID"),
            key_id: "transport-key-epoch-2".to_owned(),
            purpose: KeyPurpose::TransportEncryption,
            epoch: 2,
            activated_at_epoch: 20,
            encrypt_until_epoch: Some(30),
            compromised: false,
            revoked: false,
        };
