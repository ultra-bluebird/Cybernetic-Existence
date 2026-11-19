#ifndef AUGMENTED_HUB_ECOLOGICAL_CONNECTIVITY_AND_FAIRNESS_HPP
#define AUGMENTED_HUB_ECOLOGICAL_CONNECTIVITY_AND_FAIRNESS_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::eco_fairness {

enum class EcoFairnessError {
    empty_input,
    invalid_numeric_input,
    duplicate_identifier,
    invalid_access_request,
    prohibited_decision_input,
    insufficient_ecological_evidence
};

enum class SpeciesFunctionalGroup {
    aquatic_life,
    riparian_birds,
    pollinators,
    urban_wildlife
};

enum class DecisionInputCategory {
    environmental_evidence,
    ecological_review,
    operational_safety,
    service_capacity,
    accessibility_preference,
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

enum class AccessOutcome {
    equal_default_access,
    voluntary_interface_accommodation,
    policy_denial_receipt,
    hold_for_review
};

struct HabitatPatch {
    std::string patch_id;
    double habitat_available_score{};
    double habitat_required_score{};
    double area_m2{};
    double water_quality_score{};
    double vegetation_quality_score{};
    double barrier_severity{};
    bool restoration_candidate{};
};

struct SpeciesGroupRequirement {
    SpeciesFunctionalGroup group{};
    double ecological_weight{};
    double minimum_habitat_quality_score{};
    double movement_sensitivity{};
};

struct HabitatConnectivityAssessment {
    double habitat_quality_index{};
    double connectivity_index{};
    double aquatic_support_score{};
    double riparian_bird_support_score{};
    double pollinator_support_score{};
    double urban_wildlife_support_score{};
    bool restoration_review_required{};
    std::string plain_language_explanation;
};

struct FairnessAccessRequest {
    std::string request_id;
    std::string service_scope;
    std::vector<DecisionInputCategory> decision_inputs;
    bool voluntary_accessibility_preference_requested{};
    bool essential_service{};
    bool external_identity_verification_available{};
};

struct FairnessAccessAssessment {
    AccessOutcome outcome{AccessOutcome::equal_default_access};
    bool identity_verification_required{};
    bool accommodation_available{};
    bool human_review_required{};
    std::string plain_language_explanation;
};

[[nodiscard]]
std::expected<HabitatConnectivityAssessment, EcoFairnessError>
evaluate_multispecies_habitat_connectivity(
    const std::vector<HabitatPatch>& patches,
    const std::vector<SpeciesGroupRequirement>& requirements);

[[nodiscard]]
std::expected<FairnessAccessAssessment, EcoFairnessError>
evaluate_identity_agnostic_access(
    const FairnessAccessRequest& request);

}  // namespace augmented_hub::eco_fairness

#endif
