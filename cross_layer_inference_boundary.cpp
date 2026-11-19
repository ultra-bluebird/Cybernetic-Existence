#include "cross_layer_inference_boundary.hpp"

#include <cmath>

namespace augmented_hub::cross_layer {
namespace {

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

bool valid_evidence_reference(const EvidenceReference& reference) {
    return !reference.artifact_id.empty() &&
        !reference.provenance_hash.empty() &&
        !reference.policy_version.empty() &&
        !reference.schema_version.empty();
}

}  // namespace

std::expected<BoundedInferenceDecision, InferenceBoundaryError>
evaluate_ai_inference_boundary(
    const AIInferenceResult& inference,
    const VerifiedControlContext& context,
    double maximum_uncertainty,
    double minimum_score) {

    if (inference.inference_id.empty() ||
        inference.model_version.empty() ||
        context.active_policy_version.empty() ||
        inference.input_evidence.empty()) {
        return std::unexpected(
            InferenceBoundaryError::empty_required_field);
    }

    if (!finite_unit_interval(inference.score) ||
        !finite_unit_interval(inference.uncertainty) ||
        !finite_unit_interval(maximum_uncertainty) ||
        !finite_unit_interval(minimum_score) ||
        !std::isfinite(inference.generated_at_seconds) ||
        !std::isfinite(inference.valid_until_seconds) ||
        !std::isfinite(context.current_time_seconds) ||
        inference.valid_until_seconds < inference.generated_at_seconds) {
        return std::unexpected(
            InferenceBoundaryError::invalid_numeric_input);
    }

    for (const auto& evidence : inference.input_evidence) {
        if (!valid_evidence_reference(evidence)) {
            return std::unexpected(
                InferenceBoundaryError::empty_required_field);
        }

        if (evidence.policy_version != context.active_policy_version) {
            return std::unexpected(
                InferenceBoundaryError::policy_version_mismatch);
        }
    }

    if (inference.personal_data_processed ||
        !inference.raw_data_retained_locally) {
        return BoundedInferenceDecision{
            .status = SafetyEnvelopeStatus::rejected_outside_envelope,
            .recommendation_usable_for_analysis = false,
            .autonomous_actuation_permitted = false,
            .human_review_required = true,
            .plain_language_explanation =
                "The inference is outside the permitted evidence boundary because it either processed personal data or did not preserve its source evidence locally. The recommendation is rejected from the operational path."
        };
    }

    if (context.current_time_seconds > inference.valid_until_seconds) {
        return BoundedInferenceDecision{
            .status = SafetyEnvelopeStatus::fallback_required,
            .recommendation_usable_for_analysis = false,
            .autonomous_actuation_permitted = false,
            .human_review_required = true,
            .plain_language_explanation =
                "The inference is stale. The verified controller must use its independent fallback behavior and preserve the stale result only as audit evidence."
        };
    }

    if (inference.uncertainty > maximum_uncertainty ||
        inference.score < minimum_score) {
        return BoundedInferenceDecision{
            .status = SafetyEnvelopeStatus::hold_for_review,
            .recommendation_usable_for_analysis = true,
            .autonomous_actuation_permitted = false,
            .human_review_required = true,
            .plain_language_explanation =
                "The inference remains available as analysis evidence, but its score or uncertainty does not satisfy the configured operational envelope. It is held for review and cannot authorize action."
        };
    }

    if (!context.independent_safety_sensors_healthy ||
        !context.watchdog_healthy ||
        !context.verified_controller_available) {
        return std::unexpected(
            InferenceBoundaryError::missing_verified_controller);
    }

    return BoundedInferenceDecision{
        .status = SafetyEnvelopeStatus::accepted_for_review,
        .recommendation_usable_for_analysis = true,
        .autonomous_actuation_permitted = false,
        .human_review_required = true,
        .plain_language_explanation =
            "The AI output satisfies freshness, provenance, policy-version, score, uncertainty, and local-data-retention boundaries. It is accepted as evidence for accountable review; it does not directly authorize physical actuation or an external service change."
    };
}

}  // namespace augmented_hub::cross_layer
