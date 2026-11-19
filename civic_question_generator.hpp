#ifndef AUGMENTED_HUB_CIVIC_QUESTION_GENERATOR_HPP
#define AUGMENTED_HUB_CIVIC_QUESTION_GENERATOR_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::civic_questions {

enum class CivicQuestionError {
    empty_required_field,
    insufficient_aggregation,
    invalid_governance_status
};

enum class CivicQuestionCategory {
    service_time_opportunity,
    facility_underutilization,
    energy_reallocation,
    accessibility_feature_improvement,
    social_cohesion_activity,
    wait_time_variance,
    low_ridership_equity_function,
    fairness_preserving_service_adjustment,
    transit_accessibility_gap,
    fare_affordability_equality
};

enum class ExternalActionStatus {
    prohibited,
    informational_only,
    requires_separate_approval,
    approved_for_bounded_action
};

struct AggregateDataReference {
    std::string dataset_id;
    std::string time_window;
    std::string spatial_precision_class;
    std::size_t minimum_aggregation_count{};
    bool non_personal{};
    bool voluntary_when_feedback_derived{};
    bool uncertainty_disclosed{};
};

struct GatheringHubQuestionContext {
    std::string hub_id;
    AggregateDataReference occupancy_data;
    AggregateDataReference energy_data;
    AggregateDataReference facility_usage_data;
    AggregateDataReference weather_data;
    AggregateDataReference accessibility_feature_data;
    std::string governed_impact_shard_reference;
    ExternalActionStatus external_action_status{
        ExternalActionStatus::requires_separate_approval
    };
};

struct TransitQuestionContext {
    std::string service_area_id;
    AggregateDataReference route_performance_data;
    AggregateDataReference wait_time_data;
    AggregateDataReference accessibility_data;
    AggregateDataReference ridership_data;
    AggregateDataReference frequency_data;
    AggregateDataReference fare_affordability_data;
    std::string equity_policy_reference;
    std::string governed_impact_shard_reference;
    ExternalActionStatus external_action_status{
        ExternalActionStatus::requires_separate_approval
    };
};

struct GeneratedCivicQuestion {
    CivicQuestionCategory category{};
    std::string question;
    std::string required_evidence;
    std::string fairness_or_privacy_boundary;
    bool requires_human_review{};
};

struct CivicQuestionGenerationResult {
    std::vector<GeneratedCivicQuestion> questions;
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<CivicQuestionGenerationResult, CivicQuestionError>
generate_gathering_hub_questions(
    const GatheringHubQuestionContext& context);

[[nodiscard]] std::expected<CivicQuestionGenerationResult, CivicQuestionError>
generate_transit_equity_questions(
    const TransitQuestionContext& context);

}  // namespace augmented_hub::civic_questions

#endif
