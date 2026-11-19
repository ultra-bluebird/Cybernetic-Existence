#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EvidenceLevel {
    UnreviewedObservation,
    MethodNote,
    SecondarySummary,
    PrimarySource,
    Replication,
    SystematicReview,
    IndependentValidation,
    WithdrawnOrSuperseded,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HashDigest {
    pub algorithm: String,
    pub value_hex: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Subject {
    pub logical_name: String,
    pub media_type: String,
    pub content_hash: HashDigest,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceReference {
    pub source_id: String,
    pub source_kind: String,
    pub access_basis: String,
    pub retrieved_at_utc: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum EvidenceDuration {
    Instant {
        observed_at_utc: String,
    },
    Interval {
        started_at_utc: String,
        ended_at_utc: String,
    },
    Aggregate {
        started_at_utc: String,
        ended_at_utc: String,
        observation_count: u64,
    },
    UnspecifiedWithReason {
        reason: String,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResearchContext {
    pub domain: String,
    pub tissue_context: Option<String>,
    pub scope_note: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReviewRecord {
    pub reviewer_role: String,
    pub reviewer_key_id: String,
    pub reviewed_at_utc: String,
    pub review_outcome: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DetachedSignature {
    pub algorithm: String,
    pub key_id: String,
    pub value_base64: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EvidenceManifestV1 {
    pub manifest_version: String,
    pub manifest_id: String,
    pub subject: Subject,
    pub source: SourceReference,
    pub evidence_level: EvidenceLevel,
    pub context: ResearchContext,
    pub duration: EvidenceDuration,
    pub limitations: Vec<String>,
    pub review: ReviewRecord,
    pub previous_manifest_hash: Option<HashDigest>,
    pub signature: Option<DetachedSignature>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ManifestValidationError {
    UnsupportedManifestVersion,
    EmptyField(&'static str),
    InvalidHashAlgorithm,
    InvalidHashLength,
    InvalidHashCharacters,
    MissingLimitations,
    InvalidDuration,
    InvalidObservationCount,
    SignatureKeyMismatch,
}

impl EvidenceManifestV1 {
    pub fn validate(&self) -> Result<(), ManifestValidationError> {
        if self.manifest_version != "EvidenceManifest.v1" {
            return Err(ManifestValidationError::UnsupportedManifestVersion);
        }

        require_non_empty("manifest_id", &self.manifest_id)?;
        require_non_empty("subject.logical_name", &self.subject.logical_name)?;
        require_non_empty("subject.media_type", &self.subject.media_type)?;
        require_non_empty("source.source_id", &self.source.source_id)?;
        require_non_empty("source.source_kind", &self.source.source_kind)?;
        require_non_empty("source.access_basis", &self.source.access_basis)?;
        require_non_empty("source.retrieved_at_utc", &self.source.retrieved_at_utc)?;
        require_non_empty("context.domain", &self.context.domain)?;
        require_non_empty("context.scope_note", &self.context.scope_note)?;
        require_non_empty("review.reviewer_role", &self.review.reviewer_role)?;
        require_non_empty("review.reviewer_key_id", &self.review.reviewer_key_id)?;
        require_non_empty("review.reviewed_at_utc", &self.review.reviewed_at_utc)?;
        require_non_empty("review.review_outcome", &self.review.review_outcome)?;

        validate_sha256(&self.subject.content_hash)?;

        if let Some(previous) = &self.previous_manifest_hash {
            validate_sha256(previous)?;
        }

        if self.limitations.is_empty()
            || self.limitations.iter().any(|item| item.trim().is_empty())
        {
            return Err(ManifestValidationError::MissingLimitations);
        }

        match &self.duration {
            EvidenceDuration::Instant { observed_at_utc } => {
                require_non_empty("duration.observed_at_utc", observed_at_utc)?;
            }
            EvidenceDuration::Interval {
                started_at_utc,
                ended_at_utc,
            } => {
                require_non_empty("duration.started_at_utc", started_at_utc)?;
                require_non_empty("duration.ended_at_utc", ended_at_utc)?;
                if started_at_utc > ended_at_utc {
                    return Err(ManifestValidationError::InvalidDuration);
                }
            }
            EvidenceDuration::Aggregate {
                started_at_utc,
                ended_at_utc,
                observation_count,
            } => {
                require_non_empty("duration.started_at_utc", started_at_utc)?;
                require_non_empty("duration.ended_at_utc", ended_at_utc)?;
                if started_at_utc > ended_at_utc {
                    return Err(ManifestValidationError::InvalidDuration);
                }
                if *observation_count == 0 {
                    return Err(ManifestValidationError::InvalidObservationCount);
                }
            }
            EvidenceDuration::UnspecifiedWithReason { reason } => {
                require_non_empty("duration.reason", reason)?;
            }
        }

        if let Some(signature) = &self.signature {
            require_non_empty("signature.algorithm", &signature.algorithm)?;
            require_non_empty("signature.key_id", &signature.key_id)?;
            require_non_empty("signature.value_base64", &signature.value_base64)?;

            if signature.key_id != self.review.reviewer_key_id {
                return Err(ManifestValidationError::SignatureKeyMismatch);
            }
        }

        Ok(())
    }
}

fn require_non_empty(
    field: &'static str,
    value: &str,
) -> Result<(), ManifestValidationError> {
    if value.trim().is_empty() {
        Err(ManifestValidationError::EmptyField(field))
    } else {
        Ok(())
    }
}

fn validate_sha256(hash: &HashDigest) -> Result<(), ManifestValidationError> {
    if hash.algorithm != "sha256" {
        return Err(ManifestValidationError::InvalidHashAlgorithm);
    }

    if hash.value_hex.len() != 64 {
        return Err(ManifestValidationError::InvalidHashLength);
    }

    if !hash.value_hex.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(ManifestValidationError::InvalidHashCharacters);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn digest(value: char) -> HashDigest {
        HashDigest {
            algorithm: "sha256".to_owned(),
            value_hex: value.to_string().repeat(64),
        }
    }

    fn valid_manifest() -> EvidenceManifestV1 {
        EvidenceManifestV1 {
            manifest_version: "EvidenceManifest.v1".to_owned(),
            manifest_id: "evidence-manifest-example".to_owned(),
            subject: Subject {
                logical_name: "research-object".to_owned(),
                media_type: "application/json".to_owned(),
                content_hash: digest('a'),
            },
            source: SourceReference {
                source_id: "source-local-001".to_owned(),
                source_kind: "repository_record".to_owned(),
                access_basis: "public_or_authorized".to_owned(),
                retrieved_at_utc: "2026-09-03T00:00:00Z".to_owned(),
            },
            evidence_level: EvidenceLevel::MethodNote,
            context: ResearchContext {
                domain: "research-provenance".to_owned(),
                tissue_context: None,
                scope_note: "Research context only; no personal inference.".to_owned(),
            },
            duration: EvidenceDuration::Interval {
                started_at_utc: "2026-09-01T00:00:00Z".to_owned(),
                ended_at_utc: "2026-09-02T00:00:00Z".to_owned(),
            },
            limitations: vec![
                "The manifest records provenance and review scope, not factual certainty."
                    .to_owned(),
            ],
            review: ReviewRecord {
                reviewer_role: "evidence_reviewer".to_owned(),
                reviewer_key_id: "review-key-01".to_owned(),
                reviewed_at_utc: "2026-09-03T00:00:00Z".to_owned(),
                review_outcome: "scope-reviewed".to_owned(),
            },
            previous_manifest_hash: None,
            signature: Some(DetachedSignature {
                algorithm: "ed25519".to_owned(),
                key_id: "review-key-01".to_owned(),
                value_base64: "c2lnbmF0dXJl".to_owned(),
            }),
        }
    }

    #[test]
    fn accepts_a_valid_privacy_bounded_manifest() {
        assert_eq!(valid_manifest().validate(), Ok(()));
    }

    #[test]
    fn requires_limitations() {
        let mut manifest = valid_manifest();
        manifest.limitations.clear();

        assert_eq!(
            manifest.validate(),
            Err(ManifestValidationError::MissingLimitations)
        );
    }

    #[test]
    fn rejects_signature_key_mismatch() {
        let mut manifest = valid_manifest();
        manifest
            .signature
            .as_mut()
            .expect("signature is present")
            .key_id = "different-key".to_owned();

        assert_eq!(
            manifest.validate(),
            Err(ManifestValidationError::SignatureKeyMismatch)
        );
    }

    #[test]
    fn rejects_reversed_intervals() {
        let mut manifest = valid_manifest();
        manifest.duration = EvidenceDuration::Interval {
            started_at_utc: "2026-09-03T00:00:00Z".to_owned(),
            ended_at_utc: "2026-09-02T00:00:00Z".to_owned(),
        };

        assert_eq!(
            manifest.validate(),
            Err(ManifestValidationError::InvalidDuration)
        );
    }
}
