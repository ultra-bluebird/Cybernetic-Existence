use std::collections::BTreeSet;

use cyberrank_core::{
    evaluate, Decision, ProhibitedDataClass, ProhibitedPractice, ServiceClass, ServiceRequest,
    UncertaintyLevel,
};

fn rights_preserving_request() -> ServiceRequest {
    ServiceRequest {
        service_class: ServiceClass::GeneralService,
        digital_path_available: true,
        non_digital_path_available: true,
        human_fallback_available: true,
        outcome_equivalence_verified: true,
        correction_path_available: true,
        appeal_path_available: true,
        accessible_status_available: true,
        account_required: false,
        account_necessary: false,
        uncertainty_level: UncertaintyLevel::HighConfidence,
        critical_automated_decision_requested: false,
        requested_data_classes: BTreeSet::new(),
        requested_practices: BTreeSet::new(),
    }
}

#[test]
fn denies_private_neural_data_request() {
    let mut request = rights_preserving_request();
    request
        .requested_data_classes
        .insert(ProhibitedDataClass::NeuralInformation);

    let result = evaluate(&request);

    assert_eq!(result.decision, Decision::Deny);
    assert!(
        result
            .obligations
            .contains("provide_neutral_access_pathway")
    );
}

#[test]
fn denies_status_scoring_attempt() {
    let mut request = rights_preserving_request();
    request
        .requested_practices
        .insert(ProhibitedPractice::PerformStatusScoring);

    let result = evaluate(&request);

    assert_eq!(result.decision, Decision::Deny);
    assert!(
        result
            .obligations
            .contains("stop_prohibited_practice")
    );
}

#[test]
fn holds_unreliable_critical_automation() {
    let mut request = rights_preserving_request();
    request.critical_automated_decision_requested = true;
    request.uncertainty_level = UncertaintyLevel::Unreliable;

    let result = evaluate(&request);

    assert_eq!(result.decision, Decision::Hold);
    assert!(
        result
            .obligations
            .contains("block_automated_critical_decision")
    );
    assert!(result.obligations.contains("activate_human_fallback"));
}

#[test]
fn suspends_essential_service_without_any_continuity_path() {
    let mut request = rights_preserving_request();
    request.service_class = ServiceClass::EmergencyCommunications;
    request.digital_path_available = false;
    request.non_digital_path_available = false;
    request.human_fallback_available = false;

    let result = evaluate(&request);

    assert_eq!(result.decision, Decision::Suspend);
    assert!(result.obligations.contains("open_continuity_incident"));
}

#[test]
fn holds_essential_pathway_when_appeal_is_missing() {
    let mut request = rights_preserving_request();
    request.service_class = ServiceClass::HealthSupport;
    request.appeal_path_available = false;

    let result = evaluate(&request);

    assert_eq!(result.decision, Decision::Hold);
    assert!(result.obligations.contains("provide_appeal_path"));
}

#[test]
fn holds_unnecessary_account_requirement() {
    let mut request = rights_preserving_request();
    request.account_required = true;
    request.account_necessary = false;

    let result = evaluate(&request);

    assert_eq!(result.decision, Decision::Hold);
    assert!(
        result
            .obligations
            .contains("provide_account_free_pathway")
    );
}
