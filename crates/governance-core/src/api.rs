use crate::{
    decision::GovernanceDecision,
    evidence::EvidenceBundle,
    mission::MissionDescriptor,
    safety_envelope::SafetyEnvelope,
    validation::{validate_mission, ValidationReport},
};

#[derive(Clone, Debug, PartialEq)]
pub struct GovernanceEvaluationRequest {
    pub mission: MissionDescriptor,
    pub evidence_bundle: EvidenceBundle,
    pub safety_envelope: SafetyEnvelope,
}

#[derive(Clone, Debug, PartialEq)]
pub struct GovernanceEvaluationResponse {
    pub decision: GovernanceDecision,
    pub validation_report: ValidationReport,
    pub non_actuating: bool,
    pub identity_neutral: bool,
    pub limitations: Vec<String>,
}

pub trait GovernanceEvaluator {
    fn evaluate(
        &self,
        request: &GovernanceEvaluationRequest,
    ) -> GovernanceEvaluationResponse;
}

#[derive(Clone, Copy, Debug, Default)]
pub struct DefaultGovernanceEvaluator;

impl GovernanceEvaluator for DefaultGovernanceEvaluator {
    fn evaluate(
        &self,
        request: &GovernanceEvaluationRequest,
    ) -> GovernanceEvaluationResponse {
        let validation_report = validate_mission(
            &request.mission,
            &request.evidence_bundle,
            &request.safety_envelope,
        );

        GovernanceEvaluationResponse {
            decision: validation_report.decision.clone(),
            validation_report,
            non_actuating: true,
            identity_neutral: true,
            limitations: vec![
                "This result evaluates supplied local governance artifacts only.".to_owned(),
                "This result does not verify identity or augmentation status.".to_owned(),
                "This result does not establish clinical, legal, commissioning, or deployment conclusions.".to_owned(),
                "This result does not authorize physical action, firmware operations, device control, or infrastructure control.".to_owned(),
            ],
        }
    }
}

pub fn evaluate_governance(
    request: &GovernanceEvaluationRequest,
) -> GovernanceEvaluationResponse {
    DefaultGovernanceEvaluator.evaluate(request)
}
