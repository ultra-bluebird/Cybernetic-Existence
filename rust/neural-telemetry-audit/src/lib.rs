#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum AuditDecision {
    Permitted,
    Denied,
    Revoked,
    Expired,
    ReviewRequired,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AuditEvent {
    pub event_id: String,
    pub sequence: u64,
    pub event_time_utc: String,
    pub actor_role: String,
    pub asset_class: String,
    pub purpose: String,
    pub scope_hash_sha256: String,
    pub authorization_reference: String,
    pub policy_version: String,
    pub decision: AuditDecision,
    pub reason_code: String,
    pub output_class: String,
    pub previous_event_hash_sha256: Option<String>,
    pub event_hash_sha256: String,
    pub signature_key_id: String,
    pub signature_base64: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuditValidationError {
    EmptyField(&'static str),
    InvalidHash,
    InvalidSequence,
    MissingPreviousHash,
    UnexpectedPreviousHash,
    MissingSignature,
}

impl AuditEvent {
    pub fn validate_shape(&self) -> Result<(), AuditValidationError> {
        require_non_empty("event_id", &self.event_id)?;
        require_non_empty("event_time_utc", &self.event_time_utc)?;
        require_non_empty("actor_role", &self.actor_role)?;
        require_non_empty("asset_class", &self.asset_class)?;
        require_non_empty("purpose", &self.purpose)?;
        require_non_empty("authorization_reference", &self.authorization_reference)?;
        require_non_empty("policy_version", &self.policy_version)?;
        require_non_empty("reason_code", &self.reason_code)?;
        require_non_empty("output_class", &self.output_class)?;
        require_non_empty("signature_key_id", &self.signature_key_id)?;
        require_non_empty("signature_base64", &self.signature_base64)?;

        validate_sha256(&self.scope_hash_sha256)?;
        validate_sha256(&self.event_hash_sha256)?;

        if self.sequence == 0 && self.previous_event_hash_sha256.is_some() {
            return Err(AuditValidationError::UnexpectedPreviousHash);
        }

        if self.sequence > 0 && self.previous_event_hash_sha256.is_none() {
            return Err(AuditValidationError::MissingPreviousHash);
        }

        if let Some(previous) = &self.previous_event_hash_sha256 {
            validate_sha256(previous)?;
        }

        Ok(())
    }
}

fn require_non_empty(
    field: &'static str,
    value: &str,
) -> Result<(), AuditValidationError> {
    if value.trim().is_empty() {
        Err(AuditValidationError::EmptyField(field))
    } else {
        Ok(())
    }
}

fn validate_sha256(value: &str) -> Result<(), AuditValidationError> {
    if value.len() != 64 || !value.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(AuditValidationError::InvalidHash);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hash(value: char) -> String {
        value.to_string().repeat(64)
    }

    fn event(sequence: u64, previous: Option<String>) -> AuditEvent {
        AuditEvent {
            event_id: "audit-event-example".to_owned(),
            sequence,
            event_time_utc: "2026-09-03T00:00:00Z".to_owned(),
            actor_role: "authorized_local_processor".to_owned(),
            asset_class: "derived_feature".to_owned(),
            purpose: "authorized_local_analysis".to_owned(),
            scope_hash_sha256: hash('a'),
            authorization_reference: "consent-scope-example".to_owned(),
            policy_version: "data-governance-v1".to_owned(),
            decision: AuditDecision::Permitted,
            reason_code: "PURPOSE_AND_SCOPE_PERMITTED".to_owned(),
            output_class: "local_only".to_owned(),
            previous_event_hash_sha256: previous,
            event_hash_sha256: hash('b'),
            signature_key_id: "audit-key-example".to_owned(),
            signature_base64: "c2lnbmF0dXJl".to_owned(),
        }
    }

    #[test]
    fn accepts_well_formed_genesis_event() {
        assert_eq!(event(0, None).validate_shape(), Ok(()));
    }

    #[test]
    fn rejects_non_genesis_event_without_previous_hash() {
        assert_eq!(
            event(1, None).validate_shape(),
            Err(AuditValidationError::MissingPreviousHash)
        );
    }

    #[test]
    fn rejects_genesis_event_with_previous_hash() {
        assert_eq!(
            event(0, Some(hash('c'))).validate_shape(),
            Err(AuditValidationError::UnexpectedPreviousHash)
        );
    }

    #[test]
    fn rejects_invalid_hash() {
        let mut invalid = event(0, None);
        invalid.scope_hash_sha256 = "not-a-valid-hash".to_owned();

        assert_eq!(
            invalid.validate_shape(),
            Err(AuditValidationError::InvalidHash)
        );
    }
}
