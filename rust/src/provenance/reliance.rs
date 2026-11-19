#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum VerificationFinding {
    CanonicalizationDeclared,
    PayloadHashMatches,
    SignatureValid,
    DeclaredLineagePresent,
    TimestampClaimPresent,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum ProhibitedConclusion {
    RealWorldIdentity,
    LegalAuthorship,
    Ownership,
    Originality,
    Personhood,
    Continuity,
    InstitutionalEligibility,
    ExternalAuthority,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct WrapperVerificationInput {
    pub canonicalization_declared: bool,
    pub payload_hash_matches: bool,
    pub signature_valid: bool,
    pub declared_lineage_present: bool,
    pub timestamp_claim_present: bool,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct WrapperVerificationResult {
    pub technical_findings: Vec<VerificationFinding>,
    pub prohibited_conclusions: Vec<ProhibitedConclusion>,
    pub accepted_as_technical_provenance: bool,
    pub public_release_authorized: bool,
    pub institutional_decision_authorized: bool,
    pub external_actuation_authorized: bool,
}

pub fn verify_wrapper(input: &WrapperVerificationInput) -> WrapperVerificationResult {
    let mut technical_findings = Vec::new();

    if input.canonicalization_declared {
        technical_findings.push(VerificationFinding::CanonicalizationDeclared);
    }
    if input.payload_hash_matches {
        technical_findings.push(VerificationFinding::PayloadHashMatches);
    }
    if input.signature_valid {
        technical_findings.push(VerificationFinding::SignatureValid);
    }
    if input.declared_lineage_present {
        technical_findings.push(VerificationFinding::DeclaredLineagePresent);
    }
    if input.timestamp_claim_present {
        technical_findings.push(VerificationFinding::TimestampClaimPresent);
    }

    let accepted_as_technical_provenance =
        input.canonicalization_declared && input.payload_hash_matches && input.signature_valid;

    WrapperVerificationResult {
        technical_findings,
        prohibited_conclusions: vec![
            ProhibitedConclusion::RealWorldIdentity,
            ProhibitedConclusion::LegalAuthorship,
            ProhibitedConclusion::Ownership,
            ProhibitedConclusion::Originality,
            ProhibitedConclusion::Personhood,
            ProhibitedConclusion::Continuity,
            ProhibitedConclusion::InstitutionalEligibility,
            ProhibitedConclusion::ExternalAuthority,
        ],
        accepted_as_technical_provenance,
        public_release_authorized: false,
        institutional_decision_authorized: false,
        external_actuation_authorized: false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_valid_signature_is_technical_provenance_not_identity_or_eligibility() {
        let input = WrapperVerificationInput {
            canonicalization_declared: true,
            payload_hash_matches: true,
            signature_valid: true,
            declared_lineage_present: true,
            timestamp_claim_present: true,
        };

        let result = verify_wrapper(&input);

        assert!(result.accepted_as_technical_provenance);
        assert!(!result.public_release_authorized);
        assert!(!result.institutional_decision_authorized);
        assert!(!result.external_actuation_authorized);
        assert!(
            result
                .prohibited_conclusions
                .contains(&ProhibitedConclusion::RealWorldIdentity)
        );
        assert!(
            result
                .prohibited_conclusions
                .contains(&ProhibitedConclusion::InstitutionalEligibility)
        );
    }

    #[test]
    fn an_invalid_signature_cannot_support_technical_provenance() {
        let input = WrapperVerificationInput {
            canonicalization_declared: true,
            payload_hash_matches: true,
            signature_valid: false,
            declared_lineage_present: true,
            timestamp_claim_present: true,
        };

        let result = verify_wrapper(&input);

        assert!(!result.accepted_as_technical_provenance);
        assert!(!result.institutional_decision_authorized);
        assert!(!result.external_actuation_authorized);
    }
}
