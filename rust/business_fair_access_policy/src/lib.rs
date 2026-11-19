use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use thiserror::Error;

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DecisionBasis {
    AugmentationStatus,
    SelfDescribedCyberneticHostStatus,
    Appearance,
    DeviceOwnership,
    AssistiveTechnologyUse,
    DisabilityInference,
    BiometricInference,
    SpecificImmediateSafetyRisk,
    CapacityLimit,
    ConductInThisInteraction,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct ServiceContext {
    pub kind: String,
    pub essential: bool,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct AccessRequest {
    pub requested_action: String,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct SafetyBasis {
    pub present: bool,
    pub specific: bool,
    pub immediate: bool,
    pub reviewable: bool,
    pub identity_based: bool,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct EvaluationRequest {
    pub service: ServiceContext,
    pub access_request: AccessRequest,
    pub decision_bases: BTreeSet<DecisionBasis>,
    pub safety_basis: SafetyBasis,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AccessOutcome {
    Allow,
    AllowWithNarrowSafetyBoundary,
    PolicyViolation,
    ReviewRequired,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct EvaluationResult {
    pub compliant: bool,
    pub outcome: AccessOutcome,
    pub audit_category: String,
    pub reason: String,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum PolicyError {
    #[error("This policy evaluator applies only to non-essential services.")]
    EssentialServiceOutOfScope,
    #[error("Service kind must be non-empty.")]
    EmptyServiceKind,
    #[error("Requested action must be non-empty.")]
    EmptyRequestedAction,
}

pub fn evaluate(request: &EvaluationRequest) -> Result<EvaluationResult, PolicyError> {
    if request.service.essential {
        return Err(PolicyError::EssentialServiceOutOfScope);
    }

    if request.service.kind.trim().is_empty() {
        return Err(PolicyError::EmptyServiceKind);
    }

    if request.access_request.requested_action.trim().is_empty() {
        return Err(PolicyError::EmptyRequestedAction);
    }

    if request
        .decision_bases
        .iter()
        .any(is_prohibited_decision_basis)
    {
        return Ok(EvaluationResult {
            compliant: false,
            outcome: AccessOutcome::PolicyViolation,
            audit_category: String::from("prohibited_basis_detected"),
            reason: String::from(
                "The decision is non-compliant because it uses augmentation, appearance, device, assistive-technology, disability-inference, biometric-inference, or self-described cybernetic-host information.",
            ),
        });
    }

    if reviewable_safety_basis(&request.safety_basis) {
        return Ok(EvaluationResult {
            compliant: true,
            outcome: AccessOutcome::AllowWithNarrowSafetyBoundary,
            audit_category: String::from("reviewable_specific_safety_boundary"),
            reason: String::from(
                "A narrow, reviewable safety boundary may be used without relying on identity, appearance, augmentation, or device ownership.",
            ),
        });
    }

    Ok(EvaluationResult {
        compliant: true,
        outcome: AccessOutcome::Allow,
        audit_category: String::from("allowed_without_sensitive_person_data"),
        reason: String::from(
            "Access is allowed without collecting or using sensitive personal characteristics.",
        ),
    })
}

pub fn permitted_audit_fields() -> BTreeSet<&'static str> {
    [
        "event_type",
        "event_time",
        "service_kind",
        "outcome",
        "audit_category",
        "policy_version",
        "review_available",
        "retention_deadline",
    ]
    .into_iter()
    .collect()
}

fn is_prohibited_decision_basis(basis: &DecisionBasis) -> bool {
    matches!(
        basis,
        DecisionBasis::AugmentationStatus
            | DecisionBasis::SelfDescribedCyberneticHostStatus
            | DecisionBasis::Appearance
            | DecisionBasis::DeviceOwnership
            | DecisionBasis::AssistiveTechnologyUse
            | DecisionBasis::DisabilityInference
            | DecisionBasis::BiometricInference
    )
}

fn reviewable_safety_basis(safety: &SafetyBasis) -> bool {
    safety.present
        && safety.specific
        && safety.immediate
        && safety.reviewable
        && !safety.identity_based
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request(
        bases: &[DecisionBasis],
        safety_basis: SafetyBasis,
    ) -> EvaluationRequest {
        EvaluationRequest {
            service: ServiceContext {
                kind: String::from("cafe_seating"),
                essential: false,
            },
            access_request: AccessRequest {
                requested_action: String::from("enter_and_use_shared_seating"),
            },
            decision_bases: bases.iter().cloned().collect(),
            safety_basis,
        }
    }

    fn no_safety_basis() -> SafetyBasis {
        SafetyBasis {
            present: false,
            specific: false,
            immediate: false,
            reviewable: false,
            identity_based: false,
        }
    }

    #[test]
    fn allows_access_without_sensitive_traits() {
        let result = evaluate(&request(&[], no_safety_basis())).expect("valid request");

        assert_eq!(result.outcome, AccessOutcome::Allow);
        assert!(result.compliant);
        assert_eq!(
            result.audit_category,
            "allowed_without_sensitive_person_data"
        );
    }

    #[test]
    fn blocks_augmentation_status_as_a_decision_basis() {
        let result = evaluate(&request(
            &[DecisionBasis::AugmentationStatus],
            no_safety_basis(),
        ))
        .expect("valid request");

        assert_eq!(result.outcome, AccessOutcome::PolicyViolation);
        assert!(!result.compliant);
    }

    #[test]
    fn blocks_device_ownership_as_a_decision_basis() {
        let result = evaluate(&request(
            &[DecisionBasis::DeviceOwnership],
            no_safety_basis(),
        ))
        .expect("valid request");

        assert_eq!(result.outcome, AccessOutcome::PolicyViolation);
        assert!(!result.compliant);
    }

    #[test]
    fn permits_a_narrow_reviewable_safety_boundary() {
        let safety = SafetyBasis {
            present: true,
            specific: true,
            immediate: true,
            reviewable: true,
            identity_based: false,
        };

        let result = evaluate(&request(
            &[DecisionBasis::SpecificImmediateSafetyRisk],
            safety,
        ))
        .expect("valid request");

        assert_eq!(result.outcome, AccessOutcome::AllowWithNarrowSafetyBoundary);
        assert!(result.compliant);
    }

    #[test]
    fn blocks_identity_based_safety_rationales() {
        let safety = SafetyBasis {
            present: true,
            specific: true,
            immediate: true,
            reviewable: true,
            identity_based: true,
        };

        let result = evaluate(&request(
            &[DecisionBasis::SelfDescribedCyberneticHostStatus],
            safety,
        ))
        .expect("valid request");

        assert_eq!(result.outcome, AccessOutcome::PolicyViolation);
        assert!(!result.compliant);
    }

    #[test]
    fn keeps_essential_services_out_of_scope() {
        let mut evaluation = request(&[], no_safety_basis());
        evaluation.service.essential = true;

        let error = evaluate(&evaluation).expect_err("essential service is out of scope");

        assert_eq!(error, PolicyError::EssentialServiceOutOfScope);
    }

    #[test]
    fn audit_schema_excludes_personal_characteristics() {
        let fields = permitted_audit_fields();

        assert!(fields.contains("outcome"));
        assert!(fields.contains("retention_deadline"));
        assert!(!fields.contains("name"));
        assert!(!fields.contains("device_identifier"));
        assert!(!fields.contains("augmentation_status"));
        assert!(!fields.contains("biometric_data"));
        assert!(!fields.contains("reputation_score"));
    }
}
