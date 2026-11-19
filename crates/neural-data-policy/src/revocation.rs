#![forbid(unsafe_code)]

//! Derived-artifact re-evaluation after consent revocation.
//!
//! This module classifies whether an artifact may remain available under an
//! active, independent authorization. It does not prove remote deletion or
//! erase information held by uncooperative recipients.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ArtifactClass {
    SensitiveSource,
    SensitiveDerived,
    RestrictedAggregate,
    PolicyMetadata,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ArtifactDisposition {
    RetainUnderIndependentAuthorization,
    QuarantineForReview,
    DeleteFromControlledStore,
    PreserveMinimalAuditMetadata,
}

#[derive(Debug, Clone, Copy)]
pub struct ArtifactRecord {
    pub source_epoch: u64,
    pub current_epoch: u64,
    pub artifact_class: ArtifactClass,
    pub has_independent_authorization: bool,
    pub within_retention_period: bool,
}

pub fn reevaluate_after_revocation(record: ArtifactRecord) -> ArtifactDisposition {
    if record.artifact_class == ArtifactClass::PolicyMetadata {
        return ArtifactDisposition::PreserveMinimalAuditMetadata;
    }

    if record.source_epoch == record.current_epoch && record.within_retention_period {
        return ArtifactDisposition::RetainUnderIndependentAuthorization;
    }

    if record.has_independent_authorization && record.within_retention_period {
        return ArtifactDisposition::QuarantineForReview;
    }

    ArtifactDisposition::DeleteFromControlledStore
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stale_sensitive_derived_artifact_without_independent_basis_is_deleted() {
        let disposition = reevaluate_after_revocation(ArtifactRecord {
            source_epoch: 4,
            current_epoch: 5,
            artifact_class: ArtifactClass::SensitiveDerived,
            has_independent_authorization: false,
            within_retention_period: true,
        });

        assert_eq!(disposition, ArtifactDisposition::DeleteFromControlledStore);
    }

    #[test]
    fn policy_metadata_is_preserved_as_minimal_audit_record() {
        let disposition = reevaluate_after_revocation(ArtifactRecord {
            source_epoch: 4,
            current_epoch: 5,
            artifact_class: ArtifactClass::PolicyMetadata,
            has_independent_authorization: false,
            within_retention_period: false,
        });

        assert_eq!(
            disposition,
            ArtifactDisposition::PreserveMinimalAuditMetadata
        );
    }
}
