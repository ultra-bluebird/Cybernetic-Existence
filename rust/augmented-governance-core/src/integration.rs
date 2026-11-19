use serde::{Deserialize, Serialize};

use crate::rights::{ConsentStatus, Decision, DecisionRecord};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct IntegrationDepth {
    pub value: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct IntegrationBounds {
    pub maximum_delta: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum IntegrationDecision {
    Authorized,
    RejectedConsent,
    RejectedDepthDecrease,
    RejectedDeltaExceedsBound,
    RejectedCorridorVerdict,
    RequiresAccessibleHumanSupport,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct IntegrationRequest {
    pub current_depth: IntegrationDepth,
    pub proposed_depth: IntegrationDepth,
    pub bounds: IntegrationBounds,
    pub consent: ConsentStatus,
    pub corridor_verdict_valid: bool,
    pub accessible_path_available: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct IntegrationDecisionRecord {
    pub decision: IntegrationDecision,
    pub delta: Option<u64>,
    pub requires_human_support: bool,
    pub preserves_existing_depth: bool,
}

pub fn evaluate_integration_update(
    request: &IntegrationRequest,
) -> IntegrationDecisionRecord {
    if !request.accessible_path_available {
        return IntegrationDecisionRecord {
            decision: IntegrationDecision::RequiresAccessibleHumanSupport,
            delta: None,
            requires_human_support: true,
            preserves_existing_depth: true,
        };
    }

    if request.consent != ConsentStatus::Granted {
        return IntegrationDecisionRecord {
            decision: IntegrationDecision::RejectedConsent,
            delta: None,
            requires_human_support: false,
            preserves_existing_depth: true,
        };
    }

    if !request.corridor_verdict_valid {
        return IntegrationDecisionRecord {
            decision: IntegrationDecision::RejectedCorridorVerdict,
            delta: None,
            requires_human_support: false,
            preserves_existing_depth: true,
        };
    }

    if request.proposed_depth.value < request.current_depth.value {
        return IntegrationDecisionRecord {
            decision: IntegrationDecision::RejectedDepthDecrease,
            delta: None,
            requires_human_support: false,
            preserves_existing_depth: true,
        };
    }

    let delta = request.proposed_depth.value - request.current_depth.value;

    if delta > request.bounds.maximum_delta {
        return IntegrationDecisionRecord {
            decision: IntegrationDecision::RejectedDeltaExceedsBound,
            delta: Some(delta),
            requires_human_support: false,
            preserves_existing_depth: true,
        };
    }

    IntegrationDecisionRecord {
        decision: IntegrationDecision::Authorized,
        delta: Some(delta),
        requires_human_support: false,
        preserves_existing_depth: false,
    }
}

pub fn integration_outcome_preserves_rights(
    integration: &IntegrationDecisionRecord,
    rights: &DecisionRecord,
) -> bool {
    match integration.decision {
        IntegrationDecision::Authorized => true,
        IntegrationDecision::RejectedConsent
        | IntegrationDecision::RejectedDepthDecrease
        | IntegrationDecision::RejectedDeltaExceedsBound
        | IntegrationDecision::RejectedCorridorVerdict
        | IntegrationDecision::RequiresAccessibleHumanSupport => {
            !matches!(rights.decision, Decision::DenyUnsafe)
                || rights.requires_accessible_notice
                || rights.requires_correction_path
                || rights.requires_appeal_path
        }
    }
}
