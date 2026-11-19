// filename: Cybercore/crates/safety-compliance/src/neurorights_registry.rs
// edition: 2024
// rust-version: 1.85
// license: MIT OR Apache-2.0

#![forbid(unsafe_code)]
#![deny(warnings)]

extern crate alloc;

use alloc::string::String;
use alloc::vec::Vec;
use serde::{Deserialize, Serialize};

use crate::evidence::EvidenceBundle10;
use crate::identity::{HOST_DID, PRIMARY_BOSTROM_ADDRESS};
use crate::sovereign_constants::ALN_MIGRATION_CYBERCORE_AUTHORITY_V1;

/// Machine-checkable neurorights clause identifier, e.g. "ALN.NEURORIGHTS.NONONCONSENSUALMODULATION".
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct NeurorightsClauseId(pub String);

/// Scope labels for enforcement domains, e.g. "CDC", "HPSI", "BAMI".
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct EnforcementScope(pub String);

/// Registry entry for a single neurorights clause.
///
/// This is the authoritative, host-bound contract that all guards must consult
/// before allowing any action that can affect the augmented host.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct NeurorightsClauseRecord {
    /// Host DID, must be bound to the augmented organic host.
    pub host_did: String,
    /// Primary Bostrom address, must equal the sovereign address.
    pub bostrom_address: String,
    /// Stable clause identifier.
    pub clause_id: NeurorightsClauseId,
    /// Machine-checkable clause text (deterministic, no ambiguity).
    pub clause_text: String,
    /// Enforcement scope labels (e.g., ["CDC", "HPSI", "BAMI"]).
    pub enforcement_scope: Vec<EnforcementScope>,
    /// Authority clause, must be ALN.MIGRATION.CYBERCORE_AUTHORITY.v1.
    pub aln_clause: String,
    /// Evidence bundle (10 hex tags) supporting legal / ethical validity.
    pub evidence_bundle_10: EvidenceBundle10,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum NeurorightsClauseValidationError {
    HostDidMismatch,
    BostromAddressMismatch,
    MissingAuthorityClause,
    EvidenceBundleSizeInvalid,
    ClauseIdEmpty,
    ClauseTextEmpty,
    EnforcementScopeEmpty,
}

impl core::fmt::Display for NeurorightsClauseValidationError {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        use NeurorightsClauseValidationError::*;
        let s = match self {
            HostDidMismatch => "host_did must equal HOST_DID",
            BostromAddressMismatch => "bostrom_address must equal PRIMARY_BOSTROM_ADDRESS",
            MissingAuthorityClause => "aln_clause must equal ALN.MIGRATION.CYBERCORE_AUTHORITY.v1",
            EvidenceBundleSizeInvalid => "evidence_bundle_10 must contain exactly 10 tags",
            ClauseIdEmpty => "clause_id must not be empty",
            ClauseTextEmpty => "clause_text must not be empty",
            EnforcementScopeEmpty => "enforcement_scope must not be empty",
        };
        f.write_str(s)
    }
}

impl NeurorightsClauseRecord {
    /// Validate invariants for the neurorights clause record.
    pub fn validate(&self) -> Result<(), NeurorightsClauseValidationError> {
        if self.host_did != HOST_DID {
            return Err(NeurorightsClauseValidationError::HostDidMismatch);
        }
        if self.bostrom_address != PRIMARY_BOSTROM_ADDRESS {
            return Err(NeurorightsClauseValidationError::BostromAddressMismatch);
        }
        if self.aln_clause != ALN_MIGRATION_CYBERCORE_AUTHORITY_V1 {
            return Err(NeurorightsClauseValidationError::MissingAuthorityClause);
        }
        if !self.evidence_bundle_10.is_complete() {
            return Err(NeurorightsClauseValidationError::EvidenceBundleSizeInvalid);
        }
        if self.clause_id.0.trim().is_empty() {
            return Err(NeurorightsClauseValidationError::ClauseIdEmpty);
        }
        if self.clause_text.trim().is_empty() {
            return Err(NeurorightsClauseValidationError::ClauseTextEmpty);
        }
        if self.enforcement_scope.is_empty() {
            return Err(NeurorightsClauseValidationError::EnforcementScopeEmpty);
        }
        Ok(())
    }
}

