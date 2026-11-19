#include "social_acceptance_metrics.hpp"

#include <algorithm>
#include <cmath>

namespace augmented_hub::social_acceptance {
namespace {

constexpr double kMinimumPublicationCount = 20.0;

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

bool valid_vector(const AcceptanceVector& vector) noexcept {
    return finite_unit_interval(vector.legal) &&
        finite_unit_interval(vector.social) &&
        finite_unit_interval(vector.infrastructural) &&
        finite_unit_interval(vector.psychological) &&
        finite_unit_interval(vector.economic);
}

AcceptanceVector apply_change(
    const AcceptanceVector& previous,
    const AcceptanceChange& changes,
    const AcceptanceWeights& weights) noexcept {

    return AcceptanceVector{
        .legal = std::clamp(
            previous.legal +
            weights.policy_weights.legal * changes.policy_change.legal +
            weights.social_weights.legal *
                changes.social_feedback_change.legal +
            weights.infrastructure_weights.legal *
                changes.infrastructure_change.legal,
            0.0,
            1.0),
        .social = std::clamp(
            previous.social +
            weights.policy_weights.social * changes.policy_change.social +
            weights.social_weights.social *
                changes.social_feedback_change.social +
            weights.infrastructure_weights.social *
                changes.infrastructure_change.social,
            0.0,
            1.0),
        .infrastructural = std::clamp(
            previous.infrastructural +
            weights.policy_weights.infrastructural *
                changes.policy_change.infrastructural +
            weights.social_weights.infrastructural *
                changes.social_feedback_change.infrastructural +
            weights.infrastructure_weights.infrastructural *
                changes.infrastructure_change.infrastructural,
            0.0,
            1.0),
        .psychological = std::clamp(
            previous.psychological +
            weights.policy_weights.psychological *
                changes.policy_change.psychological +
            weights.social_weights.psychological *
                changes.social_feedback_change.psychological +
            weights.infrastructure_weights.psychological *
                changes.infrastructure_change.psychological,
            0.0,
            1.0),
        .economic = std::clamp(
            previous.economic +
            weights.policy_weights.economic *
                changes.policy_change.economic +
            weights.social_weights.economic *
                changes.social_feedback_change.economic +
            weights.infrastructure_weights.economic *
                changes.infrastructure_change.economic,
            0.0,
            1.0)
    };
}

double weighted_sum(
    const AcceptanceVector& values,
    const AcceptanceVector& weights) noexcept {

    return
        values.legal * weights.legal +
        values.social * weights.social +
        values.infrastructural * weights.infrastructural +
        values.psychological * weights.psychological +
        values.economic * weights.economic;
}

double minimum_dimension(const AcceptanceVector& values) noexcept {
    return std::min(
        {values.legal,
         values.social,
         values.infrastructural,
         values.psychological,
         values.economic});
}

}  // namespace

std::expected<AcceptanceAssessment, AcceptanceError>
evaluate_acceptance_conditions(
    const AcceptanceVector& previous,
    const AcceptanceChange& changes,
    const AcceptanceWeights& weights,
    const AggregateEvidence& evidence) {

    if (!valid_vector(previous) ||
        !valid_vector(changes.policy_change) ||
        !valid_vector(changes.social_feedback_change) ||
        !valid_vector(changes.infrastructure_change) ||
        !valid_vector(weights.policy_weights) ||
        !valid_vector(weights.social_weights) ||
        !valid_vector(weights.infrastructure_weights) ||
        !valid_vector(weights.composite_weights)) {
        return std::unexpected(AcceptanceError::invalid_numeric_input);
    }

    if (evidence.participant_count < kMinimumPublicationCount ||
        !evidence.voluntary ||
        !evidence.non_identifying) {
        return std::unexpected(AcceptanceError::insufficient_aggregation);
    }

    const AcceptanceVector updated =
        apply_change(previous, changes, weights);

    const double composite =
        weighted_sum(updated, weights.composite_weights);

    const double tolerance_floor = minimum_dimension(updated);

    const double positive_acceptance =
        std::clamp(
            0.40 * updated.legal +
            0.25 * updated.social +
            0.20 * updated.infrastructural +
            0.10 * updated.psychological +
            0.05 * updated.economic,
            0.0,
            1.0);

    return AcceptanceAssessment{
        .updated_vector = updated,
        .composite_acceptance_score = composite,
        .tolerance_floor_score = tolerance_floor,
        .positive_acceptance_score = positive_acceptance,
        .publication_eligible = evidence.publication_approved,
        .plain_language_explanation =
            "This assessment reports aggregate conditions of access, participation, infrastructure, and remedy. It distinguishes a tolerance floor from positive acceptance conditions and does not evaluate, rank, certify, or infer any individual identity."
    };
}

}  // namespace augmented_hub::social_acceptance
