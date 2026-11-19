#include "civic_question_generator.hpp"

namespace augmented_hub::civic_questions {
namespace {

constexpr std::size_t kMinimumAggregationCount = 20U;

bool valid_reference(const AggregateDataReference& reference) {
    return !reference.dataset_id.empty() &&
        !reference.time_window.empty() &&
        !reference.spatial_precision_class.empty() &&
        reference.minimum_aggregation_count >= kMinimumAggregationCount &&
        reference.non_personal &&
        reference.voluntary_when_feedback_derived &&
        reference.uncertainty_disclosed;
}

bool valid_action_status(ExternalActionStatus status) {
    switch (status) {
        case ExternalActionStatus::prohibited:
        case ExternalActionStatus::informational_only:
        case ExternalActionStatus::requires_separate_approval:
        case ExternalActionStatus::approved_for_bounded_action:
            return true;
    }

    return false;
}

}  // namespace

std::expected<CivicQuestionGenerationResult, CivicQuestionError>
generate_gathering_hub_questions(
    const GatheringHubQuestionContext& context) {

    if (context.hub_id.empty() ||
        context.governed_impact_shard_reference.empty()) {
        return std::unexpected(CivicQuestionError::empty_required_field);
    }

    if (!valid_reference(context.occupancy_data) ||
        !valid_reference(context.energy_data) ||
        !valid_reference(context.facility_usage_data) ||
        !valid_reference(context.weather_data) ||
        !valid_reference(context.accessibility_feature_data)) {
        return std::unexpected(CivicQuestionError::insufficient_aggregation);
    }

    if (!valid_action_status(context.external_action_status)) {
        return std::unexpected(CivicQuestionError::invalid_governance_status);
    }

    return CivicQuestionGenerationResult{
        .questions = {
            GeneratedCivicQuestion{
                .category = CivicQuestionCategory::service_time_opportunity,
                .question =
                    "For gathering hub " + context.hub_id +
                    ", which aggregate time windows show the greatest combined opportunity for additional services when hourly occupancy, facility availability, weather conditions, energy capacity, and accessibility-function availability are evaluated together?",
                .required_evidence =
                    "Use aggregate occupancy dataset " +
                    context.occupancy_data.dataset_id +
                    ", facility-usage dataset " +
                    context.facility_usage_data.dataset_id +
                    ", weather dataset " +
                    context.weather_data.dataset_id +
                    ", and the governed impact shard " +
                    context.governed_impact_shard_reference + ".",
                .fairness_or_privacy_boundary =
                    "Use aggregate, non-personal patterns only. Do not identify, track, profile, or infer characteristics of individual visitors.",
                .requires_human_review = true
            },
            GeneratedCivicQuestion{
                .category = CivicQuestionCategory::facility_underutilization,
                .question =
                    "Which facility types at gathering hub " + context.hub_id +
                    " are underutilized by time window after accounting for weather, maintenance availability, accessible-route availability, and scheduled community activities? What low-risk, community-governed uses could improve public benefit?",
                .required_evidence =
                    "Use aggregate facility-usage data " +
                    context.facility_usage_data.dataset_id +
                    ", accessibility-feature data " +
                    context.accessibility_feature_data.dataset_id +
                    ", maintenance records, and approved activity schedules.",
                .fairness_or_privacy_boundary =
                    "Do not treat low use as evidence that a service is unnecessary when it provides an essential accessibility, cooling, safety, or civic-participation function.",
                .requires_human_review = true
            },
            GeneratedCivicQuestion{
                .category = CivicQuestionCategory::energy_reallocation,
                .question =
                    "How can the hub's energy profile be reallocated between peak and off-peak periods while preserving critical loads for assistance panels, accessible features, safety systems, water, communications, and essential cooling or shade functions?",
                .required_evidence =
                    "Use energy dataset " +
                    context.energy_data.dataset_id +
                    ", renewable-generation forecasts, storage state, critical-load policy, and equipment maintenance status.",
                .fairness_or_privacy_boundary =
                    "Energy optimization must not disable essential accessibility or safety functions, and it must not depend on visitor identity, device use, or individual behavior tracking.",
                .requires_human_review = true
            },
            GeneratedCivicQuestion{
                .category =
                    CivicQuestionCategory::accessibility_feature_improvement,
                .question =
                    "Which accessibility features at gathering hub " +
                    context.hub_id +
                    " show aggregate signals of limited availability, maintenance interruption, or interaction friction across time windows? What infrastructure, interface, wayfinding, or service-continuity improvement should be evaluated first?",
                .required_evidence =
                    "Use aggregate accessibility-function availability from " +
                    context.accessibility_feature_data.dataset_id +
                    ", non-identifying barrier reports, maintenance outcomes, and accessible grievance-resolution statistics.",
                .fairness_or_privacy_boundary =
                    "Do not infer a diagnosis, augmentation status, disability status, or identity from use or non-use of an accessibility feature. Non-use does not reduce the requirement to maintain equivalent access.",
                .requires_human_review = true
            },
            GeneratedCivicQuestion{
                .category =
                    CivicQuestionCategory::social_cohesion_activity,
                .question =
                    "Which voluntary, accessible, community-governed activities are associated with stronger aggregate participation, reciprocal contribution, civic connection, and use of shared public space at gathering hub " +
                    context.hub_id +
                    "? What outcome indicators and uncertainty bounds should be used before expanding an activity?",
                .required_evidence =
                    "Use aggregate participation data, voluntary non-identifying feedback, accessible event records, environmental conditions, and the methodology version attached to the impact shard.",
                .fairness_or_privacy_boundary =
                    "Do not predict personal affiliation, beliefs, or social relationships. Treat findings as program-level evidence for community review, not as a ranking of people or groups.",
                .requires_human_review = true
            }
        },
        .plain_language_explanation =
            "These questions help improve public gathering-hub services using aggregate occupancy, energy, facility, weather, and accessibility evidence. They preserve essential access, prohibit individual tracking, and require separate approval for external service changes."
    };
}

std::expected<CivicQuestionGenerationResult, CivicQuestionError>
generate_transit_equity_questions(
    const TransitQuestionContext& context) {

    if (context.service_area_id.empty() ||
        context.equity_policy_reference.empty() ||
        context.governed_impact_shard_reference.empty()) {
        return std::unexpected(CivicQuestionError::empty_required_field);
    }

    if (!valid_reference(context.route_performance_data) ||
        !valid_reference(context.wait_time_data) ||
        !valid_reference(context.accessibility_data) ||
        !valid_reference(context.ridership_data) ||
        !valid_reference(context.frequency_data) ||
        !valid_reference(context.fare_affordability_data)) {
        return std::unexpected(CivicQuestionError::insufficient_aggregation);
    }

    if (!valid_action_status(context.external_action_status)) {
        return std::unexpected(CivicQuestionError::invalid_governance_status);
    }

    return CivicQuestionGenerationResult{
        .questions = {
            GeneratedCivicQuestion{
                .category = CivicQuestionCategory::wait_time_variance,
                .question =
                    "Across service area " + context.service_area_id +
                    ", which routes, stops, and time windows have the highest aggregate wait-time variance after accounting for planned frequency, on-time performance, transfer timing, weather disruption, and service alerts?",
                .required_evidence =
                    "Use route-performance data " +
                    context.route_performance_data.dataset_id +
                    ", wait-time data " +
                    context.wait_time_data.dataset_id +
                    ", frequency data " +
                    context.frequency_data.dataset_id +
                    ", and stated uncertainty for each route/time window.",
                .fairness_or_privacy_boundary =
                    "Evaluate neighborhood-level service outcomes, not passenger identity, augmentation status, disability status, or individual travel history.",
                .requires_human_review = false
            },
            GeneratedCivicQuestion{
                .category =
                    CivicQuestionCategory::low_ridership_equity_function,
                .question =
                    "Which low-ridership routes or stops in service area " +
                    context.service_area_id +
                    " perform critical equity functions such as accessible connection to essential services, heat-relief hubs, civic facilities, employment, education, health access, or emergency alternatives? What evidence demonstrates that service value exceeds ridership volume alone?",
                .required_evidence =
                    "Use aggregate ridership data " +
                    context.ridership_data.dataset_id +
                    ", stop-accessibility dataset " +
                    context.accessibility_data.dataset_id +
                    ", public destination inventory, service-area coverage analysis, and equity policy " +
                    context.equity_policy_reference + ".",
                .fairness_or_privacy_boundary =
                    "Low ridership is not sufficient evidence for service reduction. Preserve accessible and essential-service connections without requiring riders to disclose identity, diagnosis, augmentation, or assistive-technology use.",
                .requires_human_review = true
            },
            GeneratedCivicQuestion{
                .category =
                    CivicQuestionCategory::fairness_preserving_service_adjustment,
                .question =
                    "Which service-frequency, transfer, vehicle-allocation, stop-improvement, or schedule-adjustment scenarios improve wait-time equality and accessible coverage across neighborhoods while maintaining or increasing total service usefulness and preserving critical low-ridership equity functions?",
                .required_evidence =
                    "Use route performance, wait time, ridership, accessibility, frequency, operating-cost, and network-coverage scenarios referenced by impact shard " +
                    context.governed_impact_shard_reference + ".",
                .fairness_or_privacy_boundary =
                    "Do not optimize only for aggregate ridership. Apply the transit fairness metric, service-access floors, accessible-route continuity, and community review requirements.",
                .requires_human_review = true
            },
            GeneratedCivicQuestion{
                .category = CivicQuestionCategory::transit_accessibility_gap,
                .question =
                    "Which stops or transfer paths show an accessibility gap based on aggregate infrastructure conditions, accessible boarding availability, wayfinding, real-time information access, shade or thermal exposure, pedestrian-route continuity, and repair history? Which gap has the highest combined safety and access impact?",
                .required_evidence =
                    "Use accessibility dataset " +
                    context.accessibility_data.dataset_id +
                    ", maintenance records, stop-condition surveys, aggregated thermal exposure measures, and approved public-infrastructure data.",
                .fairness_or_privacy_boundary =
                    "Assess the accessibility of the environment and service, not the identity or medical information of riders. Maintain alternate accessible routes during any repair.",
                .requires_human_review = true
            },
            GeneratedCivicQuestion{
                .category =
                    CivicQuestionCategory::fare_affordability_equality,
                .question =
                    "Do fare structures, transfer rules, payment methods, and discount-access pathways produce unequal fare-to-income burdens across neighborhoods in service area " +
                    context.service_area_id +
                    "? Which policy alternatives reduce the burden disparity without creating new documentation, connectivity, proprietary-device, or identity-verification barriers?",
                .required_evidence =
                    "Use aggregate fare-affordability data " +
                    context.fare_affordability_data.dataset_id +
                    ", published fare policy, neighborhood-scale income indicators, transfer behavior aggregates, and equity policy " +
                    context.equity_policy_reference + ".",
                .fairness_or_privacy_boundary =
                    "Do not require individual financial, identity, health, augmentation, or accessibility disclosure to analyze affordability or to access essential transit services.",
                .requires_human_review = true
            }
        },
        .plain_language_explanation =
            "These questions produce fairness-aware transit analysis from aggregate service outcomes. They protect low-ridership but essential routes, require accessible-service continuity, and prohibit identity-linked service allocation."
    };
}

}  // namespace augmented_hub::civic_questions