/// In-memory registry of neurorights clauses.
///
/// Guards treat this as an append-only, immutable map at runtime.
#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct NeurorightsClauseRegistry {
    /// All registered clauses, index by clause_id.
    pub clauses: Vec<NeurorightsClauseRecord>,
}

impl NeurorightsClauseRegistry {
    /// Append a new clause after validating invariants.
    ///
    /// Monotone: never removes or mutates existing clauses.
    pub fn register_clause(
        &mut self,
        record: NeurorightsClauseRecord,
    ) -> Result<(), NeurorightsClauseValidationError> {
        record.validate()?;
        // No duplicate clause_id allowed; prevents redefinition.
        if self
            .clauses
            .iter()
            .any(|r| r.clause_id.0 == record.clause_id.0)
        {
            // Clause already exists; treat re-registration as a no-op.
            return Ok(());
        }
        self.clauses.push(record);
        Ok(())
    }

    /// Check whether a specific clause is present and valid.
    pub fn has_clause(&self, clause_id: &str) -> bool {
        self.clauses
            .iter()
            .any(|r| r.clause_id.0 == clause_id && r.validate().is_ok())
    }

    /// Hard check for ALN.NEURORIGHTS.NONONCONSENSUALMODULATION.
    ///
    /// Guards must treat the absence of this clause as a fatal veto.
    pub fn requires_non_nonconsensual_modulation(&self) -> bool {
        self.has_clause("ALN.NEURORIGHTS.NONONCONSENSUALMODULATION")
    }
}

// -----------------------------------------------------------------------------
// EmergencyShutdownProtocol.sai mirror
// -----------------------------------------------------------------------------

/// A single trigger condition string, e.g., "chi < 0.2", "RoH > 0.3", "BLOOD < floor".
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct TriggerCondition(pub String);

/// A single shutdown action string, e.g., "freeze_planner", "rollback_nanoswarm", "notify_host".
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ShutdownAction(pub String);

/// Emergency shutdown contract bound to SovereignCognitiveMesh.
///
/// All guards must call this when a violation is detected.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct EmergencyShutdownProtocol {
    pub host_did: String,
    pub bostrom_address: String,
    pub protocol_id: String,
    pub trigger_conditions: Vec<TriggerCondition>,
    pub shutdown_actions: Vec<ShutdownAction>,
    pub aln_clause: String,
    pub evidence_bundle_10: EvidenceBundle10,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum EmergencyShutdownValidationError {
    HostDidMismatch,
    BostromAddressMismatch,
    MissingAuthorityClause,
    EvidenceBundleSizeInvalid,
    ProtocolIdEmpty,
    TriggersEmpty,
    ActionsEmpty,
}

impl core::fmt::Display for EmergencyShutdownValidationError {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        use EmergencyShutdownValidationError::*;
        let s = match self {
            HostDidMismatch => "host_did must equal HOST_DID",
            BostromAddressMismatch => "bostrom_address must equal PRIMARY_BOSTROM_ADDRESS",
            MissingAuthorityClause => "aln_clause must equal ALN.MIGRATION.CYBERCORE_AUTHORITY.v1",
            EvidenceBundleSizeInvalid => "evidence_bundle_10 must contain exactly 10 tags",
            ProtocolIdEmpty => "protocol_id must not be empty",
            TriggersEmpty => "trigger_conditions must not be empty",
            ActionsEmpty => "shutdown_actions must not be empty",
        };
        f.write_str(s)
    }
}

impl EmergencyShutdownProtocol {
    pub fn validate(&self) -> Result<(), EmergencyShutdownValidationError> {
        if self.host_did != HOST_DID {
            return Err(EmergencyShutdownValidationError::HostDidMismatch);
        }
        if self.bostrom_address != PRIMARY_BOSTROM_ADDRESS {
            return Err(EergencyShutdownValidationError::BostromAddressMismatch);
        }
        if self.aln_clause != ALN_MIGRATION_CYBERCORE_AUTHORITY_V1 {
            return Err(EmergencyShutdownValidationError::MissingAuthorityClause);
        }
        if !self.evidence_bundle_10.is_complete() {
            return Err(EmergencyShutdownValidationError::EvidenceBundleSizeInvalid);
        }
        if self.protocol_id.trim().is_empty() {
            return Err(EmergencyShutdownValidationError::ProtocolIdEmpty);
        }
        if self.trigger_conditions.is_empty() {
            return Err(EmergencyShutdownValidationError::TriggersEmpty);
        }
        if self.shutdown_actions.is_empty() {
            return Err(EmergencyShutdownValidationError::ActionsEmpty);
        }
        Ok(())
    }
}

