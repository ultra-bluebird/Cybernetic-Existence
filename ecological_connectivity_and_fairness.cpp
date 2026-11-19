#include "ecological_connectivity_and_fairness.hpp"

#include <algorithm>
#include <cmath>
#include <unordered_set>

namespace augmented_hub::eco_fairness {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

bool prohibited_input(DecisionInputCategory category) noexcept {
    switch (category) {
        case DecisionInputCategory::claimed_identity:
        case DecisionInputCategory::identity_status:
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

double group_support_score(
    const std::vector<HabitatPatch>& patches,
    const SpeciesGroupRequirement& requirement) {

    double weighted_support = 0.0;
    double total_weight = 0.0;

    for (const auto& patch : patches) {
        const double habitat_ratio =
            patch.habitat_required_score > kEpsilon
                ? std::min(
                    patch.habitat_available_score /
                    patch.habitat_required_score,
                    1.0)
                : 0.0;

        const double habitat_condition =
            0.45 * habitat_ratio +
            0.25 * patch.water_quality_score +
            0.20 * patch.vegetation_quality_score +
            0.10 * (1.0 - patch.barrier_severity);

        const double patch_weight =
            std::max(patch.area_m2, 1.0);

        weighted_support +=
            patch_weight * habitat_condition;

        total_weight += patch_weight;
    }

    const double mean_support =
        total_weight > kEpsilon
            ? weighted_support / total_weight
            : 0.0;

    return std::clamp(
        mean_support *
        requirement.ecological_weight *
        (1.0 - 0.25 * requirement.movement_sensitivity),
        0.0,
        1.0);
}

}  // namespace

std::expected<HabitatConnectivityAssessment, EcoFairnessError>
evaluate_multispecies_habitat_connectivity(
    const std::vector<HabitatPatch>& patches,
    const std::vector<SpeciesGroupRequirement>& requirements) {

    if (patches.empty() || requirements.empty()) {
        return std::unexpected(EcoFairnessError::empty_input);
    }

    std::unordered_set<std::string> patch_identifiers;

    for (const auto& patch : patches) {
        if (patch.patch_id.empty() ||
            !patch_identifiers.insert(patch.patch_id).second ||
            !finite_nonnegative(patch.habitat_available_score) ||
            !finite_nonnegative(patch.habitat_required_score) ||
            !finite_nonnegative(patch.area_m2) ||
            !finite_unit_interval(patch.water_quality_score) ||
            !finite_unit_interval(patch.vegetation_quality_score) ||
            !finite_unit_interval(patch.barrier_severity)) {
            return std::unexpected(EcoFairnessError::invalid_numeric_input);
        }
    }

    std::unordered_set<int> group_identifiers;
    double habitat_quality_index = 0.0;
    double total_group_weight = 0.0;

    for (const auto& requirement : requirements) {
        const int group_id = static_cast<int>(requirement.group);

        if (!group_identifiers.insert(group_id).second ||
            !finite_unit_interval(requirement.ecological_weight) ||
            !finite_unit_interval(
                requirement.minimum_habitat_quality_score) ||
            !finite_unit_interval(requirement.movement_sensitivity)) {
            return std::unexpected(EcoFairnessError::invalid_numeric_input);
        }

        double group_habitat_quality = 0.0;

        for (const auto& patch : patches) {
            const double habitat_ratio =
                patch.habitat_required_score > kEpsilon
                    ? std::min(
                        patch.habitat_available_score /
                        patch.habitat_required_score,
                        1.0)
                    : 0.0;

            group_habitat_quality +=
                requirement.ecological_weight *
                habitat_ratio;
        }

        habitat_quality_index += group_habitat_quality;
        total_group_weight += requirement.ecological_weight;
    }

    habitat_quality_index =
        total_group_weight > kEpsilon
            ? habitat_quality_index /
                (static_cast<double>(patches.size()) *
                 total_group_weight)
            : 0.0;

    double connectivity_sum = 0.0;
    std::size_t connectivity_pair_count = 0U;

    for (std::size_t first = 0; first < patches.size(); ++first) {
        for (std::size_t second = first + 1U;
             second < patches.size();
             ++second) {

            const double effective_distance =
                std::max(
                    1.0,
                    std::sqrt(
                        std::max(patches[first].area_m2, 1.0)) +
                    std::sqrt(
                        std::max(patches[second].area_m2, 1.0)) +
                    100.0 *
                    (patches[first].barrier_severity +
                     patches[second].barrier_severity));

            connectivity_sum += 1.0 / effective_distance;
            ++connectivity_pair_count;
        }
    }

    const double connectivity_index =
        connectivity_pair_count > 0U
            ? connectivity_sum /
                static_cast<double>(connectivity_pair_count)
            : 0.0;

    double aquatic_support = 0.0;
    double bird_support = 0.0;
    double pollinator_support = 0.0;
    double wildlife_support = 0.0;

    for (const auto& requirement : requirements) {
        const double support =
            group_support_score(patches, requirement);

        switch (requirement.group) {
            case SpeciesFunctionalGroup::aquatic_life:
                aquatic_support = support;
                break;
            case SpeciesFunctionalGroup::riparian_birds:
                bird_support = support;
                break;
            case SpeciesFunctionalGroup::pollinators:
                pollinator_support = support;
                break;
            case SpeciesFunctionalGroup::urban_wildlife:
                wildlife_support = support;
                break;
        }
    }

    return HabitatConnectivityAssessment{
        .habitat_quality_index =
            std::clamp(habitat_quality_index, 0.0, 1.0),
        .connectivity_index = connectivity_index,
        .aquatic_support_score = aquatic_support,
        .riparian_bird_support_score = bird_support,
        .pollinator_support_score = pollinator_support,
        .urban_wildlife_support_score = wildlife_support,
        .restoration_review_required = true,
        .plain_language_explanation =
            "This assessment combines habitat availability, water quality, vegetation quality, barriers, patch area, and functional-group sensitivity into a scenario-level ecological planning result. It identifies candidate restoration value but does not establish species presence, guarantee population outcomes, or replace field ecological review."
    };
}

std::expected<FairnessAccessAssessment, EcoFairnessError>
evaluate_identity_agnostic_access(
    const FairnessAccessRequest& request) {

    if (request.request_id.empty() ||
        request.service_scope.empty()) {
        return std::unexpected(EcoFairnessError::empty_input);
    }

    for (const auto& input : request.decision_inputs) {
        if (prohibited_input(input)) {
            return FairnessAccessAssessment{
                .outcome = AccessOutcome::policy_denial_receipt,
                .identity_verification_required = false,
                .accommodation_available = false,
                .human_review_required = true,
                .plain_language_explanation =
                    "The proposed decision path is denied because it depends on identity-linked, augmentation-related, biometric, neural, health, disability-related, private-continuity, optional-telemetry, or external-verification information. The service must be evaluated through identity-agnostic inputs."
            };
        }
    }

    if (request.voluntary_accessibility_preference_requested) {
        return FairnessAccessAssessment{
            .outcome = AccessOutcome::voluntary_interface_accommodation,
            .identity_verification_required = false,
            .accommodation_available = true,
            .human_review_required = false,
            .plain_language_explanation =
                "A voluntary accessibility preference may adapt the interaction format, input method, pacing, output format, authentication alternative, or review pathway. No identity certification or external verification is required, and the adaptation does not alter eligibility or service priority."
        };
    }

    return FairnessAccessAssessment{
        .outcome = AccessOutcome::equal_default_access,
        .identity_verification_required = false,
        .accommodation_available = true,
        .human_review_required = request.essential_service,
        .plain_language_explanation =
            "The service is provided through an identity-agnostic access path. The system does not need to verify a self-description or infer identity in order to provide equal default service, accessible options, correction pathways, or participation."
    };
}

}  // namespace augmented_hub::eco_fairness
