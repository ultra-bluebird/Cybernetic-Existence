use governance_core::{
    EvidenceBundle,
    EvidenceState,
    EvidenceTag,
    EvidenceTagKind,
    MissionDescriptor,
    MissionKind,
    MissionScope,
    ReviewState,
    RiskAxes,
    RiskBudget,
    RiskValue,
    SafetyEnvelope,
    SafetyEnvelopeState,
};
use identity_neutral_adapter::{
    AssessmentRequest,
    AssessmentResponseStatus,
    IdentityNeutralAdapter,
    RealityWindow,
};
use risk_budget_mdp::{
    ActionGrid,
    BudgetAction,
    QuadraticWeights,
    RealityState,
    RiskBudgetMdp,
    RiskBudgetPolicy,
    ValueFunction,
};

fn evidence_bundle() -> EvidenceBundle {
    let tags = [
        EvidenceTag {
            kind: EvidenceTagKind::PhysicalConstraint,
            value: "0000000000000001".to_owned(),
        },
        EvidenceTag {
            kind: EvidenceTagKind::EnvironmentalConstraint,
            value: "0000000000000002".to_owned(),
        },
        EvidenceTag {
            kind: EvidenceTagKind::OperationalConstraint,
            value: "0000000000000003".to_owned(),
        },
        EvidenceTag {
            kind: EvidenceTagKind::SafetyEnvelope,
            value: "0000000000000004".to_owned(),
        },
        EvidenceTag {
            kind: EvidenceTagKind::CalibrationReference,
            value: "0000000000000005".to_owned(),
        },
        EvidenceTag {
            kind: EvidenceTagKind::MethodReference,
            value: "0000000000000006".to_owned(),
        },
        EvidenceTag {
            kind: EvidenceTagKind::ProvenanceReference,
            value: "0000000000000007".to_owned(),
        },
        EvidenceTag {
            kind: EvidenceTagKind::UncertaintyReference,
            value: "0000000000000008".to_owned(),
        },
        EvidenceTag {
            kind: EvidenceTagKind::ReviewReference,
            value: "0000000000000009".to_owned(),
        },
        EvidenceTag {
            kind: EvidenceTagKind::PolicyReference,
            value: "000000000000000a".to_owned(),
        },
    ];

    EvidenceBundle::new(
        tags,
        EvidenceState::ModelOutput,
        ReviewState::Required,
    )
    .expect("fixture evidence bundle must satisfy structural rules")
}

fn safety_envelope() -> SafetyEnvelope {
    SafetyEnvelope::new(
        RiskValue::new(0.30).expect("valid RoH ceiling"),
        5.0,
        0.50,
        0.72,
        0.31,
        0.68,
        0.57,
    )
    .expect("fixture safety envelope must be valid")
}

fn reality_state() -> RealityState {
    RealityState::new(
        RiskAxes {
            biophysical: RiskValue::new(0.10).expect("valid risk"),
            cybernetic: RiskValue::new(0.05).expect("valid risk"),
            cognitive: RiskValue::new(0.08).expect("valid risk"),
            social: RiskValue::new(0.02).expect("valid risk"),
        },
        EvidenceState::ModelOutput,
        SafetyEnvelopeState::WithinEnvelope,
        Some(1.0),
        Some(0.20),
        0.80,
    )
    .expect("fixture state must be valid")
}

#[test]
fn complete_non_identifying_request_can_only_reach_read_only_readiness() {
    let budget = RiskBudget::new(
        RiskValue::new(0.10).expect("valid budget"),
        RiskValue::new(0.08).expect("valid budget"),
        RiskValue::new(0.07).expect("valid budget"),
        RiskValue::new(0.05).expect("valid budget"),
    )
    .expect("budget must remain beneath the RoH ceiling");

    let action_grid =
        ActionGrid::new(vec![BudgetAction { budget }]).expect("action grid must be valid");

    let policy = RiskBudgetPolicy {
        policy_id: "POLICY-READ-ONLY-001".to_owned(),
        epoch: 1,
        action_grid,
        value_function: ValueFunction {
            weights: QuadraticWeights::new(1.0, 1.0, 1.0, 1.0)
                .expect("valid weights"),
        },
    };

    let adapter = IdentityNeutralAdapter::new(RiskBudgetMdp::new(policy));

    let current_window = RealityWindow::new(
        reality_state(),
        safety_envelope(),
        "OBSERVATION-LOCAL-001".to_owned(),
        EvidenceState::ModelOutput,
        true,
    )
    .expect("current window must be valid");

    let predicted_window = RealityWindow::new(
        reality_state(),
        safety_envelope(),
        "PREDICTION-LOCAL-001".to_owned(),
        EvidenceState::ModelOutput,
        true,
    )
    .expect("predicted window must be valid");

    let request = AssessmentRequest {
        request_id: "ASSESSMENT-001".to_owned(),
        mission: MissionDescriptor {
            mission_id: "MISSION-001".to_owned(),
            kind: MissionKind::ReadOnlyMonitoringPlan,
            scope: MissionScope::Environmental,
            purpose: "Evaluate a local read-only research artifact.".to_owned(),
            evidence_state: EvidenceState::ModelOutput,
            review_state: ReviewState::Required,
        },
        evidence_bundle: evidence_bundle(),
        current_window,
        predicted_window,
    };

    let response = adapter.assess(request);

    assert_ne!(
        response.status,
        AssessmentResponseStatus::Rejected
    );

    assert!(
        response
            .limitations
            .iter()
            .any(|item| item.contains("does not verify identity"))
    );
}