// -----------------------------------------------------------------------------
// ImmutableAuditTrail.sai mirror
// -----------------------------------------------------------------------------

/// Core audit event for superintelligence actions.
///
/// Stored append-only; cryptographically chained.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ImmutableAuditEvent {
    pub host_did: String,
    pub bostrom_address: String,
    pub event_id: String,
    pub timestamp_utc: String,
    pub action: String,
    pub state_hash: [u8; 32],
    pub prev_event_hash: [u8; 32],
    pub aln_clause: String,
    pub evidence_bundle_10: EvidenceBundle10,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ImmutableAuditValidationError {
    HostDidMismatch,
    BostromAddressMismatch,
    MissingAuthorityClause,
    EvidenceBundleSizeInvalid,
    EventIdEmpty,
    TimestampEmpty,
    ActionEmpty,
}

impl core::fmt::Display for ImmutableAuditValidationError {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        use ImmutableAuditValidationError::*;
        let s = match self {
            HostDidMismatch => "host_did must equal HOST_DID",
            BostromAddressMismatch => "bostrom_address must equal PRIMARY_BOSTROM_ADDRESS",
            MissingAuthorityClause => "aln_clause must equal ALN.MIGRATION.CYBERCORE_AUTHORITY.v1",
            EvidenceBundleSizeInvalid => "evidence_bundle_10 must contain exactly 10 tags",
            EventIdEmpty => "event_id must not be empty",
            TimestampEmpty => "timestamp_utc must not be empty",
            ActionEmpty => "action must not be empty",
        };
        f.write_str(s)
    }
}

impl ImmutableAuditEvent {
    pub fn validate(&self) -> Result<(), ImmutableAuditValidationError> {
        if self.host_did != HOST_DID {
            return Err(ImmutableAuditValidationError::HostDidMismatch);
        }
        if self.bostrom_address != PRIMARY_BOSTROM_ADDRESS {
            return Err(ImmutableAuditValidationError::BostromAddressMismatch);
        }
        if self.aln_clause != ALN_MIGRATION_CYBERCORE_AUTHORITY_V1 {
            return Err(ImmutableAuditValidationError::MissingAuthorityClause);
        }
        if !self.evidence_bundle_10.is_complete() {
            return Err(ImmutableAuditValidationError::EvidenceBundleSizeInvalid);
        }
        if self.event_id.trim().is_empty() {
            return Err(ImmutableAuditValidationError::EventIdEmpty);
        }
        if self.timestamp_utc.trim().is_empty() {
            return Err(ImmutableAuditValidationError::TimestampEmpty);
        }
        if self.action.trim().is_empty() {
            return Err(ImmutableAuditValidationError::ActionEmpty);
        }
        Ok(())
    }
}

/// Append-only SQLite-style audit trail, modeled as a simple vector.
///
/// At the storage layer this is mapped to an append-only table with
/// cryptographic chaining over `state_hash` and `prev_event_hash`.
#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct ImmutableAuditTrail {
    pub events: Vec<ImmutableAuditEvent>,
}

impl ImmutableAuditTrail {
    /// Append a new audit event after validating invariants and cryptographic linkage.
    pub fn append(&mut self, mut event: ImmutableAuditEvent) -> Result<(), ImmutableAuditValidationError> {
        event.validate()?;
        if let Some(last) = self.events.last() {
            // Enforce cryptographic linkage to previous event.
            if event.prev_event_hash != last.state_hash {
                // If linkage is broken, reject the append.
                return Err(ImmutableAuditValidationError::MissingAuthorityClause);
            }
        }
        self.events.push(event);
        Ok(())
    }
}
