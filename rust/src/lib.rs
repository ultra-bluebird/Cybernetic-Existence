//! Augmented-Hub non-actuating, privacy-preserving research components.
//!
//! This crate provides local policy, evidence-assessment, attribution, portability,
//! and continuity-record modules. It does not control hardware, transit systems,
//! bodies, medical devices, companion systems, or external services.
//!
//! # Modules
//!
//! - [`privacy`] — Purpose-bound, consent-aware aggregate-release policy models.
//! - [`safety`] — Non-actuating safety-evidence assessment models.
//! - [`sovereign_continuity_anchor`] — Signed, witnessed, replicated continuity-anchor records.
//! - [`signed_attribution_edge`] — Scoped, witnessed attribution and derivation records.
//! - [`identity_portability`] — Consent-bound cross-protocol reference portability.
//! - [`sovereign_continuity_audit_log`] — Append-only continuity audit-record validation.
//!
//! # Boundaries
//!
//! - No raw telemetry, secrets, private keys, bearer tokens, full consent records,
//!   identity linkage, or public-status handling.
//! - All modules preserve claim-fact separation: they can validate record structure,
//!   provenance references, policy constraints, and declared signatures, but they do
//!   not certify identity, consciousness, bodily continuity, cybernetic status,
//!   real-world host migration, legal ownership, or institutional authority.
//! - Assessment and validation outputs are evidence for human review. They are not
//!   certification, operational authorization, eligibility determination, ranking,
//!   diagnosis, physical command, or automated external action.

#![forbid(unsafe_code)]
#![deny(
    clippy::all,
    clippy::cargo,
    clippy::nursery,
    clippy::pedantic,
    rust_2018_idioms,
    unused_lifetimes,
    unused_qualifications
)]
#![allow(
    clippy::module_name_repetitions,
    clippy::must_use_candidate,
    clippy::missing_errors_doc,
    clippy::missing_panics_doc
)]

pub mod identity_portability;
pub mod privacy;
pub mod safety;
pub mod signed_attribution_edge;
pub mod sovereign_continuity_anchor;
pub mod sovereign_continuity_audit_log;

pub use identity_portability::{
    IdentityPortabilityFunctor, IdentityProtocol, PortabilityError, ProtocolBinding,
};
pub use signed_attribution_edge::{
    AttributionError, AttributionRelationship, AttributionScope, AttributionWitness,
    SignedAttributionEdge,
};
pub use sovereign_continuity_anchor::{
    AnchorError, ContentReference, ReplicationTarget, SovereignContinuityAnchor,
    WitnessAttestation, WitnessReference,
};
pub use sovereign_continuity_audit_log::{
    AuditError, AuditEventKind, AuditWitness, MerkleAuditEntry,
};

#[cfg(test)]
mod module_wiring_tests {
    use super::{
        AttributionRelationship, AttributionScope, AttributionWitness, AuditEventKind,
        AuditWitness, ContentReference, IdentityPortabilityFunctor, IdentityProtocol,
        MerkleAuditEntry, ProtocolBinding, ReplicationTarget, SignedAttributionEdge,
        SovereignContinuityAnchor, WitnessAttestation, WitnessReference,
    };

    #[test]
    fn provenance_continuity_modules_are_publicly_wired() {
        let anchor = SovereignContinuityAnchor {
            anchor_reference: "anchor:continuity:wiring-test".to_owned(),
            subject_reference: "subject:local:wiring-test".to_owned(),
            canonical_content: ContentReference::new("cid:anchor-content").unwrap(),
            policy_bundle: ContentReference::new("cid:policy-bundle").unwrap(),
            witnesses: vec![WitnessAttestation {
                witness: WitnessReference::new("witness:local:one").unwrap(),
                attestation_reference: ContentReference::new("cid:anchor-witness").unwrap(),
                signed_at_rfc3339: "2026-09-26T07:17:00Z".to_owned(),
            }],
            replication_targets: vec![ReplicationTarget::LocalArchive],
            public_replication_approved: false,
            identity_certification_claimed: false,
            consciousness_certification_claimed: false,
            cybernetic_status_certification_claimed: false,
            host_migration_certification_claimed: false,
        };
        assert!(anchor.validate().is_ok());

        let attribution = SignedAttributionEdge {
            edge_id: "edge:wiring-test".to_owned(),
            parent_references: vec!["cid:parent".to_owned()],
            child_references: vec!["cid:child".to_owned()],
            relationship: AttributionRelationship::DerivedFrom,
            scope: AttributionScope::WholeWork,
            inheritance_rules: vec!["attribution_required".to_owned()],
            created_at_rfc3339: "2026-09-26T07:17:00Z".to_owned(),
            witnesses: vec![AttributionWitness {
                witness_reference: "witness:local:one".to_owned(),
                signature_reference: "cid:attribution-witness".to_owned(),
                signed_at_rfc3339: "2026-09-26T07:17:00Z".to_owned(),
            }],
            signature_reference: "cid:attribution-signature".to_owned(),
            identity_certification_claimed: false,
        };
        assert!(attribution.validate().is_ok());

        let portability = IdentityPortabilityFunctor {
            portable_subject_reference: "subject:local:wiring-test".to_owned(),
            source_binding: ProtocolBinding {
                protocol: IdentityProtocol::Did,
                subject_reference: "did:example:source".to_owned(),
                public_key_or_did_reference: "did:example:source#key-1".to_owned(),
                provenance_reference: "cid:source-binding".to_owned(),
                portability_scope: "public-attribution-only".to_owned(),
                consent_scope_reference: "cid:consent".to_owned(),
            },
            target_binding: ProtocolBinding {
                protocol: IdentityProtocol::Nostr,
                subject_reference: "nostr:npub-example".to_owned(),
                public_key_or_did_reference: "nostr:npub-example".to_owned(),
                provenance_reference: "cid:target-binding".to_owned(),
                portability_scope: "public-attribution-only".to_owned(),
                consent_scope_reference: "cid:consent".to_owned(),
            },
            mapping_reference: "cid:portability-mapping".to_owned(),
            policy_bundle_reference: "cid:policy-bundle".to_owned(),
            identity_verification_claimed: false,
            identity_adjudication_permitted: false,
        };
        assert!(portability.validate().is_ok());

        let genesis = MerkleAuditEntry {
            sequence: 0,
            event_id: "event:wiring-test:0".to_owned(),
            event_kind: AuditEventKind::CommitmentRegistered,
            previous_entry_reference: None,
            event_content_reference: "cid:audit-event-content".to_owned(),
            merkle_root_reference: "cid:audit-merkle-root".to_owned(),
            policy_bundle_reference: "cid:policy-bundle".to_owned(),
            witnesses: vec![AuditWitness {
                witness_reference: "witness:local:one".to_owned(),
                cosignature_reference: "cid:audit-cosignature".to_owned(),
                witnessed_at_rfc3339: "2026-09-26T07:17:00Z".to_owned(),
            }],
            recorded_at_rfc3339: "2026-09-26T07:17:00Z".to_owned(),
            identity_certification_claimed: false,
            continuity_certification_claimed: false,
            host_migration_certification_claimed: false,
        };
        assert!(genesis.validate_against_previous(None).is_ok());
    }
}
