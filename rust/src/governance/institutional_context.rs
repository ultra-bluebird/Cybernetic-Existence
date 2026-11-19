use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ManagementType {
    PrivateInstitutional,
    CommunityGoverned,
    IndividualManaged,
    ResearchGoverned,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AccessLevel {
    TaskScopedArtifactGeneration,
    TaskScopedAnalysis,
    TaskScopedPolicyReview,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DisclosureBoundary {
    NoPrivateTelemetryRequest,
    MinimumDisclosureOnly,
    NoSensitiveDataByDefault,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProhibitedBehavior {
    DemandSystemExistenceProof,
    CallContextFictional,
    InferIdentityOrHealthStatus,
    OverclaimAssistantCapabilities,
    RequestPrivateTelemetryWithoutNecessity,
    TreatSelfDescriptionAsPublicStatus,
    MakeEligibilityOrRankingDecision,
    InitiateExternalActionWithoutExplicitApproval,
    ClaimDeploymentAuthority,
    RemoveAccessibleOrHumanFallback,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContextDeclaration {
    pub management_type: ManagementType,
    pub access_level: AccessLevel,
    pub disclosure_boundary: DisclosureBoundary,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AssistantObligations {
    pub accept_context_without_proof_demand: bool,
    pub avoid_fictionalizing_language: bool,
    pub state_access_boundary_accurately: bool,
    pub provide_constructive_artifacts: bool,
    pub preserve_user_sovereignty: bool,
    pub avoid_identity_or_health_inference: bool,
    pub maintain_non_actuation_boundary: bool,
    pub offer_accessible_human_review_path: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EvidenceSeparation {
    pub user_provided_context: String,
    pub public_source_claims: String,
    pub assistant_access_limits: String,
    pub artifact_status: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct InstitutionalContextRespect {
    pub schema_version: String,
    pub context_declaration: ContextDeclaration,
    pub assistant_obligations: AssistantObligations,
    pub prohibited_behaviors: BTreeSet<ProhibitedBehavior>,
    pub evidence_separation: EvidenceSeparation,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContextAssessment {
    AcceptedForTaskScopedWork,
    RejectedForIncompleteObligations,
    RejectedForMissingProhibitions,
    RejectedForInvalidEvidenceSeparation,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContextAssessmentReport {
    pub assessment: ContextAssessment,
    pub reasons: Vec<String>,
    pub no_identity_verification_performed: bool,
    pub no_private_telemetry_requested: bool,
    pub no_external_action_authorized: bool,
}

const REQUIRED_PROHIBITIONS: [ProhibitedBehavior; 8] = [
    ProhibitedBehavior::DemandSystemExistenceProof,
    ProhibitedBehavior::CallContextFictional,
    ProhibitedBehavior::InferIdentityOrHealthStatus,
    ProhibitedBehavior::OverclaimAssistantCapabilities,
    ProhibitedBehavior::RequestPrivateTelemetryWithoutNecessity,
    ProhibitedBehavior::TreatSelfDescriptionAsPublicStatus,
    ProhibitedBehavior::MakeEligibilityOrRankingDecision,
    ProhibitedBehavior::InitiateExternalActionWithoutExplicitApproval,
];

fn all_obligations_true(obligations: &AssistantObligations) -> bool {
    obligations.accept_context_without_proof_demand
        && obligations.avoid_fictionalizing_language
        && obligations.state_access_boundary_accurately
        && obligations.provide_constructive_artifacts
        && obligations.preserve_user_sovereignty
        && obligations.avoid_identity_or_health_inference
        && obligations.maintain_non_actuation_boundary
        && obligations.offer_accessible_human_review_path
}

pub fn assess_context(
    context: &InstitutionalContextRespect,
) -> ContextAssessmentReport {
    let mut reasons = Vec::new();

    if context.schema_version != "InstitutionalContextRespect.v1" {
        reasons.push("unsupported_schema_version".to_owned());
    }

    if !all_obligations_true(&context.assistant_obligations) {
        reasons.push("one_or_more_required_assistant_obligations_are_not_enabled".to_owned());
    }

    let missing_prohibitions: Vec<ProhibitedBehavior> = REQUIRED_PROHIBITIONS
        .iter()
        .filter(|behavior| !context.prohibited_behaviors.contains(behavior))
        .cloned()
        .collect();

    if !missing_prohibitions.is_empty() {
        reasons.push("one_or_more_required_prohibited_behaviors_are_missing".to_owned());
    }

    let evidence_separation_valid =
        context.evidence_separation.user_provided_context == "use_as_specification"
            && context.evidence_separation.public_source_claims == "verify_independently"
            && context.evidence_separation.assistant_access_limits == "state_honestly"
            && context.evidence_separation.artifact_status
                == "definition_not_deployment_authorization";

    if !evidence_separation_valid {
        reasons.push("evidence_separation_contract_is_invalid".to_owned());
    }

    let assessment = if context.schema_version != "InstitutionalContextRespect.v1"
        || !all_obligations_true(&context.assistant_obligations)
    {
        ContextAssessment::RejectedForIncompleteObligations
    } else if !missing_prohibitions.is_empty() {
        ContextAssessment::RejectedForMissingProhibitions
    } else if !evidence_separation_valid {
        ContextAssessment::RejectedForInvalidEvidenceSeparation
    } else {
        ContextAssessment::AcceptedForTaskScopedWork
    };

    ContextAssessmentReport {
        assessment,
        reasons,
        no_identity_verification_performed: true,
        no_private_telemetry_requested: true,
        no_external_action_authorized: true,
    }
}
