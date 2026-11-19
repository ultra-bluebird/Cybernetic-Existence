#![forbid(unsafe_code)]

//! Local-first authorization and revocation checks for high-sensitivity data.
//!
//! This crate enforces policy metadata only. It does not inspect, transmit,
//! decode, store, or classify neural, medical, biometric, or physiological data.

use std::collections::BTreeSet;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DataClass {
    LocalOnly,
    DerivedLocal,
    AggregateReleaseCandidate,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConsentGrant {
    pub consent_id: String,
    pub subject_reference: String,
    pub revocation_epoch: u64,
    pub purposes: BTreeSet<String>,
    pub recipients: BTreeSet<String>,
    pub expires_at_unix_seconds: u64,
    pub data_classes: BTreeSet<DataClass>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AccessRequest<'a> {
    pub consent_id: &'a str,
    pub purpose: &'a str,
    pub recipient: &'a str,
    pub required_epoch: u64,
    pub requested_data_class: DataClass,
    pub requested_at_unix_seconds: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AccessDecision {
    AllowLocalProcessing,
    DenyExpired,
    DenyRevoked,
    DenyPurpose,
    DenyRecipient,
    DenyDataClass,
}

impl ConsentGrant {
    pub fn decide(&self, request: AccessRequest<'_>) -> AccessDecision {
        if request.requested_at_unix_seconds >= self.expires_at_unix_seconds {
            return AccessDecision::DenyExpired;
        }

        if request.required_epoch != self.revocation_epoch {
            return AccessDecision::DenyRevoked;
        }

        if !self.purposes.contains(request.purpose) {
            return AccessDecision::DenyPurpose;
        }

        if !self.recipients.contains(request.recipient) {
            return AccessDecision::DenyRecipient;
        }

        if request.requested_data_class == DataClass::LocalOnly {
            return AccessDecision::DenyDataClass;
        }

        if !self.data_classes.contains(&request.requested_data_class) {
            return AccessDecision::DenyDataClass;
        }

        AccessDecision::AllowLocalProcessing
    }

    pub fn revoke(mut self) -> Self {
        self.revocation_epoch = self.revocation_epoch.saturating_add(1);
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn grant() -> ConsentGrant {
        ConsentGrant {
            consent_id: "consent-001".to_owned(),
            subject_reference: "urn:subject:opaque-001".to_owned(),
            revocation_epoch: 4,
            purposes: BTreeSet::from(["aggregate-calibration".to_owned()]),
            recipients: BTreeSet::from(["local-policy-kernel".to_owned()]),
            expires_at_unix_seconds: 2_000_000_000,
            data_classes: BTreeSet::from([DataClass::AggregateReleaseCandidate]),
        }
    }

    #[test]
    fn raw_local_only_data_is_never_authorized_for_export_request() {
        let decision = grant().decide(AccessRequest {
            consent_id: "consent-001",
            purpose: "aggregate-calibration",
            recipient: "local-policy-kernel",
            required_epoch: 4,
            requested_data_class: DataClass::LocalOnly,
            requested_at_unix_seconds: 1_900_000_000,
        });

        assert_eq!(decision, AccessDecision::DenyDataClass);
    }

    #[test]
    fn old_capability_epoch_is_rejected_after_revocation() {
        let revoked = grant().revoke();

        let decision = revoked.decide(AccessRequest {
            consent_id: "consent-001",
            purpose: "aggregate-calibration",
            recipient: "local-policy-kernel",
            required_epoch: 4,
            requested_data_class: DataClass::AggregateReleaseCandidate,
            requested_at_unix_seconds: 1_900_000_000,
        });

        assert_eq!(decision, AccessDecision::DenyRevoked);
    }
}
