use augmented_hub::privacy::dp_aggregate::{
    assess_release, AggregateRequest, ConsentScope, ConsentState, DataClass, OutputMode,
    ReleaseDecision, DEFAULT_MINIMUM_AGGREGATION_THRESHOLD,
};

fn valid_request() -> AggregateRequest {
    AggregateRequest {
        request_id: "aggregate-release-test-001".to_owned(),
        purpose: "heat-safe-corridor-planning".to_owned(),
        requested_at_unix_ms: 1_800_000_000_000,
        contributor_count: DEFAULT_MINIMUM_AGGREGATION_THRESHOLD,
        minimum_contributor_count: DEFAULT_MINIMUM_AGGREGATION_THRESHOLD,
        clipped_sum: 87,
        l1_sensitivity_units: 1,
        epsilon_micros: 100_000,
        cumulative_epsilon_used_micros: 100_000,
        cumulative_epsilon_limit_micros: 500_000,
        consent: ConsentScope {
            purpose: "heat-safe-corridor-planning".to_owned(),
            data_class: DataClass::ThermalAggregate,
            output_mode: OutputMode::AggregateOnly,
            valid_from_unix_ms: 1_700_000_000_000,
            valid_until_unix_ms: 1_900_000_000_000,
            state: ConsentState::Valid,
        },
    }
}

#[test]
fn valid_aggregate_request_is_allowed() {
    let assessment = assess_release(&valid_request());

    assert_eq!(assessment.decision, ReleaseDecision::AllowAggregateOnly);
    assert_eq!(assessment.laplace_scale_numerator, 1_000_000);
    assert_eq!(assessment.laplace_scale_denominator, 100_000);
}

#[test]
fn fewer_than_fifty_contributors_is_denied() {
    let mut request = valid_request();
    request.contributor_count = 49;

    let assessment = assess_release(&request);

    assert_eq!(
        assessment.decision,
        ReleaseDecision::DenyMinimumAggregationThreshold
    );
}

#[test]
fn revoked_consent_stops_new_processing() {
    let mut request = valid_request();
    request.consent.state = ConsentState::Revoked;

    let assessment = assess_release(&request);

    assert_eq!(assessment.decision, ReleaseDecision::DenyConsentRevoked);
}

#[test]
fn purpose_mismatch_is_denied() {
    let mut request = valid_request();
    request.purpose = "unrelated-analysis".to_owned();

    let assessment = assess_release(&request);

    assert_eq!(assessment.decision, ReleaseDecision::DenyPurposeMismatch);
}

#[test]
fn derived_sensitive_features_are_not_aggregate_release_eligible() {
    let mut request = valid_request();
    request.consent.data_class = DataClass::DerivedSensitiveFeature;

    let assessment = assess_release(&request);

    assert_eq!(
        assessment.decision,
        ReleaseDecision::DenyDataClassNotEligible
    );
}

#[test]
fn exhausted_privacy_budget_is_denied() {
    let mut request = valid_request();
    request.cumulative_epsilon_used_micros = 450_000;
    request.epsilon_micros = 100_000;
    request.cumulative_epsilon_limit_micros = 500_000;

    let assessment = assess_release(&request);

    assert_eq!(assessment.decision, ReleaseDecision::DenyCumulativeBudget);
}
