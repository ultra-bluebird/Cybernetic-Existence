use std::collections::BTreeSet;

const MAX_REFERENCE_LENGTH: usize = 2_048;
const MIN_WITNESSES: usize = 1;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AnchorError {
    EmptyField(&'static str),
    ReferenceTooLong(&'static str),
    DuplicateWitness,
    InsufficientWitnesses,
    PublicReplicationWithoutApproval,
    MissingReplicationTarget,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct ContentReference(String);

impl ContentReference {
    pub fn new(value: impl Into<String>) -> Result<Self, AnchorError> {
        let value = value.into();
        validate_reference("content_reference", &value)?;
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct WitnessReference(String);

impl WitnessReference {
    pub fn new(value: impl Into<String>) -> Result<Self, AnchorError> {
        let value = value.into();
        validate_reference("witness_reference", &value)?;
        Ok(Self(value))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReplicationTarget {
    LocalArchive,
    ContentAddressedStore,
    NostrRelay,
    AtProtocolRepository,
    OtherApprovedTarget(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WitnessAttestation {
    pub witness: WitnessReference,
    pub attestation_reference: ContentReference,
    pub signed_at_rfc3339: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SovereignContinuityAnchor {
    pub anchor_reference: String,
    pub subject_reference: String,
    pub canonical_content: ContentReference,
    pub policy_bundle: ContentReference,
    pub witnesses: Vec<WitnessAttestation>,
    pub replication_targets: Vec<ReplicationTarget>,
    pub public_replication_approved: bool,
    pub identity_certification_claimed: bool,
    pub consciousness_certification_claimed: bool,
    pub cybernetic_status_certification_claimed: bool,
    pub host_migration_certification_claimed: bool,
}

impl SovereignContinuityAnchor {
    pub fn validate(&self) -> Result<(), AnchorError> {
        validate_reference("anchor_reference", &self.anchor_reference)?;
        validate_reference("subject_reference", &self.subject_reference)?;

        if self.witnesses.len() < MIN_WITNESSES {
            return Err(AnchorError::InsufficientWitnesses);
        }

        let mut unique_witnesses = BTreeSet::new();
        for witness in &self.witnesses {
            if !unique_witnesses.insert(witness.witness.clone()) {
                return Err(AnchorError::DuplicateWitness);
            }
        }

        if self.replication_targets.is_empty() {
            return Err(AnchorError::MissingReplicationTarget);
        }

        let has_public_target = self.replication_targets.iter().any(|target| {
            matches!(
                target,
                ReplicationTarget::NostrRelay | ReplicationTarget::AtProtocolRepository
            )
        });

        if has_public_target && !self.public_replication_approved {
            return Err(AnchorError::PublicReplicationWithoutApproval);
        }

        if self.identity_certification_claimed
            || self.consciousness_certification_claimed
            || self.cybernetic_status_certification_claimed
            || self.host_migration_certification_claimed
        {
            return Err(AnchorError::EmptyField(
                "certification claims are prohibited for this anchor",
            ));
        }

        Ok(())
    }

    pub fn replication_summary(&self) -> String {
        format!(
            "anchor={} mirrors={} witnesses={} public_approval={}",
            self.anchor_reference,
            self.replication_targets.len(),
            self.witnesses.len(),
            self.public_replication_approved
        )
    }
}

fn validate_reference(field: &'static str, value: &str) -> Result<(), AnchorError> {
    if value.trim().is_empty() {
        return Err(AnchorError::EmptyField(field));
    }

    if value.len() > MAX_REFERENCE_LENGTH {
        return Err(AnchorError::ReferenceTooLong(field));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn reference(value: &str) -> ContentReference {
        ContentReference::new(value).unwrap()
    }

    fn witness(value: &str) -> WitnessReference {
        WitnessReference::new(value).unwrap()
    }

    #[test]
    fn accepts_private_anchor_with_witness_and_local_replication() {
        let anchor = SovereignContinuityAnchor {
            anchor_reference: "anchor:continuity:example-001".to_string(),
            subject_reference: "did:example:sovereign-subject".to_string(),
            canonical_content: reference("cid:example-content"),
            policy_bundle: reference("cid:example-policy"),
            witnesses: vec![WitnessAttestation {
                witness: witness("did:example:witness-1"),
                attestation_reference: reference("cid:example-attestation-1"),
                signed_at_rfc3339: "2026-09-26T07:00:00Z".to_string(),
            }],
            replication_targets: vec![ReplicationTarget::LocalArchive],
            public_replication_approved: false,
            identity_certification_claimed: false,
            consciousness_certification_claimed: false,
            cybernetic_status_certification_claimed: false,
            host_migration_certification_claimed: false,
        };

        assert_eq!(anchor.validate(), Ok(()));
    }

    #[test]
    fn rejects_public_nostr_replication_without_approval() {
        let anchor = SovereignContinuityAnchor {
            anchor_reference: "anchor:continuity:example-002".to_string(),
            subject_reference: "did:example:sovereign-subject".to_string(),
            canonical_content: reference("cid:example-content"),
            policy_bundle: reference("cid:example-policy"),
            witnesses: vec![WitnessAttestation {
                witness: witness("did:example:witness-1"),
                attestation_reference: reference("cid:example-attestation-1"),
                signed_at_rfc3339: "2026-09-26T07:00:00Z".to_string(),
            }],
            replication_targets: vec![ReplicationTarget::NostrRelay],
            public_replication_approved: false,
            identity_certification_claimed: false,
            consciousness_certification_claimed: false,
            cybernetic_status_certification_claimed: false,
            host_migration_certification_claimed: false,
        };

        assert_eq!(
            anchor.validate(),
            Err(AnchorError::PublicReplicationWithoutApproval)
        );
    }
}
