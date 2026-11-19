#ifndef AUGMENTED_HUB_CROSS_LAYER_INFERENCE_BOUNDARY_HPP
#define AUGMENTED_HUB_CROSS_LAYER_INFERENCE_BOUNDARY_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::cross_layer {

enum class InferenceBoundaryError {
    empty_required_field,
    invalid_numeric_input,
    stale_inference,
    policy_version_mismatch,
    unsafe_recommendation,
    insufficient_uncertainty_evidence,
    missing_verified_controller
};

enum class AIRecommendationKind {
    anomaly_candidate,
    drift_candidate,
    maintenance_review_candidate,
    energy_optimization_candidate,
    planning_scenario_candidate
};

enum class SafetyEnvelopeStatus {
    accepted_for_review,
    rejected_outside_envelope,
    hold_for_review,
    fallback_required
};

struct EvidenceReference {
    std::string artifact_id;
    std::string provenance_hash;
    std::string policy_version;
    std::string schema_version;
};

struct AIInferenceResult {
    std::string inference_id;
    AIRecommendationKind kind{};
    double score{};
    double uncertainty{};
    double generated_at_seconds{};
    double valid_until_seconds{};
    std::string model_version;
    std::vector<EvidenceReference> input_evidence;
    bool raw_data_retained_locally{true};
    bool personal_data_processed{false};
};

struct VerifiedControlContext {
    double current_time_seconds{};
    std::string active_policy_version;
    bool independent_safety_sensors_healthy{};
    bool watchdog_healthy{};
    bool verified_controller_available{};
    bool external_action_preapproved{false};
};

struct BoundedInferenceDecision {
    SafetyEnvelopeStatus status{SafetyEnvelopeStatus::hold_for_review};
    bool recommendation_usable_for_analysis{};
    bool autonomous_actuation_permitted{};
    bool human_review_required{};
    std::string plain_language_explanation;
};

[[nodiscard]]
std::expected<BoundedInferenceDecision, InferenceBoundaryError>
evaluate_ai_inference_boundary(
    const AIInferenceResult& inference,
    const VerifiedControlContext& context,
    double maximum_uncertainty,
    double minimum_score);

}  // namespace augmented_hub::cross_layer

#endif
