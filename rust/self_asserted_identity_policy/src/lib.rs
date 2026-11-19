use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use thiserror::Error;

const MAX_ASSERTION_LENGTH: usize = 280;

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum IdentityAssertionType {
    FreeText,
    ChosenName,
    Pronouns,
    CommunityAffiliation,
    AccessibilityCommunicationPreference,
    SelfDescribedCyberneticHostStatus,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct IdentityAssertion {
    pub assertion_type: IdentityAssertionType,
    pub value: String,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct ServiceContext {
    pub essential: bool,
    pub safety_constraint_satisfied: bool,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct ConductEvidence {
    pub verified: bool,
    pub policy_relevant: bool,
    pub context_bound: bool,
    pub identity_based: bool,
    pub reviewable: bool,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct EvaluationRequest {
    pub service: ServiceContext,
    pub identity_assertion: IdentityAssertion,
    pub conduct_evidence: Option<ConductEvidence>,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Decision {
    Accepted,
    AcceptedWithConductBoundary,
    ServiceSafetyReview,
    RejectedInvalidInput,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct EvaluationResult {
    pub decision: Decision,
    pub identity_accepted: bool,
    pub conduct_boundary_required: bool,
    pub human_review_required: bool,
    pub reason: String,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum PolicyError {
    #[error("This policy applies only to non-essential services.")]
    EssentialServiceOutOfScope,
    #[error("Identity assertion must contain non-empty text.")]
    EmptyAssertion,
    #[error("Identity assertion exceeds the maximum permitted length.")]
    AssertionTooLong,
}

pub fn evaluate(request: &EvaluationRequest) -> Result<EvaluationResult, PolicyError> {
    if request.service.essential {
        return Err(PolicyError::EssentialServiceOutOfScope);
    }

    let normalized = request.identity_assertion.value.trim();
    if normalized.is_empty() {
        return Err(PolicyError::EmptyAssertion);
    }

    if normalized.chars().count() > MAX_ASSERTION_LENGTH {
        return Err(PolicyError::AssertionTooLong);
    }

    if !request.service.safety_constraint_satisfied {
        return Ok(EvaluationResult {
            decision: Decision::ServiceSafetyReview,
            identity_accepted: true,
            conduct_boundary_required: false,
            human_review_required: true,
            reason: String::from(
                "The self-asserted identity is accepted. A separate service safety constraint requires human review.",
            ),
        });
    }

    if has_reviewable_context_bound_harm(request.conduct_evidence.as_ref()) {
        return Ok(EvaluationResult {
            decision: Decision::AcceptedWithConductBoundary,
            identity_accepted: true,
            conduct_boundary_required: true,
            human_review_required: true,
            reason: String::from(
                "The self-asserted identity remains accepted. A narrow, reviewable conduct boundary is required.",
            ),
        });
    }

    Ok(EvaluationResult {
        decision: Decision::Accepted,
        identity_accepted: true,
        conduct_boundary_required: false,
        human_review_required: false,
        reason: String::from(
            "The self-asserted identity is accepted without certification, scoring, or centralized lookup.",
        ),
    })
}

pub fn permitted_boundary_record_fields() -> BTreeSet<&'static str> {
    [
        "record_type",
        "scope",
        "reason_category",
        "created_at",
        "expires_at",
        "review_status",
        "appeal_status",
        "identity_assertion_stored",
        "cross_service_sharing",
        "automated_ranking",
    ]
    .into_iter()
    .collect()
}

fn has_reviewable_context_bound_harm(evidence: Option<&ConductEvidence>) -> bool {
    matches!(
        evidence,
        Some(ConductEvidence {
            verified: true,
            policy_relevant: true,
            context_bound: true,
            identity_based: false,
            reviewable: true,
        })
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request(
        essential: bool,
        safety_constraint_satisfied: bool,
        evidence: Option<ConductEvidence>,
    ) -> EvaluationRequest {
        EvaluationRequest {
            service: ServiceContext {
                essential,
                safety_constraint_satisfied,
            },
            identity_assertion: IdentityAssertion {
                assertion_type: IdentityAssertionType::SelfDescribedCyberneticHostStatus,
                value: String::from("cybernetic host"),
            },
            conduct_evidence: evidence,
        }
    }

    #[test]
    fn accepts_self_assertion_without_certification() {
        let result = evaluate(&request(false, true, None)).expect("request is valid");

        assert_eq!(result.decision, Decision::Accepted);
        assert!(result.identity_accepted);
        assert!(!result.conduct_boundary_required);
        assert!(!result.human_review_required);
    }

    #[test]
    fn preserves_identity_acceptance_when_conduct_needs_review() {
        let evidence = ConductEvidence {
            verified: true,
            policy_relevant: true,
            context_bound: true,
            identity_based: false,
            reviewable: true,
        };

        let result = evaluate(&request(false, true, Some(evidence))).expect("request is valid");

        assert_eq!(result.decision, Decision::AcceptedWithConductBoundary);
        assert!(result.identity_accepted);
        assert!(result.conduct_boundary_required);
        assert!(result.human_review_required);
    }

    #[test]
    fn rejects_identity_based_conduct_evidence_as_a_boundary_basis() {
        let evidence = ConductEvidence {
            verified: true,
            policy_relevant: true,
            context_bound: true,
            identity_based: true,
            reviewable: true,
        };

        let result = evaluate(&request(false, true, Some(evidence))).expect("request is valid");

        assert_eq!(result.decision, Decision::Accepted);
        assert!(result.identity_accepted);
        assert!(!result.conduct_boundary_required);
    }

    #[test]
    fn separates_identity_acceptance_from_service_safety_review() {
        let result = evaluate(&request(false, false, None)).expect("request is valid");

        assert_eq!(result.decision, Decision::ServiceSafetyReview);
        assert!(result.identity_accepted);
        assert!(result.human_review_required);
    }

    #[test]
    fn keeps_essential_services_out_of_scope() {
        let error = evaluate(&request(true, true, None)).expect_err("must reject out-of-scope use");

        assert_eq!(error, PolicyError::EssentialServiceOutOfScope);
    }

    #[test]
    fn rejects_empty_assertions() {
        let mut value = request(false, true, None);
        value.identity_assertion.value = String::from("  ");

        let error = evaluate(&value).expect_err("must reject empty assertion");

        assert_eq!(error, PolicyError::EmptyAssertion);
    }

    #[test]
    fn exposes_only_non_ranking_boundary_fields() {
        let fields = permitted_boundary_record_fields();

        assert!(fields.contains("expires_at"));
        assert!(fields.contains("appeal_status"));
        assert!(!fields.contains("reputation_score"));
        assert!(!fields.contains("identity_validity_score"));
        assert!(!fields.contains("cross_service_profile"));
    }
}
