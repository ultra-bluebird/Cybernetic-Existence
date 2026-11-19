#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum EvidenceScope {
    CanonicalBytes,
    SignatureValidity,
    DeclaredParentLink,
    ScopedConsentRecord,
    InvariantEvaluation,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum ProhibitedInference {
    RealWorldIdentity,
    Personhood,
    Consciousness,
    MedicalStatus,
    CyberneticStatus,
    ContinuityDetermination,
    LegalAuthority,
    InstitutionalEligibility,
    ServiceAccessDecision,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct RelianceBoundary {
    pub evidence_scope: Vec<EvidenceScope>,
    pub prohibited_inferences: Vec<ProhibitedInference>,
    pub requires_human_review: bool,
    pub external_actuation_allowed: bool,
    pub institutional_decision_allowed: bool,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct EvidenceAssessment {
    pub canonical_bytes_valid: bool,
    pub signature_valid: bool,
    pub declared_parent_link_valid: bool,
    pub consent_record_present: bool,
    pub invariant_evaluation_present: bool,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct RelianceResult {
    pub accepted_as_technical_evidence: bool,
    pub prohibited_inferences: Vec<ProhibitedInference>,
    pub external_actuation_allowed: bool,
    pub institutional_decision_allowed: bool,
    pub human_review_required: bool,
}

impl RelianceBoundary {
    pub fn private_default() -> Self {
        Self {
            evidence_scope: vec![
                EvidenceScope::CanonicalBytes,
                EvidenceScope::SignatureValidity,
                EvidenceScope::DeclaredParentLink,
                EvidenceScope::ScopedConsentRecord,
                EvidenceScope::InvariantEvaluation,
            ],
            prohibited_inferences: vec![
                ProhibitedInference::RealWorldIdentity,
                ProhibitedInference::Personhood,
                ProhibitedInference::Consciousness,
                ProhibitedInference::MedicalStatus,
                ProhibitedInference::CyberneticStatus,
                ProhibitedInference::ContinuityDetermination,
                ProhibitedInference::LegalAuthority,
                ProhibitedInference::InstitutionalEligibility,
                ProhibitedInference::ServiceAccessDecision,
            ],
            requires_human_review: true,
            external_actuation_allowed: false,
            institutional_decision_allowed: false,
        }
    }

    pub fn assess(&self, evidence: &EvidenceAssessment) -> RelianceResult {
        let accepted_as_technical_evidence = evidence.canonical_bytes_valid
            && evidence.signature_valid
            && evidence.declared_parent_link_valid
            && evidence.consent_record_present
            && evidence.invariant_evaluation_present;

        RelianceResult {
            accepted_as_technical_evidence,
            prohibited_inferences: self.prohibited_inferences.clone(),
            external_actuation_allowed: self.external_actuation_allowed,
            institutional_decision_allowed: self.institutional_decision_allowed,
            human_review_required: self.requires_human_review,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_evidence_does_not_become_an_identity_or_eligibility_decision() {
        let boundary = RelianceBoundary::private_default();
        let evidence = EvidenceAssessment {
            canonical_bytes_valid: true,
            signature_valid: true,
            declared_parent_link_valid: true,
            consent_record_present: true,
            invariant_evaluation_present: true,
        };

        let result = boundary.assess(&evidence);

        assert!(result.accepted_as_technical_evidence);
        assert!(!result.external_actuation_allowed);
        assert!(!result.institutional_decision_allowed);
        assert!(result.human_review_required);
        assert!(
            result
                .prohibited_inferences
                .contains(&ProhibitedInference::RealWorldIdentity)
        );
        assert!(
            result
                .prohibited_inferences
                .contains(&ProhibitedInference::InstitutionalEligibility)
        );
    }

    #[test]
    fn incomplete_evidence_is_not_accepted_as_technical_evidence() {
        let boundary = RelianceBoundary::private_default();
        let evidence = EvidenceAssessment {
            canonical_bytes_valid: true,
            signature_valid: false,
            declared_parent_link_valid: true,
            consent_record_present: true,
            invariant_evaluation_present: true,
        };

        let result = boundary.assess(&evidence);

        assert!(!result.accepted_as_technical_evidence);
        assert!(!result.external_actuation_allowed);
        assert!(!result.institutional_decision_allowed);
    }
}
