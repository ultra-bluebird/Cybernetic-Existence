#include "business_place_integration.hpp"

#include <algorithm>
#include <cmath>

namespace augmented_hub::business_integration {
namespace {

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

bool valid_weights(const ContributionWeights& weights) noexcept {
    return finite_unit_interval(weights.data_quality_weight) &&
        finite_unit_interval(weights.accessible_space_weight) &&
        finite_unit_interval(weights.eco_initiative_weight) &&
        finite_unit_interval(weights.maintenance_support_weight) &&
        finite_unit_interval(weights.community_benefit_weight);
}

double normalized_weight_total(
    const ContributionWeights& weights) noexcept {

    return
        weights.data_quality_weight +
        weights.accessible_space_weight +
        weights.eco_initiative_weight +
        weights.maintenance_support_weight +
        weights.community_benefit_weight;
}

bool is_prohibited_data_request(DataAccessRequest request) noexcept {
    switch (request) {
        case DataAccessRequest::identifiable_community_data:
        case DataAccessRequest::customer_linked_data:
        case DataAccessRequest::exclusive_data_access:
        case DataAccessRequest::marketing_profile_data:
            return true;
        case DataAccessRequest::aggregate_environmental_data:
        case DataAccessRequest::aggregate_community_planning_data:
            return false;
    }

    return true;
}

}  // namespace

std::expected<
    BusinessContributionAssessment,
    BusinessIntegrationError>
assess_business_contribution(
    const BusinessContribution& contribution,
    const ContributionWeights& weights) {

    if (contribution.contributor_id.empty() ||
        contribution.policy_version.empty()) {
        return std::unexpected(
            BusinessIntegrationError::empty_required_field);
    }

    if (!finite_unit_interval(contribution.data_quality_score) ||
        !finite_unit_interval(contribution.accessible_space_score) ||
        !finite_unit_interval(
            contribution.verified_eco_initiative_score) ||
        !finite_unit_interval(contribution.maintenance_support_score) ||
        !finite_unit_interval(contribution.community_benefit_score) ||
        !finite_unit_interval(contribution.resource_burden_score) ||
        !valid_weights(weights) ||
        normalized_weight_total(weights) <= 0.0) {
        return std::unexpected(
            BusinessIntegrationError::invalid_numeric_input);
    }

    if (contribution.identity_linked_data_collected) {
        return std::unexpected(
            BusinessIntegrationError::prohibited_contribution_use);
    }

    if (!contribution.data_minimization_commitment ||
        !contribution.accessible_grievance_path_available ||
        !contribution.plain_language_terms_accepted) {
        return BusinessContributionAssessment{
            .normalized_contribution_value = 0.0,
            .status = ContributionStatus::hold_for_review,
            .nonexclusive_access_required = true,
            .size_neutral_participation = true,
            .plain_language_explanation =
                "The contribution remains on hold because required data-minimization, accessible-grievance, or plain-language participation commitments are not complete. The hold does not prevent the contributor from using public services or participating through another supported pathway."
        };
    }

    const double weighted_value =
        weights.data_quality_weight *
            contribution.data_quality_score +
        weights.accessible_space_weight *
            contribution.accessible_space_score +
        weights.eco_initiative_weight *
            contribution.verified_eco_initiative_score +
        weights.maintenance_support_weight *
            contribution.maintenance_support_score +
        weights.community_benefit_weight *
            contribution.community_benefit_score;

    const double burden_adjustment =
        1.0 - 0.20 * contribution.resource_burden_score;

    const double normalized_value =
        std::clamp(
            weighted_value / normalized_weight_total(weights) *
            burden_adjustment,
            0.0,
            1.0);

    return BusinessContributionAssessment{
        .normalized_contribution_value = normalized_value,
        .status = ContributionStatus::candidate_for_review,
        .nonexclusive_access_required = true,
        .size_neutral_participation = true,
        .plain_language_explanation =
            "This contribution is recorded as a capacity-aware, nonexclusive community benefit. It may support environmental, gathering-space, repair, or eco-initiative planning after review, but it does not create exclusive community-data access, increased civic authority, preferential service access, or a business-size-based advantage."
    };
}

std::expected<DataAccessAssessment, BusinessIntegrationError>
assess_business_data_access(
    DataAccessRequest request,
    bool requester_has_approved_role,
    const std::string& policy_version) {

    if (policy_version.empty()) {
        return std::unexpected(
            BusinessIntegrationError::invalid_policy_version);
    }

    if (is_prohibited_data_request(request)) {
        return DataAccessAssessment{
            .permitted = false,
            .nonexclusive_terms_required = true,
            .human_review_required = true,
            .plain_language_explanation =
                "This data-access request is denied. Businesses may not receive identifiable community data, customer-linked data, marketing-profile data, or exclusive access to aggregate community information in exchange for contribution."
        };
    }

    if (!requester_has_approved_role) {
        return DataAccessAssessment{
            .permitted = false,
            .nonexclusive_terms_required = true,
            .human_review_required = true,
            .plain_language_explanation =
                "This aggregate-data request requires an approved role, purpose-bound access terms, and an auditable access receipt. Contribution volume or business size does not substitute for governance approval."
        };
    }

    return DataAccessAssessment{
        .permitted = true,
        .nonexclusive_terms_required = true,
        .human_review_required = true,
        .plain_language_explanation =
            "Approved access is limited to purpose-bound, aggregate, non-identifying data under equal nonexclusive terms. The access decision is independent of business size, revenue, brand, contribution amount, or identity."
    };
}

}  // namespace augmented_hub::business_integration
