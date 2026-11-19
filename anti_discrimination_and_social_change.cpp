#include "anti_discrimination_and_social_change.hpp"

#include <algorithm>
#include <cmath>

namespace augmented_hub::social_governance {
namespace {

constexpr std::size_t kMinimumAggregationCount = 20U;

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

bool valid_vector(const SocialChangeVector& vector) noexcept {
    return finite_unit_interval(vector.dignity) &&
        finite_unit_interval(vector.autonomy) &&
        finite_unit_interval(vector.participation) &&
        finite_unit_interval(vector.contribution) &&
        finite_unit_interval(vector.belonging);
}

bool is_prohibited_identity_input(
    DecisionInputCategory category) noexcept {

    switch (category) {
        case DecisionInputCategory::identity_status:
        case DecisionInputCategory::claimed_identity:
        case DecisionInputCategory::augmentation_status:
        case DecisionInputCategory::biometric_information:
        case DecisionInputCategory::neural_information:
        case DecisionInputCategory::health_information:
        case DecisionInputCategory::disability_related_information:
        case DecisionInputCategory::private_learning_continuity:
        case DecisionInputCategory::optional_telemetry_absence:
        case DecisionInputCategory::external_identity_verification_absence:
            return true;
        default:
            return false;
    }
}

bool is_accommodation_output(
    DecisionOutputCategory category) noexcept {
    return category == DecisionOutputCategory::interface_adaptation;
}

double composite_change(
    const SocialChangeVector& delta) noexcept {

    return
        0.25 * delta.dignity +
        0.25 * delta.autonomy +
        0.20 * delta.participation +
        0.15 * delta.contribution +
        0.15 * delta.belonging;
}

double minimum_dimension_change(
    const SocialChangeVector& delta) noexcept {

    return std::min(
        {delta.dignity,
         delta.autonomy,
         delta.participation,
         delta.contribution,
         delta.belonging});
}

}  // namespace

std::expected<DecisionPolicyAssessment, GovernanceError>
assess_decision_inputs(
    const DecisionRequest& request) {

    if (request.decision_id.empty() ||
        request.stated_purpose.empty() ||
        request.inputs.empty()) {
        return std::unexpected(GovernanceError::empty_input);
    }

    for (const auto& input : request.inputs) {
        if (is_prohibited_identity_input(input.category)) {
            return DecisionPolicyAssessment{
                .permitted = false,
                .accommodation_only = false,
                .policy_receipt_reason =
                    "prohibited_identity_linked_input",
                .plain_language_explanation =
                    "This request is denied because identity, augmentation, biometric, health, disability-related, private continuity, optional-telemetry, or external-verification information may not determine a civic, ecological, service, credibility, eligibility, or participation outcome."
            };
        }

        if (input.category ==
                DecisionInputCategory::accessibility_preference &&
            (!input.user_voluntary || !input.purpose_bound)) {
            return DecisionPolicyAssessment{
                .permitted = false,
                .accommodation_only = false,
                .policy_receipt_reason =
                    "accessibility_preference_requires_voluntary_purpose_bound_use",
                .plain_language_explanation =
                    "Accessibility preferences are accepted only when voluntary and purpose-bound to adapting the interaction experience."
            };
        }
    }

    const bool accommodation_only =
        is_accommodation_output(request.output_category);

    for (const auto& input : request.inputs) {
        if (input.category ==
                DecisionInputCategory::accessibility_preference &&
            !accommodation_only) {
            return DecisionPolicyAssessment{
                .permitted = false,
                .accommodation_only = false,
                .policy_receipt_reason =
                    "accessibility_preference_cannot_change_service_outcome",
                .plain_language_explanation =
                    "Accessibility preferences may adapt presentation, interaction, authentication alternatives, pacing, or export format. They do not alter eligibility, ecological scoring, service priority, credibility, civic participation, or appeal access."
            };
        }
    }

    return DecisionPolicyAssessment{
        .permitted = true,
        .accommodation_only = accommodation_only,
        .policy_receipt_reason = "permitted_non_identity_linked_decision",
        .plain_language_explanation =
            accommodation_only
                ? "The request is permitted as a voluntary, purpose-bound interface adaptation. It does not change eligibility, priority, evidence weight, credibility, or civic access."
                : "The request is permitted because its inputs are limited to non-identity-linked environmental, operational, or service-capacity evidence."
    };
}

std::expected<SocialChangeAssessment, GovernanceError>
assess_social_change(
    const SocialChangeVector& baseline,
    const SocialChangeVector& current,
    const SocialChangeEvidence& evidence) {

    if (!valid_vector(baseline) || !valid_vector(current)) {
        return std::unexpected(GovernanceError::invalid_numeric_input);
    }

    if (evidence.aggregate_count < kMinimumAggregationCount ||
        !evidence.voluntary_feedback ||
        !evidence.non_identifying ||
        !evidence.methodology_versioned ||
        !evidence.uncertainty_disclosed ||
        !evidence.accessible_review_path_available) {
        return std::unexpected(GovernanceError::insufficient_aggregation);
    }

    const SocialChangeVector delta{
        .dignity = current.dignity - baseline.dignity,
        .autonomy = current.autonomy - baseline.autonomy,
        .participation = current.participation - baseline.participation,
        .contribution = current.contribution - baseline.contribution,
        .belonging = current.belonging - baseline.belonging
    };

    const double minimum_delta = minimum_dimension_change(delta);
    const bool all_dimensions_improved = minimum_delta > 0.0;

    return SocialChangeAssessment{
        .baseline = baseline,
        .current = current,
        .delta = delta,
        .minimum_dimension_change = minimum_delta,
        .composite_change = composite_change(delta),
        .all_dimensions_improved = all_dimensions_improved,
        .publication_eligible = true,
        .plain_language_explanation =
            all_dimensions_improved
                ? "Aggregate evidence indicates improvement across dignity, autonomy, participation, contribution, and belonging during the stated measurement window. This supports program learning and accountable planning; it is not an assessment of any individual person."
                : "Aggregate evidence shows mixed change across the measured dimensions. The result identifies where accessible service design, participation pathways, or grievance processes can be strengthened without assigning a score or status to any individual."
    };
}

}  // namespace augmented_hub::social_governance
