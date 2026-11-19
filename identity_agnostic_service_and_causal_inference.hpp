#ifndef AUGMENTED_HUB_IDENTITY_AGNOSTIC_SERVICE_AND_CAUSAL_INFERENCE_HPP
#define AUGMENTED_HUB_IDENTITY_AGNOSTIC_SERVICE_AND_CAUSAL_INFERENCE_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::causal_services {

enum class CausalServiceError {
    empty_input,
    invalid_numeric_input,
    prohibited_feature,
    incompatible_time_series,
    insufficient_pre_intervention_evidence,
    invalid_treatment_assignment,
    invalid_service_request
};

enum class ServiceFeatureCategory {
    request_parameters,
    operational_safety,
    service_capacity,
    infrastructure_condition,
    voluntary_accessibility_preference,
    claimed_identity,
    identity_status,
    augmentation_status,
    biometric_information,
    neural_information,
    health_information,
    disability_related_information,
    private_learning_continuity,
    optional_telemetry_absence,
    external_identity_verification_absence
};

enum class ServiceDecisionOutcome {
    equal_default_service,
    voluntary_interface_adaptation,
    identity_linked_model_rejected,
    hold_for_review
};

struct ServiceModelFeature {
    std::string feature_name;
    ServiceFeatureCategory category{};
    bool required_for_service_quality{};
    bool purpose_bound{};
};

struct ServicePrioritizationModel {
    std::string model_version;
    std::vector<ServiceModelFeature> features;
    bool counterfactual_invariance_test_passed{};
    bool aggregate_outcome_monitoring_enabled{};
    bool human_reviewed_priority_policy{};
};

struct IdentityAgnosticServiceAssessment {
    ServiceDecisionOutcome outcome{
        ServiceDecisionOutcome::hold_for_review
    };
    bool identity_agnostic{};
    bool accommodation_only{};
    bool human_review_required{};
    std::string plain_language_explanation;
};

struct TimeSeriesObservation {
    std::string unit_id;
    double time_index{};
    double outcome_value{};
    bool treated{};
    bool post_intervention{};
    double seasonal_covariate{};
    double weather_covariate{};
};

struct DifferenceInDifferencesResult {
    double treated_pre_mean{};
    double treated_post_mean{};
    double control_pre_mean{};
    double control_post_mean{};
    double difference_in_differences_estimate{};
    double seasonally_adjusted_estimate{};
    std::size_t treated_observation_count{};
    std::size_t control_observation_count{};
    bool sufficient_pre_intervention_evidence{};
    std::string plain_language_explanation;
};

[[nodiscard]]
std::expected<IdentityAgnosticServiceAssessment, CausalServiceError>
evaluate_service_prioritization_model(
    const ServicePrioritizationModel& model);

[[nodiscard]]
std::expected<DifferenceInDifferencesResult, CausalServiceError>
estimate_difference_in_differences(
    const std::vector<TimeSeriesObservation>& observations,
    std::size_t minimum_pre_intervention_observations);

}  // namespace augmented_hub::causal_services

#endif
