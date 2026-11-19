#![forbid(unsafe_code)]

//! Deterministic evidence-package construction.
//!
//! This crate constructs a canonical package payload for use with an approved
//! external integrity adapter. It does not claim to prove a statement true,
//! establish identity, issue legal authority, or make clinical determinations.

use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClaimPackageDraft {
    pub package_id: String,
    pub claim_id: String,
    pub claim_kind: String,
    pub statement: String,
    pub scope: String,
    pub source_reference: String,
    pub holder_or_issuer_reference: String,
    pub created_at: String,
    pub non_clinical: bool,
    pub limitations: Vec<String>,
    pub attributes: BTreeMap<String, String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PackageError {
    EmptyRequiredField,
    MissingLimitation,
    InvalidClaimKind,
}

impl ClaimPackageDraft {
    pub fn validate(&self) -> Result<(), PackageError> {
        let required = [
            &self.package_id,
            &self.claim_id,
            &self.claim_kind,
            &self.statement,
            &self.scope,
            &self.source_reference,
            &self.holder_or_issuer_reference,
            &self.created_at,
        ];

        if required.iter().any(|value| value.trim().is_empty()) {
            return Err(PackageError::EmptyRequiredField);
        }

        if self.limitations.is_empty() {
            return Err(PackageError::MissingLimitation);
        }

        match self.claim_kind.as_str() {
            "holder_self_attestation"
            | "technical_research_claim"
            | "independent_reviewer_statement"
            | "issuer_credential_claim"
            | "procedural_claim" => Ok(()),
            _ => Err(PackageError::InvalidClaimKind),
        }
    }

    pub fn canonical_payload(&self) -> Result<String, PackageError> {
        self.validate()?;

        let mut lines = vec![
            format!("package_id={}", self.package_id.trim()),
            format!("claim_id={}", self.claim_id.trim()),
            format!("claim_kind={}", self.claim_kind.trim()),
            format!("statement={}", self.statement.trim()),
            format!("scope={}", self.scope.trim()),
            format!("source_reference={}", self.source_reference.trim()),
            format!(
                "holder_or_issuer_reference={}",
                self.holder_or_issuer_reference.trim()
            ),
            format!("created_at={}", self.created_at.trim()),
            format!("non_clinical={}", self.non_clinical),
        ];

        let mut limitations = self
            .limitations
            .iter()
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .collect::<Vec<_>>();

        limitations.sort_unstable();

        for limitation in limitations {
            lines.push(format!("limitation={limitation}"));
        }

        for (key, value) in &self.attributes {
            lines.push(format!("attribute.{key}={value}"));
        }

        Ok(lines.join("\n"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_payload_sorts_attributes_and_limitations() {
        let draft = ClaimPackageDraft {
            package_id: "urn:evidence-package:example:001".to_owned(),
            claim_id: "urn:claim:example:001".to_owned(),
            claim_kind: "technical_research_claim".to_owned(),
            statement: "A bounded technical claim.".to_owned(),
            scope: "Research documentation only.".to_owned(),
            source_reference: "urn:source:example:001".to_owned(),
            holder_or_issuer_reference: "urn:holder:example:001".to_owned(),
            created_at: "2026-09-24T00:00:00Z".to_owned(),
            non_clinical: true,
            limitations: vec![
                "Not a legal determination.".to_owned(),
                "Not a medical determination.".to_owned(),
            ],
            attributes: BTreeMap::from([
                ("purpose".to_owned(), "research".to_owned()),
                ("version".to_owned(), "1".to_owned()),
            ]),
        };

        let canonical = draft.canonical_payload().expect("valid draft");

        assert!(canonical.contains("attribute.purpose=research"));
        assert!(canonical.contains("attribute.version=1"));
        assert!(canonical.contains("limitation=Not a legal determination."));
    }
}
