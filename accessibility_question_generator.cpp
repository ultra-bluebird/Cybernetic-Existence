#include "accessibility_question_generator.hpp"

namespace augmented_hub::accessibility_questions {
namespace {

constexpr std::size_t kMinimumAggregationCount = 20U;

bool valid_evidence_reference(
    const AggregateEvidenceReference& reference) {

    return !reference.dataset_id.empty() &&
        !reference.measurement_window.empty() &&
        !reference.spatial_or_interface_precision.empty() &&
        reference.aggregation_count >= kMinimumAggregationCount &&
        reference.non_identifying &&
        reference.uncertainty_disclosed &&
        reference.methodology_versioned;
}

bool valid_action_status(ExternalActionStatus status) {
    switch (status) {
        case ExternalActionStatus::prohibited:
        case ExternalActionStatus::informational_only:
        case ExternalActionStatus::requires_separate_approval:
        case ExternalActionStatus::approved_for_bounded_action:
            return true;
    }

    return false;
}

}  // namespace

std::expected<
    AccessibilityQuestionGenerationResult,
    AccessibilityQuestionError>
generate_assistance_panel_questions(
    const AssistancePanelQuestionContext& context) {

    if (context.panel_group_id.empty() ||
        context.accessibility_policy_reference.empty() ||
        context.governed_impact_shard_reference.empty()) {
        return std::unexpected(
            AccessibilityQuestionError::empty_required_field);
    }

    if (!valid_evidence_reference(context.language_data) ||
        !valid_evidence_reference(context.interaction_data) ||
        !valid_evidence_reference(context.error_data) ||
        !valid_evidence_reference(context.accessibility_feature_data) ||
        !valid_evidence_reference(context.help_request_data)) {
        return std::unexpected(
            AccessibilityQuestionError::insufficient_aggregation);
    }

    if (!valid_action_status(context.external_action_status)) {
        return std::unexpected(
            AccessibilityQuestionError::invalid_governance_status);
    }

    return AccessibilityQuestionGenerationResult{
        .questions = {
            GeneratedAccessibilityQuestion{
                .category =
                    AccessibilityQuestionCategory::aggregate_interaction_difficulty,
                .question =
                    "For assistance panel group " + context.panel_group_id +
                    ", which interface journeys show aggregate signals of interaction difficulty, including elevated completion time, repeated errors, help requests, abandonment, or accessibility-feature switching? Which panel functions should receive a usability and accessibility review first?",
                .required_evidence =
                    "Use aggregate interaction dataset " +
                    context.interaction_data.dataset_id +
                    ", error dataset " + context.error_data.dataset_id +
                    ", help-request dataset " +
                    context.help_request_data.dataset_id +
                    ", and impact shard " +
                    context.governed_impact_shard_reference + ".",
                .privacy_and_rights_boundary =
                    "Describe barriers in the panel experience. Do not infer, identify, classify, or score user identity, disability, augmentation status, language identity, cognitive state, or assistive-technology use.",
                .requires_human_review = true
            },
            GeneratedAccessibilityQuestion{
                .category =
                    AccessibilityQuestionCategory::confusing_interface_element,
                .question =
                    "Which interface elements in panel group " +
                    context.panel_group_id +
                    " have the highest aggregate error, correction, timeout, backtracking, or help-request rates by task step? What plain-language labels, feedback, input guidance, error recovery, or layout adjustments should be evaluated?",
                .required_evidence =
                    "Use step-level aggregate error data " +
                    context.error_data.dataset_id +
                    ", non-identifying help-request patterns " +
                    context.help_request_data.dataset_id +
                    ", interface version records, and accessible usability review notes.",
                .privacy_and_rights_boundary =
                    "Do not make assumptions about a person's capability from an error event. Preserve a dignified recovery path and provide accessible alternatives without requiring explanation or disclosure.",
                .requires_human_review = true
            },
            GeneratedAccessibilityQuestion{
                .category =
                    AccessibilityQuestionCategory::cognitive_navigation_simplification,
                .question =
                    "Which high-frequency panel tasks can be completed with fewer decisions, clearer progress cues, reduced memory demand, plain-language instructions, reversible steps, and predictable error recovery while preserving access to all essential services?",
                .required_evidence =
                    "Use aggregate journey duration and error evidence from " +
                    context.interaction_data.dataset_id +
                    ", interface task maps, accessibility review findings, and policy " +
                    context.accessibility_policy_reference + ".",
                .privacy_and_rights_boundary =
                    "Simplification must expand choice and clarity; it must not hide services, remove independent control, force a reduced interface, or condition access on cognitive or identity disclosure.",
                .requires_human_review = true
            },
            GeneratedAccessibilityQuestion{
                .category =
                    AccessibilityQuestionCategory::input_modality_equivalence,
                .question =
                    "Do touch, physical keyboard or tactile controls, voice output and input alternatives, gesture pathways, and other supported interaction modes provide equivalent completion success, time, error recovery, privacy, and service scope for panel group " +
                    context.panel_group_id +
                    "? Which modality has an environment-created barrier that should be removed?",
                .required_evidence =
                    "Use aggregate accessibility-feature dataset " +
                    context.accessibility_feature_data.dataset_id +
                    ", task-completion aggregates, hardware health records, environmental-noise/lighting context, and accessibility conformance evidence.",
                .privacy_and_rights_boundary =
                    "No interaction modality may become a condition for service. Voice, gesture, touch, or other optional input must have non-surveilling, accessible alternatives.",
                .requires_human_review = true
            },
            GeneratedAccessibilityQuestion{
                .category =
                    AccessibilityQuestionCategory::language_support_gap,
                .question =
                    "Which language selections, help pathways, translation-error reports, or task-abandonment patterns indicate that panel group " +
                    context.panel_group_id +
                    " needs additional language support, clearer translation, audio alternatives, visual explanation, or community-reviewed content?",
                .required_evidence =
                    "Use aggregate language-selection evidence " +
                    context.language_data.dataset_id +
                    ", aggregate error and help-request data, approved language-content inventory, and plain-language review records.",
                .privacy_and_rights_boundary =
                    "Language-choice patterns are aggregate service-design evidence only. Do not infer nationality, immigration status, ethnicity, identity, or personal characteristics from language selection.",
                .requires_human_review = true
            }
        },
        .plain_language_explanation =
            "These questions improve assistance-panel clarity, accessible interaction, language support, and error recovery through aggregate evidence. They identify interface barriers without identifying or tracking people."
    };
}

std::expected<
    AccessibilityQuestionGenerationResult,
    AccessibilityQuestionError>
generate_accessible_path_questions(
    const AccessiblePathQuestionContext& context) {

    if (context.path_network_id.empty() ||
        context.accessibility_policy_reference.empty() ||
        context.governed_impact_shard_reference.empty()) {
        return std::unexpected(
            AccessibilityQuestionError::empty_required_field);
    }

    if (!valid_evidence_reference(context.surface_condition_data) ||
        !valid_evidence_reference(context.obstacle_data) ||
        !valid_evidence_reference(context.lighting_data) ||
        !valid_evidence_reference(context.audio_guidance_data) ||
        !valid_evidence_reference(context.gradient_data) ||
        !valid_evidence_reference(context.door_operation_data)) {
        return std::unexpected(
            AccessibilityQuestionError::insufficient_aggregation);
    }

    if (!valid_action_status(context.external_action_status)) {
        return std::unexpected(
            AccessibilityQuestionError::invalid_governance_status);
    }

    return AccessibilityQuestionGenerationResult{
        .questions = {
            GeneratedAccessibilityQuestion{
                .category =
                    AccessibilityQuestionCategory::path_condition_degradation,
                .question =
                    "Which segments in accessible-path network " +
                    context.path_network_id +
                    " show surface degradation, discontinuity, cross-slope change, drainage issue, vibration risk, or door-access interruption that exceeds the applicable accessible-route maintenance corridor? What evidence, uncertainty, and site confirmation are required before repair planning?",
                .required_evidence =
                    "Use surface-condition data " +
                    context.surface_condition_data.dataset_id +
                    ", door-operation data " +
                    context.door_operation_data.dataset_id +
                    ", survey records, measurement uncertainty, and policy " +
                    context.accessibility_policy_reference + ".",
                .privacy_and_rights_boundary =
                    "Evaluate environmental and infrastructure conditions only. Do not collect route histories, mobility-device identifiers, personal tracking data, or identity-linked accessibility telemetry.",
                .requires_human_review = true
            },
            GeneratedAccessibilityQuestion{
                .category =
                    AccessibilityQuestionCategory::recurring_path_obstacle,
                .question =
                    "Which obstacle types and path segments in network " +
                    context.path_network_id +
                    " recur most often, how long do they persist, and which responsible maintenance or service workflow can remove them while preserving emergency access and a clearly marked accessible alternate route?",
                .required_evidence =
                    "Use aggregate obstacle dataset " +
                    context.obstacle_data.dataset_id +
                    ", maintenance records, emergency-access policy, and temporary-route inspection evidence.",
                .privacy_and_rights_boundary =
                    "Do not use cameras, audio, or proximity data to identify pedestrians. Obstacle analysis must remain aggregate and infrastructure-focused.",
                .requires_human_review = true
            },
            GeneratedAccessibilityQuestion{
                .category =
                    AccessibilityQuestionCategory::lighting_sufficiency,
                .question =
                    "At which hours and path segments does lighting in network " +
                    context.path_network_id +
                    " fall below the project’s safe-navigation operating threshold after accounting for weather, power availability, glare, shadow, maintenance state, and emergency conditions? Which resilient lighting intervention provides the greatest access benefit?",
                .required_evidence =
                    "Use lighting dataset " +
                    context.lighting_data.dataset_id +
                    ", weather data, power-system telemetry, maintenance status, and accessible-path inspection records.",
                .privacy_and_rights_boundary =
                    "Assess illumination and infrastructure reliability, not pedestrian behavior or identity. Preserve lighting for safe, equitable access rather than optimizing only for aggregate traffic volume.",
                .requires_human_review = true
            },
            GeneratedAccessibilityQuestion{
                .category =
                    AccessibilityQuestionCategory::ramp_gradient_assessment,
                .question =
                    "Which ramp or transition segments in network " +
                    context.path_network_id +
                    " have measured running slope, cross slope, landing condition, surface condition, or handrail-related indicators that require field review against the applicable project accessibility standard? What repair alternatives preserve route continuity during work?",
                .required_evidence =
                    "Use gradient dataset " +
                    context.gradient_data.dataset_id +
                    ", surface-condition data, surveyed geometry, jurisdiction-specific project requirements, and accessible detour plans.",
                .privacy_and_rights_boundary =
                    "This is an infrastructure-conformance and maintenance question, not a judgment about who uses the ramp or what assistive technology they may use.",
                .requires_human_review = true
            },
            GeneratedAccessibilityQuestion{
                .category =
                    AccessibilityQuestionCategory::path_maintenance_priority,
                .question =
                    "Which accessible-path maintenance candidates should be prioritized using a transparent score that combines safety risk, route continuity, barrier severity, lighting reliability, door-function availability, environmental exposure, and access to essential destinations—without using individual identity or personal route history?",
                .required_evidence =
                    "Use all approved aggregate path datasets, access-to-essential-destination analysis, work-order evidence, ecological impact estimates, and governed impact shard " +
                    context.governed_impact_shard_reference + ".",
                .privacy_and_rights_boundary =
                    "Prioritize barrier removal and equivalent access. Do not lower a path’s priority because observed use is low or because individual users have not disclosed access needs.",
                .requires_human_review = true
            }
        },
        .plain_language_explanation =
            "These questions support accessible-route inspection and maintenance from aggregate environmental and infrastructure evidence. They preserve route continuity and accessible alternatives while prohibiting individual tracking."
    };
}

}  // namespace augmented_hub::accessibility_questions
