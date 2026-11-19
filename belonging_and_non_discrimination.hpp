#ifndef AUGMENTED_HUB_BELONGING_AND_NON_DISCRIMINATION_HPP
#define AUGMENTED_HUB_BELONGING_AND_NON_DISCRIMINATION_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::belonging {

enum class BelongingError {
    empty_required_field,
    prohibited_decision_input,
    invalid_request,
    inaccessible_service_path
};

enum class DecisionInputCategory {
    environmental_evidence,
    operational_safety,
    service_capacity,
    infrastructure_condition,
    approved_policy,
    voluntary_accessibility_preference,
    claimed_identity,
    identity_status,
    private_motivation,
    purposeful_reason_to_exist,
    augmentation_status,
    assistive_technology_status,
    biometric_information,
    neural_information,
    health_information,
    disability_related_information,
    private_learning_continuity,
    optional_telemetry_absence,
    external_identity_verification_absence
};

enum class ServiceOutcome {
    equal_default_access,
    voluntary_interface_adaptation,
    identity_linked_decision_denied,
    hold_for_human_review
};

struct ServiceRequest {
    std::string request_id;
    std::string service_scope;
    bool essential_service{};
    bool voluntary_accessibility_preference_requested{};
    bool accessible_default_path_available{};
    bool accessible_review_path_available{};
    std::vector<DecisionInputCategory> decision_inputs;
};

struct BelongingAssessment {
    ServiceOutcome outcome{ServiceOutcome::hold_for_human_review};
    bool private_motivation_required{};
    bool identity_verification_required{};
    bool accommodation_available{};
    bool human_review_required{};
    std::string plain_language_explanation;
};

[[nodiscard]]
std::expected<BelongingAssessment, BelongingError>
evaluate_belonging_and_access(
    const ServiceRequest& request);

}  // namespace augmented_hub::belonging

#endif
