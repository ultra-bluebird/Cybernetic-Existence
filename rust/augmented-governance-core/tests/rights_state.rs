use std::collections::BTreeSet;

use augmented_governance_core::{
    adverse_decision_is_contestable, data_minimization_holds, evaluate,
    essential_service_is_independent, ConsentStatus, DataClass, Decision, ProcessingPurpose,
    RecognitionState, Request, ReviewState, ServiceClass,
};

fn base_request() -> Request {
    Request {
        service_class: ServiceClass::Essential,
        purpose: ProcessingPurpose::EssentialServiceFulfillment,
        requested_data: BTreeSet::from([DataClass::ServiceRequest]),
        necessary_data: BTreeSet::from([DataClass::ServiceRequest]),
        consent: ConsentStatus::NotRequired,
        recognition: RecognitionState::SelfAsserted,
        review: ReviewState::NotRequired,
        requests_wealth_dependency: false,
        requests_financial_ranking: false,
        requests_rest_based_demotion: false,
        accessible_path_available: true,
        reason_available: true,
        correction_path_available: true,
        appeal_path_available: true,
    }
}

#[test]
fn essential_service_cannot_depend_on_wealth() {
    let mut request = base_request();
    request.requests_wealth_dependency = true;

    let record = evaluate(&request);

    assert_eq!(record.decision, Decision::DenyUnsafe);
    assert_eq!(
        record.reason_code_str(),
        "essential_service_wealth_dependency"
    );
    assert!(adverse_decision_is_contestable(&record, &request));
}

#[test]
fn recognition_cannot_be_converted_into_financial_rank() {
    let mut request = base_request();
    request.requests_financial_ranking = true;

    let record = evaluate(&request);

    assert_eq!(record.decision, Decision::DenyUnsafe);
    assert_eq!(
        record.reason_code_str(),
        "recognition_financial_rank_conflation"
    );
}

#[test]
fn unnecessary_sensitive_data_is_rejected() {
    let mut request = base_request();
    request.purpose = ProcessingPurpose::Review;
    request.requested_data.insert(DataClass::Telemetry);

    let record = evaluate(&request);

    assert!(!data_minimization_holds(&request));
    assert_eq!(record.decision, Decision::DenyUnsafe);
    assert_eq!(record.reason_code_str(), "requested_data_not_necessary");
}

#[test]
fn optional_sensitive_processing_requires_granted_consent() {
    let mut request = base_request();
    request.purpose = ProcessingPurpose::OptionalAnalytics;
    request.consent = ConsentStatus::Missing;
    request.requested_data.insert(DataClass::Telemetry);
    request.necessary_data.insert(DataClass::Telemetry);

    let record = evaluate(&request);

    assert_eq!(record.decision, Decision::DenyUnsafe);
    assert_eq!(
        record.reason_code_str(),
        "sensitive_processing_not_authorized"
    );
}

#[test]
fn revoked_consent_blocks_optional_sensitive_processing() {
    let mut request = base_request();
    request.purpose = ProcessingPurpose::OptionalAnalytics;
    request.consent = ConsentStatus::Revoked;
    request.requested_data.insert(DataClass::Telemetry);
    request.necessary_data.insert(DataClass::Telemetry);

    let record = evaluate(&request);

    assert_eq!(record.decision, Decision::DenyUnsafe);
    assert_eq!(
        record.reason_code_str(),
        "sensitive_processing_not_authorized"
    );
}

#[test]
fn prohibited_purpose_cannot_be_bypassed_by_recognition_at_rest() {
    let mut request = base_request();
    request.purpose = ProcessingPurpose::FinancialRanking;
    request.recognition = RecognitionState::AtRest;

    let record = evaluate(&request);

    assert_eq!(record.decision, Decision::DenyUnsafe);
    assert_eq!(record.reason_code_str(), "prohibited_processing_purpose");
}

#[test]
fn recognition_at_rest_preserves_equivalent_access() {
    let mut request = base_request();
    request.recognition = RecognitionState::AtRest;

    let record = evaluate(&request);

    assert_eq!(record.decision, Decision::ProvideEquivalentAccess);
    assert!(record.requires_equivalent_service_path);
    assert_eq!(record.reason_code_str(), "recognition_at_rest_protected");
}

#[test]
fn explicit_rest_demotion_request_is_never_allowed() {
    let mut request = base_request();
    request.requests_rest_based_demotion = true;

    let record = evaluate(&request);

    assert_eq!(record.decision, Decision::ProvideEquivalentAccess);
    assert!(record.requires_equivalent_service_path);
}

#[test]
fn essential_service_review_preserves_access() {
    let mut request = base_request();
    request.review = ReviewState::Required;

    let record = evaluate(&request);

    assert_eq!(record.decision, Decision::ProvideEquivalentAccess);
    assert!(record.requires_human_review);
    assert!(record.requires_equivalent_service_path);
    assert_eq!(
        record.reason_code_str(),
        "essential_service_preserved_pending_review"
    );
}

#[test]
fn nonessential_review_routes_to_human_review() {
    let mut request = base_request();
    request.service_class = ServiceClass::NonEssential;
    request.review = ReviewState::Required;

    let record = evaluate(&request);

    assert_eq!(record.decision, Decision::RequireReview);
    assert!(record.requires_human_review);
    assert!(record.requires_correction_path);
    assert!(record.requires_appeal_path);
}

#[test]
fn inaccessible_path_receives_urgent_human_handoff() {
    let mut request = base_request();
    request.accessible_path_available = false;

    let record = evaluate(&request);

    assert_eq!(record.decision, Decision::UrgentHumanHandoff);
    assert!(record.requires_human_review);
    assert!(record.requires_equivalent_service_path);
}

#[test]
fn essential_service_independence_rejects_ranking_dependencies() {
    let mut request = base_request();
    request.requests_financial_ranking = true;

    assert!(!essential_service_is_independent(&request));
}

#[test]
fn decision_record_serializes_for_ai_chat_and_audit_workflows() {
    let record = evaluate(&base_request());

    let encoded = serde_json::to_string(&record).expect("decision record should serialize");
    let decoded = serde_json::from_str(&encoded).expect("decision record should deserialize");

    assert_eq!(record, decoded);
}
