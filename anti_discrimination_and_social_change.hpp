#ifndef AUGMENTED_HUB_ANTI_DISCRIMINATION_AND_SOCIAL_CHANGE_HPP
#define AUGMENTED_HUB_ANTI_DISCRIMINATION_AND_SOCIAL_CHANGE_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::social_governance {

enum class GovernanceError {
    empty_input,
    invalid_numeric_input,
    insufficient_aggregation,
    prohibited_decision_input,
    incompatible_measurement_window
};

enum class DecisionInputCategory {
    environmental_evidence,
    operational_safety,
    service_capacity,
    accessibility_preference,
    identity_status,
    claimed_identity,
    augmentation_status,
    biometric_information,
    neural_information,
    health_information,
    disability_related_information,
    private_learning_continuity,
    optional_telemetry_absence,
    external_identity_verification_absence
};

enum class DecisionOutputCategory {
    interface_adaptation,
    service_eligibility,
    service_priority,
    ecological_score,
    credibility_score,
    civic_participation_access,
    appeal_access,
    maintenance_assignment,
    planning_recommendation
};

struct DecisionInputDescriptor {
    DecisionInputCategory category{};
    bool user_voluntary{};
    bool purpose_bound{};
};

struct DecisionRequest {
    std::string decision_id;
    DecisionOutputCategory output_category{};
    std::vector<DecisionInputDescriptor> inputs;
    std::string stated_purpose;
};

struct DecisionPolicyAssessment {
    bool permitted{};
    bool accommodation_only{};
    std::string policy_receipt_reason;
    std::string plain_language_explanation;
};

struct SocialChangeVector {
    double dignity{};
    double autonomy{};
    double participation{};
    double contribution{};
    double belonging{};
};

struct SocialChangeEvidence {
    std::size_t aggregate_count{};
    bool voluntary_feedback{};
    bool non_identifying{};
    bool methodology_versioned{};
    bool uncertainty_disclosed{};
    bool accessible_review_path_available{};
};

struct SocialChangeAssessment {
    SocialChangeVector baseline{};
    SocialChangeVector current{};
    SocialChangeVector delta{};
    double minimum_dimension_change{};
    double composite_change{};
    bool all_dimensions_improved{};
    bool publication_eligible{};
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<DecisionPolicyAssessment, GovernanceError>
assess_decision_inputs(
    const DecisionRequest& request);

[[nodiscard]] std::expected<SocialChangeAssessment, GovernanceError>
assess_social_change(
    const SocialChangeVector& baseline,
    const SocialChangeVector& current,
    const SocialChangeEvidence& evidence);

}  // namespace augmented_hub::social_governance

#endif
