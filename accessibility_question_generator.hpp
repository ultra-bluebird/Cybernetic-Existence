#ifndef AUGMENTED_HUB_ACCESSIBILITY_QUESTION_GENERATOR_HPP
#define AUGMENTED_HUB_ACCESSIBILITY_QUESTION_GENERATOR_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::accessibility_questions {

enum class AccessibilityQuestionError {
    empty_required_field,
    insufficient_aggregation,
    invalid_governance_status
};

enum class ExternalActionStatus {
    prohibited,
    informational_only,
    requires_separate_approval,
    approved_for_bounded_action
};

enum class AccessibilityQuestionCategory {
    aggregate_interaction_difficulty,
    confusing_interface_element,
    cognitive_navigation_simplification,
    input_modality_equivalence,
    language_support_gap,
    path_condition_degradation,
    recurring_path_obstacle,
    lighting_sufficiency,
    ramp_gradient_assessment,
    path_maintenance_priority
};

struct AggregateEvidenceReference {
    std::string dataset_id;
    std::string measurement_window;
    std::string spatial_or_interface_precision;
    std::size_t aggregation_count{};
    bool non_identifying{};
    bool uncertainty_disclosed{};
    bool methodology_versioned{};
};

struct AssistancePanelQuestionContext {
    std::string panel_group_id;
    AggregateEvidenceReference language_data;
    AggregateEvidenceReference interaction_data;
    AggregateEvidenceReference error_data;
    AggregateEvidenceReference accessibility_feature_data;
    AggregateEvidenceReference help_request_data;
    std::string accessibility_policy_reference;
    std::string governed_impact_shard_reference;
    ExternalActionStatus external_action_status{
        ExternalActionStatus::requires_separate_approval
    };
};

struct AccessiblePathQuestionContext {
    std::string path_network_id;
    AggregateEvidenceReference surface_condition_data;
    AggregateEvidenceReference obstacle_data;
    AggregateEvidenceReference lighting_data;
    AggregateEvidenceReference audio_guidance_data;
    AggregateEvidenceReference gradient_data;
    AggregateEvidenceReference door_operation_data;
    std::string accessibility_policy_reference;
    std::string governed_impact_shard_reference;
    ExternalActionStatus external_action_status{
        ExternalActionStatus::requires_separate_approval
    };
};

struct GeneratedAccessibilityQuestion {
    AccessibilityQuestionCategory category{};
    std::string question;
    std::string required_evidence;
    std::string privacy_and_rights_boundary;
    bool requires_human_review{};
};

struct AccessibilityQuestionGenerationResult {
    std::vector<GeneratedAccessibilityQuestion> questions;
    std::string plain_language_explanation;
};

[[nodiscard]]
std::expected<AccessibilityQuestionGenerationResult, AccessibilityQuestionError>
generate_assistance_panel_questions(
    const AssistancePanelQuestionContext& context);

[[nodiscard]]
std::expected<AccessibilityQuestionGenerationResult, AccessibilityQuestionError>
generate_accessible_path_questions(
    const AccessiblePathQuestionContext& context);

}  // namespace augmented_hub::accessibility_questions

#endif
