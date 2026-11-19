#ifndef AUGMENTED_HUB_BUSINESS_PLACE_INTEGRATION_HPP
#define AUGMENTED_HUB_BUSINESS_PLACE_INTEGRATION_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::business_integration {

enum class BusinessIntegrationError {
    empty_required_field,
    invalid_numeric_input,
    prohibited_data_access,
    prohibited_contribution_use,
    insufficient_accessibility_evidence,
    invalid_policy_version
};

enum class ContributionType {
    environmental_sensor_hosting,
    accessible_gathering_space,
    eco_initiative,
    maintenance_support,
    repair_material_reuse,
    community_event_support
};

enum class DataAccessRequest {
    aggregate_environmental_data,
    aggregate_community_planning_data,
    identifiable_community_data,
    customer_linked_data,
    exclusive_data_access,
    marketing_profile_data
};

enum class ContributionStatus {
    candidate_for_review,
    qualified,
    accepted_with_limitations,
    hold_for_review
};

struct BusinessContribution {
    std::string contributor_id;
    ContributionType type{};
    double data_quality_score{};
    double accessible_space_score{};
    double verified_eco_initiative_score{};
    double maintenance_support_score{};
    double community_benefit_score{};
    double resource_burden_score{};
    bool data_minimization_commitment{};
    bool accessible_grievance_path_available{};
    bool plain_language_terms_accepted{};
    bool identity_linked_data_collected{};
    std::string policy_version;
};

struct ContributionWeights {
    double data_quality_weight{0.25};
    double accessible_space_weight{0.25};
    double eco_initiative_weight{0.25};
    double maintenance_support_weight{0.15};
    double community_benefit_weight{0.10};
};

struct BusinessContributionAssessment {
    double normalized_contribution_value{};
    ContributionStatus status{ContributionStatus::hold_for_review};
    bool nonexclusive_access_required{};
    bool size_neutral_participation{};
    std::string plain_language_explanation;
};

struct DataAccessAssessment {
    bool permitted{};
    bool nonexclusive_terms_required{};
    bool human_review_required{};
    std::string plain_language_explanation;
};

[[nodiscard]]
std::expected<BusinessContributionAssessment, BusinessIntegrationError>
assess_business_contribution(
    const BusinessContribution& contribution,
    const ContributionWeights& weights);

[[nodiscard]]
std::expected<DataAccessAssessment, BusinessIntegrationError>
assess_business_data_access(
    DataAccessRequest request,
    bool requester_has_approved_role,
    const std::string& policy_version);

}  // namespace augmented_hub::business_integration

#endif
