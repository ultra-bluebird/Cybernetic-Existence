#include "identity_agnostic_service_and_causal_inference.hpp"

#include <cmath>
#include <unordered_set>

namespace augmented_hub::causal_services {
namespace {

bool finite_value(double value) noexcept {
    return std::isfinite(value);
}

bool is_prohibited_feature_category(
    ServiceFeatureCategory category) noexcept {

    switch (category) {
        case ServiceFeatureCategory::claimed_identity:
        case ServiceFeatureCategory::identity_status:
        case ServiceFeatureCategory::augmentation_status:
        case ServiceFeatureCategory::biometric_information:
        case ServiceFeatureCategory::neural_information:
        case ServiceFeatureCategory::health_information:
        case ServiceFeatureCategory::disability_related_information:
        case ServiceFeatureCategory::private_learning_continuity:
        case ServiceFeatureCategory::optional_telemetry_absence:
        case ServiceFeatureCategory::external_identity_verification_absence:
            return true;
        default:
            return false;
    }
}

struct OutcomeAccumulator {
    double sum{};
    double seasonal_sum{};
    double weather_sum{};
    std::size_t count{};

    void add(const TimeSeriesObservation& observation) {
        sum += observation.outcome_value;
        seasonal_sum += observation.seasonal_covariate;
        weather_sum += observation.weather_covariate;
        ++count;
    }

    [[nodiscard]] double mean() const noexcept {
        return count > 0U
            ? sum / static_cast<double>(count)
            : 0.0;
    }

    [[nodiscard]] double seasonal_mean() const noexcept {
        return count > 0U
            ? seasonal_sum / static_cast<double>(count)
            : 0.0;
    }

