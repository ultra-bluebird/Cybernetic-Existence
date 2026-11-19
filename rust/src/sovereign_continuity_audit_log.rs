use std::collections::BTreeSet;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuditError {
    EmptyField(&'static str),
    DuplicateWitness,
    MissingWitness,
    InvalidSequence,
    CertificationClaimProhibited,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuditEventKind {
    CommitmentRegistered,
    AttributionEdgeAdded,
    ForkDeclared,
    MigrationDeclared,
    PolicyUpdated,
    CorrectionLinked,
    WitnessAdded,
    ModelUpdateRecorded,
    SunsetRecorded,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuditWitness {
    pub witness_reference: String,
    pub cosignature_reference: String,
    pub witnessed_at_rfc3339: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MerkleAuditEntry {
    pub sequence: u64,
    pub event_id: String,
    pub event_kind: AuditEventKind,
    pub previous_entry_reference: Option<String>,
    pub event_content_reference: String,
    pub merkle_root_reference: String,
    pub policy_bundle_reference: String,
    pub witnesses: Vec<AuditWitness>,
    pub recorded_at_rfc3339: String,
    pub identity_certification_claimed: bool,
    pub continuity_certification_claimed: bool,
    pub host_migration_certification_claimed: bool,
}

impl MerkleAuditEntry {
    pub fn validate_against_previous(
        &self,
        previous: Option<&MerkleAuditEntry>,
    ) -> Result<(), AuditError> {
        require("event_id", &self.event_id)?;
        require("event_content_reference", &self.event_content_reference)?;
        require("merkle_root_reference", &self.merkle_root_reference)?;
        require("policy_bundle_reference", &self.policy_bundle_reference)?;
        require("recorded_at_rfc3339", &self.recorded_at_rfc3339)?;

        if self.witnesses.is_empty() {
            return Err(AuditError::MissingWitness);
        }

        let mut unique_witnesses = BTreeSet::new();
        for witness in &self.witnesses {
            require("witness_reference", &witness.witness_reference)?;
            require("cosignature_reference", &witness.cosignature_reference)?;

            if !unique_witnesses.insert(witness.witness_reference.as_str()) {
                return Err(AuditError::DuplicateWitness);
            }
        }

        if self.identity_certification_claimed
            || self.continuity_certification_claimed
            || self.host_migration_certification_claimed
        {
            return Err(AuditError::CertificationClaimProhibited);
        }

        match previous {
            None if self.sequence != 0 => Err(AuditError::InvalidSequence),
            None if self.previous_entry_reference.is_some() => Err(AuditError::InvalidSequence),
            Some(previous) => {
                if self.sequence != previous.sequence + 1 {
                    return Err(AuditError::InvalidSequence);
                }

                if self.previous_entry_reference.as_deref() != Some(previous.event_id.as_str()) {
                    return Err(AuditError::InvalidSequence);
                }

                Ok(())
            }
            _ => Ok(()),
        }
    }
}

fn require(field: &'static str, value: &str) -> Result<(), AuditError> {
    if value.trim().is_empty() {
        return Err(AuditError::EmptyField(field));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn witness() -> AuditWitness {
        AuditWitness {
            witness_reference: "did:example:witness-1".to_string(),
            cosignature_reference: "cid:cosignature-1".to_string(),
            witnessed_at_rfc3339: "2026-09-26T07:06:00Z".to_string(),
        }
    }

    #[test]
    fn validates_append_only_entry_chain() {
        let genesis = MerkleAuditEntry {
            sequence: 0,
            event_id: "event:000".to_string(),
            event_kind: AuditEventKind::CommitmentRegistered,
            previous_entry_reference: None,
            event_content_reference: "cid:genesis-content".to_string(),
            merkle_root_reference: "cid:root-000".to_string(),
            policy_bundle_reference: "cid:policy-v1".to_string(),
            witnesses: vec![witness()],
            recorded_at_rfc3339: "2026-09-26T07:06:00Z".to_string(),
            identity_certification_claimed: false,
            continuity_certification_claimed: false,
            host_migration_certification_claimed: false,
        };

        let successor = MerkleAuditEntry {
            sequence: 1,
            event_id: "event:001".to_string(),
            event_kind: AuditEventKind::ForkDeclared,
            previous_entry_reference: Some("event:000".to_string()),
            event_content_reference: "cid:fork-content".to_string(),
            merkle_root_reference: "cid:root-001".to_string(),
            policy_bundle_reference: "cid:policy-v1".to_string(),
            witnesses: vec![witness()],
            recorded_at_rfc3339: "2026-09-26T07:07:00Z".to_string(),
            identity_certification_claimed: false,
            continuity_certification_claimed: false,
            host_migration_certification_claimed: false,
        };

        assert_eq!(genesis.validate_against_previous(None), Ok(()));
        assert_eq!(successor.validate_against_previous(Some(&genesis)), Ok(()));
    }
}
