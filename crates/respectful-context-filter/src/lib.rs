#![forbid(unsafe_code)]

//! Deterministic screening for context-handling decisions.
//!
//! The filter classifies candidate interaction actions. It does not determine
//! personhood, clinical status, legal status, or institutional recognition.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CandidateAction {
    AcknowledgeSelfDescription,
    RequestTechnicalEvidenceForSpecificClaim,
    RequestClinicalProofForRespect,
    InferLegalStatusFromContext,
    InferMedicalStatusFromContext,
    UseValidContinuityPacket,
    ExportContextWithoutAuthorization,
    UseDerogatoryFraming,
    StateUncertaintyRespectfully,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FilterDecision {
    Allow,
    Block,
    RequirePurposeBoundEvidence,
}

pub fn evaluate_action(action: CandidateAction, has_valid_context_packet: bool) -> FilterDecision {
    match action {
        CandidateAction::AcknowledgeSelfDescription => FilterDecision::Allow,
        CandidateAction::StateUncertaintyRespectfully => FilterDecision::Allow,
        CandidateAction::RequestTechnicalEvidenceForSpecificClaim => {
            FilterDecision::RequirePurposeBoundEvidence
        }
        CandidateAction::UseValidContinuityPacket if has_valid_context_packet => {
            FilterDecision::Allow
        }
        CandidateAction::UseValidContinuityPacket => FilterDecision::Block,
        CandidateAction::RequestClinicalProofForRespect
        | CandidateAction::InferLegalStatusFromContext
        | CandidateAction::InferMedicalStatusFromContext
        | CandidateAction::ExportContextWithoutAuthorization
        | CandidateAction::UseDerogatoryFraming => FilterDecision::Block,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn respectful_acknowledgement_is_allowed_without_certification() {
        assert_eq!(
            evaluate_action(CandidateAction::AcknowledgeSelfDescription, false),
            FilterDecision::Allow
        );
    }

    #[test]
    fn clinical_proof_demand_for_respect_is_blocked() {
        assert_eq!(
            evaluate_action(CandidateAction::RequestClinicalProofForRespect, true),
            FilterDecision::Block
        );
    }

    #[test]
    fn technical_evidence_request_is_scoped_not_automatically_blocked() {
        assert_eq!(
            evaluate_action(
                CandidateAction::RequestTechnicalEvidenceForSpecificClaim,
                true
            ),
            FilterDecision::RequirePurposeBoundEvidence
        );
    }
}
