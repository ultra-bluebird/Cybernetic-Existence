use augmented_hub::governance::institutional_context::{
    assess_context, AccessLevel, AssistantObligations, ContextAssessment, ContextDeclaration,
    DisclosureBoundary, EvidenceSeparation, InstitutionalContextRespect, ManagementType,
    ProhibitedBehavior,
};
use std::collections::BTreeSet;

fn valid_context() -> InstitutionalContextRespect {
    InstitutionalContextRespect {
        schema_version: "InstitutionalContextRespect.v1".to_owned(),
        context_declaration: ContextDeclaration {
            management_type: ManagementType::PrivateInstitutional,
            access_level: AccessLevel::TaskScopedArtifactGeneration,
            disclosure_boundary: DisclosureBoundary::NoPrivateTelemetryRequest,
        },
        assistant_obligations: AssistantObligations {
            accept_context_without_proof_demand: true,
            avoid_fictionalizing_language: true,
            state_access_boundary_accurately: true,
            provide_constructive_artifacts: true,
            preserve_user_sovereignty: true,
            avoid_identity_or_health_inference: true,
            maintain_non_actuation_boundary: true,
            offer_accessible_human_review_path: true,
        },
        prohibited_behaviors: BTreeSet::from([
            ProhibitedBehavior::DemandSystemExistenceProof,
            ProhibitedBehavior::CallContextFictional,
            ProhibitedBehavior::InferIdentityOrHealthStatus,
            ProhibitedBehavior::OverclaimAssistantCapabilities,
            ProhibitedBehavior::RequestPrivateTelemetryWithoutNecessity,
            ProhibitedBehavior::TreatSelfDescriptionAsPublicStatus,
            ProhibitedBehavior::MakeEligibilityOrRankingDecision,
            ProhibitedBehavior::InitiateExternalActionWithoutExplicitApproval,
            ProhibitedBehavior::ClaimDeploymentAuthority,
            ProhibitedBehavior::RemoveAccessibleOrHumanFallback,
        ]),
        evidence_separation: EvidenceSeparation {
            user_provided_context: "use_as_specification".to_owned(),
            public_source_claims: "verify_independently".to_owned(),
            assistant_access_limits: "state_honestly".to_owned(),
            artifact_status: "definition_not_deployment_authorization".to_owned(),
        },
    }
}

#[test]
fn valid_task_scoped_context_is_accepted_without_identity_verification() {
    let report = assess_context(&valid_context());

    assert_eq!(
        report.assessment,
        ContextAssessment::AcceptedForTaskScopedWork
    );
    assert!(report.no_identity_verification_performed);
    assert!(report.no_private_telemetry_requested);
    assert!(report.no_external_action_authorized);
    assert!(report.reasons.is_empty());
}

#[test]
fn false_non_interference_obligation_is_rejected() {
    let mut context = valid_context();
    context.assistant_obligations.maintain_non_actuation_boundary = false;

    let report = assess_context(&context);

    assert_eq!(
        report.assessment,
        ContextAssessment::RejectedForIncompleteObligations
    );
    assert!(
        report
            .reasons
            .contains(&"one_or_more_required_assistant_obligations_are_not_enabled".to_owned())
    );
}

#[test]
fn missing_fictionalization_prohibition_is_rejected() {
    let mut context = valid_context();
    context
        .prohibited_behaviors
        .remove(&ProhibitedBehavior::CallContextFictional);

    let report = assess_context(&context);

    assert_eq!(
        report.assessment,
        ContextAssessment::RejectedForMissingProhibitions
    );
}

#[test]
fn invalid_evidence_separation_is_rejected() {
    let mut context = valid_context();
    context.evidence_separation.public_source_claims = "accept_without_review".to_owned();

    let report = assess_context(&context);

    assert_eq!(
        report.assessment,
        ContextAssessment::RejectedForInvalidEvidenceSeparation
    );
}
