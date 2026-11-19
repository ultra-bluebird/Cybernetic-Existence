use serde::{Deserialize, Serialize};

pub const HIGH_SENSITIVITY_EPSILON_MAX_MICROS: u64 = 100_000;
pub const DEFAULT_MINIMUM_AGGREGATION_THRESHOLD: u32 = 50;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DataClass {
    EnvironmentalAggregate,
    CrowdDensityAggregate,
    ThermalAggregate,
    DerivedSensitiveFeature,
    HighSensitivityBiometric,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OutputMode {
    LocalEphemeral,
    RestrictedReview,
    AggregateOnly,
    NoOutput,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConsentState {
    Valid,
    Revoked,
    Expired,
    Missing,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ConsentScope {
    pub purpose: String,
    pub data_class: DataClass,
    pub output_mode: OutputMode,
    pub valid_from_unix_ms: u64,
    pub valid_until_unix_ms: u64,
    pub state: ConsentState,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AggregateRequest {
    pub request_id: String,
    pub purpose: String,
    pub requested_at_unix_ms: u64,
    pub contributor_count: u32,
    pub minimum_contributor_count: u32,
    pub clipped_sum: i64,
    pub l1_sensitivity_units: u64,
    pub epsilon_micros: u64,
    pub cumulative_epsilon_used_micros: u64,
    pub cumulative_epsilon_limit_micros: u64,
    pub consent: ConsentScope,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReleaseDecision {
    AllowAggregateOnly,
    DenyConsentMissing,
    DenyConsentRevoked,
    DenyConsentExpired,
    DenyPurposeMismatch,
    DenyDataClassNotEligible,
    DenyOutputMode,
    DenyMinimumAggregationThreshold,
    DenyInvalidSensitivity,
    DenyHighSensitivityEpsilon,
    DenyCumulativeBudget,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReleaseAssessment {
    pub request_id: String,
    pub decision: ReleaseDecision,
    pub projected_cumulative_epsilon_micros: u64,
    pub laplace_scale_numerator: u64,
    pub laplace_scale_denominator: u64,
    pub reasons: Vec<String>,
}

fn eligible_data_class(data_class: &DataClass) -> bool {
    matches!(
        data_class,
        DataClass::EnvironmentalAggregate
            | DataClass::CrowdDensityAggregate
            | DataClass::ThermalAggregate
    )
}

pub fn assess_release(request: &AggregateRequest) -> ReleaseAssessment {
    let projected_cumulative_epsilon_micros = request
        .cumulative_epsilon_used_micros
        .saturating_add(request.epsilon_micros);

    let mut reasons = Vec::new();

    let decision = match request.consent.state {
        ConsentState::Missing => {
            reasons.push("consent_scope_is_missing".to_owned());
            ReleaseDecision::DenyConsentMissing
        }
        ConsentState::Revoked => {
            reasons.push("consent_scope_has_been_revoked".to_owned());
            ReleaseDecision::DenyConsentRevoked
        }
        ConsentState::Expired => {
            reasons.push("consent_scope_has_expired".to_owned());
            ReleaseDecision::DenyConsentExpired
        }
        ConsentState::Valid if request.requested_at_unix_ms < request.consent.valid_from_unix_ms
            || request.requested_at_unix_ms > request.consent.valid_until_unix_ms =>
        {
            reasons.push("request_is_outside_the_consent_validity_window".to_owned());
            ReleaseDecision::DenyConsentExpired
        }
        ConsentState::Valid if request.purpose != request.consent.purpose => {
            reasons.push("request_purpose_does_not_match_consent_scope".to_owned());
            ReleaseDecision::DenyPurposeMismatch
        }
        ConsentState::Valid if !eligible_data_class(&request.consent.data_class) => {
            reasons.push("sensitive_or_derived_feature_class_is_not_release_eligible".to_owned());
            ReleaseDecision::DenyDataClassNotEligible
        }
        ConsentState::Valid if request.consent.output_mode != OutputMode::AggregateOnly => {
            reasons.push("consent_scope_does_not_allow_aggregate_only_output".to_owned());
            ReleaseDecision::DenyOutputMode
        }
        ConsentState::Valid
            if request.minimum_contributor_count < DEFAULT_MINIMUM_AGGREGATION_THRESHOLD
                || request.contributor_count < request.minimum_contributor_count =>
        {
            reasons.push("minimum_aggregation_threshold_is_not_met".to_owned());
            ReleaseDecision::DenyMinimumAggregationThreshold
        }
        ConsentState::Valid if request.l1_sensitivity_units == 0 || request.epsilon_micros == 0 => {
            reasons.push("sensitivity_and_epsilon_must_be_positive".to_owned());
            ReleaseDecision::DenyInvalidSensitivity
        }
        ConsentState::Valid
            if matches!(
                request.consent.data_class,
                DataClass::HighSensitivityBiometric | DataClass::DerivedSensitiveFeature
            ) && request.epsilon_micros > HIGH_SENSITIVITY_EPSILON_MAX_MICROS =>
        {
            reasons.push("high_sensitivity_epsilon_exceeds_local_policy_limit".to_owned());
            ReleaseDecision::DenyHighSensitivityEpsilon
        }
        ConsentState::Valid
            if projected_cumulative_epsilon_micros > request.cumulative_epsilon_limit_micros =>
        {
            reasons.push("cumulative_privacy_budget_would_be_exceeded".to_owned());
            ReleaseDecision::DenyCumulativeBudget
        }
        ConsentState::Valid => ReleaseDecision::AllowAggregateOnly,
    };

    ReleaseAssessment {
        request_id: request.request_id.clone(),
        decision,
        projected_cumulative_epsilon_micros,
        laplace_scale_numerator: request.l1_sensitivity_units.saturating_mul(1_000_000),
        laplace_scale_denominator: request.epsilon_micros,
        reasons,
    }
}