    [[nodiscard]] double weather_mean() const noexcept {
        return count > 0U
            ? weather_sum / static_cast<double>(count)
            : 0.0;
    }
};

}  // namespace

std::expected<
    IdentityAgnosticServiceAssessment,
    CausalServiceError>
evaluate_service_prioritization_model(
    const ServicePrioritizationModel& model) {

    if (model.model_version.empty() || model.features.empty()) {
        return std::unexpected(CausalServiceError::empty_input);
    }

    std::unordered_set<std::string> feature_names;
    bool has_voluntary_accessibility_preference = false;

    for (const auto& feature : model.features) {
        if (feature.feature_name.empty() ||
            !feature_names.insert(feature.feature_name).second ||
            !feature.purpose_bound) {
            return std::unexpected(
                CausalServiceError::invalid_service_request);
        }

        if (is_prohibited_feature_category(feature.category)) {
            return IdentityAgnosticServiceAssessment{
                .outcome =
                    ServiceDecisionOutcome::identity_linked_model_rejected,
                .identity_agnostic = false,
                .accommodation_only = false,
                .human_review_required = true,
                .plain_language_explanation =
                    "The service-prioritization model is rejected because its feature schema includes identity-linked or sensitive information. Service priority must be based on request, operational safety, infrastructure condition, and service-capacity evidence only."
            };
        }

        if (feature.category ==
            ServiceFeatureCategory::voluntary_accessibility_preference) {
            has_voluntary_accessibility_preference = true;

            if (feature.required_for_service_quality) {
                return IdentityAgnosticServiceAssessment{
                    .outcome =
                        ServiceDecisionOutcome::identity_linked_model_rejected,
                    .identity_agnostic = false,
                    .accommodation_only = false,
                    .human_review_required = true,
                    .plain_language_explanation =
                        "The model is rejected because a voluntary accessibility preference is required for service-quality or priority determination. Preferences may adapt interaction only and cannot become a service-eligibility or prioritization feature."
                };
            }
        }
    }

    if (!model.counterfactual_invariance_test_passed ||
        !model.aggregate_outcome_monitoring_enabled ||
        !model.human_reviewed_priority_policy) {
        return IdentityAgnosticServiceAssessment{
            .outcome = ServiceDecisionOutcome::hold_for_review,
            .identity_agnostic = false,
            .accommodation_only = false,
            .human_review_required = true,
            .plain_language_explanation =
                "The feature schema does not contain prohibited identity-linked inputs, but the model remains held for review until counterfactual invariance testing, aggregate outcome monitoring, and human review of the priority policy are complete."
        };
    }

    return IdentityAgnosticServiceAssessment{
        .outcome = has_voluntary_accessibility_preference
            ? ServiceDecisionOutcome::voluntary_interface_adaptation
            : ServiceDecisionOutcome::equal_default_service,
        .identity_agnostic = true,
        .accommodation_only = has_voluntary_accessibility_preference,
        .human_review_required = false,
        .plain_language_explanation =
            has_voluntary_accessibility_preference
                ? "The model is identity-agnostic. A voluntary accessibility preference may be used only to adapt the interaction experience and does not affect service priority, eligibility, credibility, or rights of access."
                : "The model is identity-agnostic because its feature schema excludes identity-linked inputs and its governance checks require counterfactual invariance testing, aggregate outcome monitoring, and reviewed priority rules."
    };
}

std::expected<DifferenceInDifferencesResult, CausalServiceError>
estimate_difference_in_differences(
    const std::vector<TimeSeriesObservation>& observations,
    std::size_t minimum_pre_intervention_observations) {

    if (observations.empty() ||
        minimum_pre_intervention_observations == 0U) {
        return std::unexpected(CausalServiceError::empty_input);
    }

    OutcomeAccumulator treated_pre;
    OutcomeAccumulator treated_post;
    OutcomeAccumulator control_pre;
    OutcomeAccumulator control_post;

    std::unordered_set<std::string> unit_identifiers;

    for (const auto& observation : observations) {
        if (observation.unit_id.empty() ||
            !unit_identifiers.insert(
                observation.unit_id + ":" +
                std::to_string(observation.time_index)).second ||
            !finite_value(observation.time_index) ||
            !finite_value(observation.outcome_value) ||
            !finite_value(observation.seasonal_covariate) ||
            !finite_value(observation.weather_covariate)) {
            return std::unexpected(
                CausalServiceError::invalid_numeric_input);
        }

        if (observation.treated && !observation.post_intervention) {
            treated_pre.add(observation);
        } else if (observation.treated && observation.post_intervention) {
            treated_post.add(observation);
        } else if (!observation.treated && !observation.post_intervention) {
            control_pre.add(observation);
        } else {
            control_post.add(observation);
        }
    }

    if (treated_pre.count < minimum_pre_intervention_observations ||
        control_pre.count < minimum_pre_intervention_observations ||
        treated_post.count == 0U ||
        control_post.count == 0U) {
        return std::unexpected(
            CausalServiceError::insufficient_pre_intervention_evidence);
    }

    const double treated_change =
        treated_post.mean() - treated_pre.mean();

    const double control_change =
        control_post.mean() - control_pre.mean();

    const double difference_in_differences =
        treated_change - control_change;

    const double treated_seasonal_change =
        treated_post.seasonal_mean() - treated_pre.seasonal_mean();

    const double control_seasonal_change =
        control_post.seasonal_mean() - control_pre.seasonal_mean();

    const double treated_weather_change =
        treated_post.weather_mean() - treated_pre.weather_mean();

    const double control_weather_change =
        control_post.weather_mean() - control_pre.weather_mean();

    const double seasonal_and_weather_difference =
        (treated_seasonal_change - control_seasonal_change) +
        (treated_weather_change - control_weather_change);

    const double adjusted_estimate =
        difference_in_differences -
        seasonal_and_weather_difference;

    return DifferenceInDifferencesResult{
        .treated_pre_mean = treated_pre.mean(),
        .treated_post_mean = treated_post.mean(),
        .control_pre_mean = control_pre.mean(),
        .control_post_mean = control_post.mean(),
        .difference_in_differences_estimate =
            difference_in_differences,
        .seasonally_adjusted_estimate = adjusted_estimate,
        .treated_observation_count =
            treated_pre.count + treated_post.count,
        .control_observation_count =
            control_pre.count + control_post.count,
        .sufficient_pre_intervention_evidence = true,
        .plain_language_explanation =
            "This result estimates the change associated with an infrastructure intervention by comparing treated and comparison units before and after implementation. It includes a simple seasonal and weather covariate adjustment, but the causal interpretation depends on stated assumptions, pre-intervention trend diagnostics, comparison quality, placebo tests, and uncertainty analysis."
    };
}

}  // namespace augmented_hub::causal_services
