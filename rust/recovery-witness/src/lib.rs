#![forbid(unsafe_code)]

use serde::Serialize;
use thiserror::Error;

pub const MAX_LOCAL_RECORDS: usize = 256;
pub const MAX_SESSION_PSEUDONYM_BYTES: usize = 128;
pub const MAX_POLICY_VERSION_BYTES: usize = 128;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum EndReason {
    Timeout,
    UserRevocation,
    MalformedInput,
    IntegrityFailure,
}

impl EndReason {
    pub fn code(self) -> &'static str {
        match self {
            Self::Timeout => "TIMEOUT",
            Self::UserRevocation => "USER_REVOCATION",
            Self::MalformedInput => "MALFORMED_INPUT",
            Self::IntegrityFailure => "INTEGRITY_FAILURE",
        }
    }

    pub fn local_explanation(self) -> &'static str {
        match self {
            Self::Timeout => "The session ended because its allowed time expired.",
            Self::UserRevocation => "The session ended because consent was revoked.",
            Self::MalformedInput => "The session ended because an invalid message was rejected.",
            Self::IntegrityFailure => "The session ended because an integrity check failed.",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct RecoveryRecord {
    pub event_type: &'static str,
    pub event_time_unix_s: u64,
    pub session_pseudonym: String,
    pub policy_ver: String,
    pub outcome: &'static str,
    pub reason_code: &'static str,
    pub protected_release_completed: bool,
    pub retention_class: &'static str,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum RecoveryError {
    #[error("session pseudonym is missing or too long")]
    InvalidSessionPseudonym,
    #[error("policy version is missing or too long")]
    InvalidPolicyVersion,
}

#[derive(Debug, Default)]
pub struct RecoveryWitness {
    records: Vec<RecoveryRecord>,
}

impl RecoveryWitness {
    pub fn record_end(
        &mut self,
        event_time_unix_s: u64,
        session_pseudonym: &str,
        policy_ver: &str,
        reason: EndReason,
    ) -> Result<RecoveryRecord, RecoveryError> {
        validate(session_pseudonym, MAX_SESSION_PSEUDONYM_BYTES)
            .map_err(|_| RecoveryError::InvalidSessionPseudonym)?;
        validate(policy_ver, MAX_POLICY_VERSION_BYTES)
            .map_err(|_| RecoveryError::InvalidPolicyVersion)?;

        let record = RecoveryRecord {
            event_type: "SESSION_ENDED",
            event_time_unix_s,
            session_pseudonym: session_pseudonym.to_owned(),
            policy_ver: policy_ver.to_owned(),
            outcome: "BLOCKED",
            reason_code: reason.code(),
            protected_release_completed: false,
            retention_class: "OPERATIONAL_30D",
        };

        if self.records.len() == MAX_LOCAL_RECORDS {
            self.records.remove(0);
        }
        self.records.push(record.clone());
        Ok(record)
    }

    pub fn local_status(record: &RecoveryRecord) -> String {
        let reason = match record.reason_code {
            "TIMEOUT" => EndReason::Timeout,
            "USER_REVOCATION" => EndReason::UserRevocation,
            "MALFORMED_INPUT" => EndReason::MalformedInput,
            "INTEGRITY_FAILURE" => EndReason::IntegrityFailure,
            _ => return "The session ended for an unrecognized local reason code.".to_owned(),
        };

        format!(
            "{} No protected release was completed. A new session requires a new authorization.",
            reason.local_explanation()
        )
    }

    pub fn records(&self) -> &[RecoveryRecord] {
        &self.records
    }
}

fn validate(value: &str, maximum: usize) -> Result<(), ()> {
    if value.is_empty() || value.len() > maximum {
        return Err(());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn malformed_input_record_contains_no_payload() {
        let mut witness = RecoveryWitness::default();
        let record = witness
            .record_end(100, "session-pseudo-a", "policy-1", EndReason::MalformedInput)
            .unwrap();

        let serialized = serde_json::to_string(&record).unwrap();
        assert!(!serialized.contains("payload"));
        assert!(!serialized.contains("plaintext"));
        assert!(!serialized.contains("ciphertext"));
        assert_eq!(record.protected_release_completed, false);
    }

    #[test]
    fn recovery_status_is_plain_language() {
        let mut witness = RecoveryWitness::default();
        let record = witness
            .record_end(100, "session-pseudo-a", "policy-1", EndReason::UserRevocation)
            .unwrap();

        assert!(RecoveryWitness::local_status(&record).contains("consent was revoked"));
    }

    #[test]
    fn witness_record_capacity_is_bounded() {
        let mut witness = RecoveryWitness::default();

        for index in 0..=MAX_LOCAL_RECORDS {
            witness
                .record_end(
                    index as u64,
                    &format!("session-{index}"),
                    "policy-1",
                    EndReason::Timeout,
                )
                .unwrap();
        }

        assert_eq!(witness.records().len(), MAX_LOCAL_RECORDS);
        assert_eq!(witness.records()[0].session_pseudonym, "session-1");
    }
}
