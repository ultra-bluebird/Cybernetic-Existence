use augmented_governance_core::{
    evaluate_integration_update, ConsentStatus, IntegrationBounds, IntegrationDecision,
    IntegrationDepth, IntegrationRequest,
};

fn request_template() -> IntegrationRequest {
    IntegrationRequest {
        current_depth: IntegrationDepth { value: 4 },
        proposed_depth: IntegrationDepth { value: 5 },
        bounds: IntegrationBounds { maximum_delta: 2 },
        consent: ConsentStatus::Granted,
        corridor_verdict_valid: true,
        accessible_path_available: true,
    }
}

#[test]
fn authorized_update_has_nonnegative_bounded_delta() {
    let record = evaluate_integration_update(&request_template());

    assert_eq!(record.decision, IntegrationDecision::Authorized);
    assert_eq!(record.delta, Some(1));
    assert!(!record.preserves_existing_depth);
}

#[test]
fn revoked_consent_preserves_existing_depth() {
    let mut request = request_template();
    request.consent = ConsentStatus::Revoked;

    let record = evaluate_integration_update(&request);

    assert_eq!(record.decision, IntegrationDecision::RejectedConsent);
    assert!(record.preserves_existing_depth);
}

#[test]
fn depth_decrease_is_rejected() {
    let mut request = request_template();
    request.proposed_depth = IntegrationDepth { value: 3 };

    let record = evaluate_integration_update(&request);

    assert_eq!(record.decision, IntegrationDecision::RejectedDepthDecrease);
    assert!(record.preserves_existing_depth);
}

#[test]
fn excessive_delta_is_rejected() {
    let mut request = request_template();
    request.proposed_depth = IntegrationDepth { value: 7 };

    let record = evaluate_integration_update(&request);

    assert_eq!(
        record.decision,
        IntegrationDecision::RejectedDeltaExceedsBound
    );
    assert_eq!(record.delta, Some(3));
    assert!(record.preserves_existing_depth);
}

#[test]
fn inaccessible_update_path_routes_to_human_support() {
    let mut request = request_template();
    request.accessible_path_available = false;

    let record = evaluate_integration_update(&request);

    assert_eq!(
        record.decision,
        IntegrationDecision::RequiresAccessibleHumanSupport
    );
    assert!(record.requires_human_support);
    assert!(record.preserves_existing_depth);
}
