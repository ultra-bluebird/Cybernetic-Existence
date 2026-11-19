#include "augmented_hub_core.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <sstream>
#include <unordered_set>
#include <utility>

namespace augmented_hub::core {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

bool valid_interval(const TimeInterval& interval) noexcept {
    return interval.end >= interval.start;
}

bool has_required_aggregate_properties(
    const AggregateEvidenceReference& reference,
    std::size_t minimum_aggregate_count) {

    return !reference.dataset_id.empty() &&
        !reference.spatial_or_interface_precision.empty() &&
        valid_interval(reference.measurement_window) &&
        reference.aggregation_count >= minimum_aggregate_count &&
        reference.non_identifying &&
        reference.uncertainty_disclosed &&
        reference.methodology_versioned;
}

bool identity_linked_input(ServiceInputClass input) noexcept {
    return input == ServiceInputClass::prohibited_identity_linked;
}

bool scenario_is_feasible(
    const PlanningScenario& scenario,
    const EpsilonValues& constraints) noexcept {

    return scenario.satisfies_non_discrimination_invariant &&
        scenario.preserves_essential_access &&
        scenario.social_inequity <= constraints.maximum_social_inequity &&
        scenario.total_cost <= constraints.maximum_total_cost &&
        scenario.accessibility_benefit + kEpsilon >=
            constraints.minimum_accessibility_benefit &&
        scenario.harm_risk <= constraints.maximum_harm_risk;
}

bool dominates(
    const PlanningScenario& left,
    const PlanningScenario& right) noexcept {

    const bool no_worse =
        left.ecological_benefit >= right.ecological_benefit &&
        left.social_inequity <= right.social_inequity &&
        left.accessibility_benefit >= right.accessibility_benefit &&
        left.total_cost <= right.total_cost &&
        left.maintenance_burden <= right.maintenance_burden &&
        left.water_or_energy_burden <= right.water_or_energy_burden &&
        left.harm_risk <= right.harm_risk &&
        left.uncertainty <= right.uncertainty;

    const bool strictly_better =
        left.ecological_benefit > right.ecological_benefit ||
        left.social_inequity < right.social_inequity ||
        left.accessibility_benefit > right.accessibility_benefit ||
        left.total_cost < right.total_cost ||
        left.maintenance_burden < right.maintenance_burden ||
        left.water_or_energy_burden < right.water_or_energy_burden ||
        left.harm_risk < right.harm_risk ||
        left.uncertainty < right.uncertainty;

    return no_worse && strictly_better;
}

ServiceRequest stripped_identity_equivalent(
    const ServiceRequest& request) {

    ServiceRequest equivalent = request;

    equivalent.decision_inputs.erase(
        std::remove(
            equivalent.decision_inputs.begin(),
            equivalent.decision_inputs.end(),
            ServiceInputClass::prohibited_identity_linked),
        equivalent.decision_inputs.end());

    return equivalent;
}

}  // namespace

AccessibilityQuestionGenerator::AccessibilityQuestionGenerator(
    std::size_t minimum_aggregate_count)
    : minimum_aggregate_count_(minimum_aggregate_count) {
}

std::expected<
    AccessibilityQuestionGenerationResult,
    CoreError>
AccessibilityQuestionGenerator::generate_assistance_panel_questions(
    const AssistancePanelQuestionContext& context) const {

    if (context.panel_group_id.empty() ||
        context.accessibility_policy_reference.empty() ||
        context.governed_impact_shard_reference.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    if (!has_required_aggregate_properties(
            context.language_data,
            minimum_aggregate_count_) ||
        !has_required_aggregate_properties(
            context.interaction_data,
            minimum_aggregate_count_) ||
        !has_required_aggregate_properties(
            context.error_data,
            minimum_aggregate_count_) ||
        !has_required_aggregate_properties(
            context.accessibility_feature_data,
            minimum_aggregate_count_) ||
        !has_required_aggregate_properties(
            context.help_request_data,
            minimum_aggregate_count_)) {
        return std::unexpected(CoreError::insufficient_aggregation);
    }

    return AccessibilityQuestionGenerationResult{
        .questions = {
            {
                .category =
                    AccessibilityQuestionCategory::
                        aggregate_interaction_difficulty,
                .question =
                    "Which assistance-panel journeys show aggregate signs of interaction difficulty, including longer completion time, repeated error recovery, help requests, or abandonment, and which interface function should receive an accessibility review first?",
                .required_evidence =
                    "Use aggregate interaction, error, help-request, accessibility-function, and language-support evidence referenced by the governed impact shard.",
                .privacy_and_rights_boundary =
                    "Identify environmental and interface barriers only. Do not identify, infer, classify, or score people, identity, disability, augmentation status, cognitive state, or assistive-technology use.",
                .requires_human_review = true
            },
            {
                .category =
                    AccessibilityQuestionCategory::
                        confusing_interface_element,
                .question =
                    "Which panel elements have elevated aggregate timeout, correction, backtracking, or help-request rates, and what plain-language, feedback, input-guidance, layout, or error-recovery change should be evaluated?",
                .required_evidence =
                    "Use versioned interface steps, aggregate error data, voluntary non-identifying help outcomes, and accessibility review evidence.",
                .privacy_and_rights_boundary =
                    "An error is evidence of an interface condition, not evidence about a person's capability or identity.",
                .requires_human_review = true
            },
            {
                .category =
                    AccessibilityQuestionCategory::
                        cognitive_navigation_simplification,
                .question =
                    "How can essential panel tasks be completed with fewer decisions, clear progress cues, reversible steps, plain language, predictable recovery, and preserved independent control?",
                .required_evidence =
                    "Use aggregate task duration, error patterns, accessibility review records, and essential-service workflow requirements.",
                .privacy_and_rights_boundary =
                    "Simplification must expand usable options and must not hide services, force a reduced interface, or require cognitive or identity disclosure.",
                .requires_human_review = true
            },
            {
                .category =
                    AccessibilityQuestionCategory::
                        input_modality_equivalence,
                .question =
                    "Do available touch, keyboard, tactile, voice, nonvoice, switch, and other interaction pathways provide equivalent success, privacy, error recovery, and service scope?",
                .required_evidence =
                    "Use aggregate modality availability, task completion, hardware health, lighting/noise context, and accessibility conformance evidence.",
                .privacy_and_rights_boundary =
                    "No modality may become a condition for service, and optional use of an accessibility feature cannot affect eligibility or priority.",
                .requires_human_review = true
            },
            {
                .category =
                    AccessibilityQuestionCategory::language_support_gap,
                .question =
                    "Which aggregate language selections, translation-error signals, help pathways, or task-abandonment patterns indicate a need for clearer language support, visual explanation, audio alternatives, or community-reviewed content?",
                .required_evidence =
                    "Use aggregate language selections, error aggregates, approved content inventory, and plain-language review records.",
                .privacy_and_rights_boundary =
                    "Language patterns are service-design evidence only and must not be used to infer nationality, ethnicity, immigration status, identity, or personal characteristics.",
                .requires_human_review = true
            }
        },
        .plain_language_explanation =
            "The generated questions evaluate assistance-panel conditions from aggregate, non-identifying evidence. They support accessible improvement review and do not authorize interface deployment or external action."
    };
}

std::expected<
    AccessibilityQuestionGenerationResult,
    CoreError>
AccessibilityQuestionGenerator::generate_accessible_path_questions(
    const AccessiblePathQuestionContext& context) const {

    if (context.path_network_id.empty() ||
        context.accessibility_policy_reference.empty() ||
        context.governed_impact_shard_reference.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    if (!has_required_aggregate_properties(
            context.surface_condition_data,
            minimum_aggregate_count_) ||
        !has_required_aggregate_properties(
            context.obstacle_data,
            minimum_aggregate_count_) ||
        !has_required_aggregate_properties(
            context.lighting_data,
            minimum_aggregate_count_) ||
        !has_required_aggregate_properties(
            context.audio_guidance_data,
            minimum_aggregate_count_) ||
        !has_required_aggregate_properties(
            context.gradient_data,
            minimum_aggregate_count_) ||
        !has_required_aggregate_properties(
            context.door_operation_data,
            minimum_aggregate_count_)) {
        return std::unexpected(CoreError::insufficient_aggregation);
    }

    return AccessibilityQuestionGenerationResult{
        .questions = {
            {
                .category =
                    AccessibilityQuestionCategory::
                        path_condition_degradation,
                .question =
                    "Which path segments show surface degradation, discontinuity, drainage concerns, cross-slope change, vibration risk, or door-access interruption that requires accessible-route maintenance review?",
                .required_evidence =
                    "Use measured surface, door-operation, geometry, uncertainty, and approved accessible-route policy evidence.",
                .privacy_and_rights_boundary =
                    "Evaluate infrastructure conditions only. Do not collect personal route history, mobility-device identifiers, identity data, or individual tracking records.",
                .requires_human_review = true
            },
            {
                .category =
                    AccessibilityQuestionCategory::recurring_path_obstacle,
                .question =
                    "Which obstacle types and path segments recur most often, how long do they persist, and which maintenance workflow can remove them while preserving emergency access and an accessible alternate route?",
                .required_evidence =
                    "Use aggregate obstacle observations, maintenance records, temporary-route inspections, and emergency-access requirements.",
                .privacy_and_rights_boundary =
                    "Obstacle analysis must remain infrastructure-focused and must not identify or profile pedestrians.",
                .requires_human_review = true
            },
            {
                .category =
                    AccessibilityQuestionCategory::lighting_sufficiency,
                .question =
                    "Which hours and path segments have lighting conditions that fall below the approved safe-navigation operating threshold after accounting for weather, power availability, glare, shadow, and maintenance state?",
                .required_evidence =
                    "Use lighting telemetry, weather, power-state, maintenance, and accessible-route inspection evidence.",
                .privacy_and_rights_boundary =
                    "Assess illumination and infrastructure reliability, not pedestrian behavior, identity, or travel patterns.",
                .requires_human_review = true
            },
            {
                .category =
                    AccessibilityQuestionCategory::ramp_gradient_assessment,
                .question =
                    "Which ramp or transition segments require field review based on measured running slope, cross slope, landing condition, surface quality, handrail condition, and route-continuity requirements?",
                .required_evidence =
                    "Use surveyed geometry, gradient data, surface-condition data, approved project requirements, and accessible detour plans.",
                .privacy_and_rights_boundary =
                    "This is an infrastructure assessment and does not depend on who uses the route or what assistive technology they use.",
                .requires_human_review = true
            },
            {
                .category =
                    AccessibilityQuestionCategory::path_maintenance_priority,
                .question =
                    "Which accessible-path repairs should be prioritized using safety risk, route continuity, barrier severity, lighting reliability, door availability, environmental exposure, and access to essential destinations?",
                .required_evidence =
                    "Use aggregate infrastructure evidence, maintenance records, ecological effects, and the governed impact shard.",
                .privacy_and_rights_boundary =
                    "Do not reduce priority because observed use is low or because people have not disclosed an access need.",
                .requires_human_review = true
            }
        },
        .plain_language_explanation =
            "The generated questions support accessible-path inspection and planning through aggregate infrastructure evidence. They preserve identity-agnostic access and require review before repairs or service changes."
    };
}

DriftDiscriminator::DriftDiscriminator(DriftPolicy policy)
    : policy_(policy) {
}

std::expected<DriftAssessment, CoreError>
DriftDiscriminator::assess(
    const TelemetryEnvelope& current,
    const CalibrationRecord& calibration,
    const std::vector<TelemetryEnvelope>& neighbors) const {

    if (current.artifact_id.empty() ||
        current.phenomenon.empty() ||
        current.unit.empty() ||
        calibration.sensor_artifact_id.empty() ||
        calibration.calibration_reference.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    if (!finite_nonnegative(current.uncertainty_value) ||
        !finite_nonnegative(calibration.expected_standard_deviation) ||
        policy_.minimum_neighbor_count == 0U ||
        !finite_nonnegative(policy_.baseline_z_threshold) ||
        !finite_nonnegative(policy_.recalibration_z_threshold) ||
        policy_.recalibration_z_threshold <
            policy_.baseline_z_threshold ||
        !finite_unit_interval(
            policy_.required_neighbor_anomaly_fraction)) {
        return std::unexpected(CoreError::invalid_numeric_input);
    }

    if (neighbors.size() < policy_.minimum_neighbor_count) {
        return std::unexpected(CoreError::insufficient_neighbor_evidence);
    }

    const bool calibration_expired =
        current.observed_at_utc > calibration.valid_until_utc;

    const bool stabilization_active =
        current.observed_at_utc >= calibration.calibrated_at_utc &&
        current.observed_at_utc - calibration.calibrated_at_utc <=
            policy_.stabilization_window;

    const SensorState sensor_state =
        !calibration.calibration_accepted || calibration_expired
            ? SensorState::recalibration_window
            : stabilization_active
                ? SensorState::post_recalibration_stabilization
                : current.quality_status == QualityStatus::validated
                    ? SensorState::validated
                    : SensorState::stable;

    const double threshold =
        sensor_state == SensorState::recalibration_window ||
        sensor_state == SensorState::post_recalibration_stabilization
            ? policy_.recalibration_z_threshold
            : policy_.baseline_z_threshold;

    double neighbor_sum = 0.0;
    double neighbor_uncertainty_sum = 0.0;
    std::size_t compatible_neighbor_count = 0U;
    std::size_t anomalous_neighbor_count = 0U;

    for (const auto& neighbor : neighbors) {
        if (neighbor.phenomenon != current.phenomenon ||
            neighbor.unit != current.unit ||
            !finite_nonnegative(neighbor.uncertainty_value)) {
            continue;
        }

        const auto time_delta =
            current.observed_at_utc > neighbor.observed_at_utc
                ? current.observed_at_utc - neighbor.observed_at_utc
                : neighbor.observed_at_utc - current.observed_at_utc;

        if (time_delta > std::chrono::minutes(15)) {
            continue;
        }

        neighbor_sum += neighbor.value;
        neighbor_uncertainty_sum +=
            neighbor.uncertainty_value *
            neighbor.uncertainty_value;

        ++compatible_neighbor_count;
    }

    if (compatible_neighbor_count < policy_.minimum_neighbor_count) {
        return std::unexpected(CoreError::insufficient_neighbor_evidence);
    }

    const double neighbor_mean =
        neighbor_sum / static_cast<double>(compatible_neighbor_count);

    const double combined_standard_deviation =
        std::sqrt(
            std::max(
                current.uncertainty_value *
                    current.uncertainty_value +
                calibration.expected_standard_deviation *
                    calibration.expected_standard_deviation +
                neighbor_uncertainty_sum /
                    static_cast<double>(compatible_neighbor_count),
                kEpsilon));

    const double residual = current.value - neighbor_mean;
    const double standardized_score =
        residual / combined_standard_deviation;

    for (const auto& neighbor : neighbors) {
        if (neighbor.phenomenon != current.phenomenon ||
            neighbor.unit != current.unit ||
            !finite_nonnegative(neighbor.uncertainty_value)) {
            continue;
        }

        const double neighbor_score =
            (neighbor.value - neighbor_mean) /
            std::max(neighbor.uncertainty_value, kEpsilon);

        if (std::abs(neighbor_score) >= threshold) {
            ++anomalous_neighbor_count;
        }
    }

    const double spatial_corroboration =
        static_cast<double>(anomalous_neighbor_count) /
        static_cast<double>(compatible_neighbor_count);

    const bool current_anomalous =
        std::abs(standardized_score) >= threshold;

    const bool distributed_event_candidate =
        current_anomalous &&
        spatial_corroboration >=
            policy_.required_neighbor_anomaly_fraction;

    const bool correction_candidate =
        current_anomalous &&
        !distributed_event_candidate &&
        sensor_state != SensorState::recalibration_window;

    const double candidate_corrected_value =
        correction_candidate
            ? (current.value + neighbor_mean) / 2.0
            : current.value;

    const HumanReviewStatus review_status =
        current_anomalous
            ? HumanReviewStatus::hold_for_review
            : HumanReviewStatus::candidate_for_review;

    const std::string explanation =
        sensor_state == SensorState::recalibration_window
            ? "The sensor is in a recalibration or expired-calibration state. The observation remains preserved and is held for review; no environmental anomaly claim or correction is applied."
            : distributed_event_candidate
                ? "The sensor and a sufficient fraction of compatible time-aligned neighbors show anomalous evidence. The result is a distributed environmental-event candidate for review."
                : correction_candidate
                    ? "The sensor differs from compatible neighbors beyond the active uncertainty-aware threshold without sufficient spatial corroboration for a distributed event. A separate correction candidate is available for review while the raw value remains preserved."
                    : "The observation is consistent with the available calibrated, time-aligned neighboring evidence and active uncertainty threshold.";

    return DriftAssessment{
        .sensor_state = sensor_state,
        .residual = residual,
        .standardized_score = standardized_score,
        .spatial_corroboration_score = spatial_corroboration,
        .candidate_corrected_value = candidate_corrected_value,
        .raw_value_preserved = true,
        .correction_candidate_available = correction_candidate,
        .review_status = review_status,
        .plain_language_explanation = explanation
    };
}

SafetyViolation SafetyStack::evaluate_safety_contract(
    const ProposedAction& action,
    const PolicySnapshot& policy) const {

    if (action.action_id.empty() ||
        action.action_type.empty() ||
        action.exact_scope.empty() ||
        policy.policy_id.empty() ||
        policy.version.empty()) {
        return SafetyViolation{
            .violated = true,
            .required_mode = SafetyMode::degraded_hold_for_review,
            .reason = "missing_action_or_policy_information",
            .plain_language_explanation =
                "The proposed action cannot be evaluated because required action or policy information is missing. The system remains in a review state."
        };
    }

    if (action.requested_by_ml &&
        !action.ml_output_within_safe_envelope) {
        return SafetyViolation{
            .violated = true,
            .required_mode = SafetyMode::restricted,
            .reason = "machine_learning_output_outside_safe_envelope",
            .plain_language_explanation =
                "The machine-learning recommendation is outside its verified operating envelope. The recommendation is rejected from the action path and a verified fallback is required."
        };
    }

    if (!action.safety_evidence.design_time_property_verified ||
        !action.safety_evidence.compile_time_checks_passed ||
        !action.safety_evidence.runtime_watchdog_healthy ||
        !action.safety_evidence.independent_safety_sensors_healthy ||
        !action.safety_evidence.post_incident_audit_ready) {
        return SafetyViolation{
            .violated = true,
            .required_mode = SafetyMode::degraded_hold_for_review,
            .reason = "four_layer_safety_evidence_incomplete",
            .plain_language_explanation =
                "The proposed action does not satisfy all design-time, compile-time, runtime, and post-incident safety evidence requirements. Autonomous action is not permitted."
        };
    }

    return SafetyViolation{
        .violated = false,
        .required_mode = SafetyMode::normal,
        .reason = "safety_contract_satisfied",
        .plain_language_explanation =
            "The proposed action satisfies the available four-layer safety evidence. A separate exact-scope action approval is still required before an external action."
    };
}

std::expected<ActionAuthorizationResult, CoreError>
SafetyStack::authorize_external_action(
    const GovernedImpactShard& shard,
    const ActionApproval& approval,
    UtcTime now) const {

    if (shard.shard_id.empty() ||
        approval.approval_id.empty() ||
        approval.action_type.empty() ||
        approval.exact_scope.empty() ||
        approval.policy_version.empty() ||
        approval.appeal_or_correction_path.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    if (approval.expires_at < approval.valid_from) {
        return std::unexpected(CoreError::invalid_time_interval);
    }

    if (shard.external_action_status ==
            ExternalActionStatus::prohibited ||
        shard.external_action_status ==
            ExternalActionStatus::informational_only) {
        return ActionAuthorizationResult{
            .authorized = false,
            .status = ExternalActionStatus::prohibited,
            .review_status = HumanReviewStatus::hold_for_review,
            .plain_language_explanation =
                "This governed impact shard is evidence only and does not permit an external action."
        };
    }

    if (now < approval.valid_from ||
        now > approval.expires_at ||
        approval.policy_version != shard.policy_shard_id ||
        approval.human_signoff_roles.empty() ||
        approval.evidence_references.empty() ||
        !approval.accessibility_continuity_verified ||
        !approval.ecological_impact_reviewed ||
        !approval.safety_reviewed) {
        return ActionAuthorizationResult{
            .authorized = false,
            .status = ExternalActionStatus::requires_separate_approval,
            .review_status = HumanReviewStatus::hold_for_review,
            .plain_language_explanation =
                "The action approval is incomplete, expired, incompatible with the governed shard, or lacks required safety, ecological, accessibility, evidence, or human-signoff records."
        };
    }

    return ActionAuthorizationResult{
        .authorized = true,
        .status = ExternalActionStatus::approved_for_bounded_action,
        .review_status = HumanReviewStatus::reviewed,
        .plain_language_explanation =
            "The exact scoped action has a current, reviewable approval with required evidence, safety review, ecological review, accessibility continuity verification, human sign-offs, and an appeal or correction path."
    };
}

DigitalTwin::DigitalTwin(double maximum_consistency_error)
    : maximum_consistency_error_(maximum_consistency_error) {
}

std::expected<DigitalTwinUpdateResult, CoreError>
DigitalTwin::update_state(
    const TelemetryEnvelope& envelope,
    const ValidationKernelResult& validated) {

    if (envelope.artifact_id.empty() ||
        validated.metric_id.empty() ||
        envelope.unit.empty() ||
        validated.unit.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    if (!finite_nonnegative(envelope.uncertainty_value) ||
        !finite_nonnegative(validated.uncertainty_value) ||
        !finite_nonnegative(maximum_consistency_error_)) {
        return std::unexpected(CoreError::invalid_numeric_input);
    }

    if (envelope.unit != validated.unit) {
        return std::unexpected(CoreError::incompatible_unit);
    }

    if (validated.validation_status == ValidationStatus::rejected) {
        return std::unexpected(CoreError::missing_required_evidence);
    }

    if (!initialized_) {
        state_estimate_ = validated.value;
        state_uncertainty_ =
            std::max(validated.uncertainty_value, kEpsilon);
        consistency_metric_ = 0.0;
        initialized_ = true;
    } else {
        const double innovation = validated.value - state_estimate_;
        const double measurement_uncertainty =
            std::max(validated.uncertainty_value, kEpsilon);

        const double gain =
            state_uncertainty_ /
            (state_uncertainty_ + measurement_uncertainty);

        state_estimate_ += gain * innovation;
        state_uncertainty_ =
            std::max(
                (1.0 - gain) * state_uncertainty_ +
                    envelope.uncertainty_value,
                kEpsilon);

        consistency_metric_ = std::abs(innovation);
    }

    const bool synchronization_degraded =
        consistency_metric_ > maximum_consistency_error_ ||
        validated.validation_status ==
            ValidationStatus::review_required;

    return DigitalTwinUpdateResult{
        .twin_state_version = state_version_,
        .innovation_magnitude = consistency_metric_,
        .state_uncertainty = state_uncertainty_,
        .consistency_metric = consistency_metric_,
        .review_status = synchronization_degraded
            ? HumanReviewStatus::hold_for_review
            : HumanReviewStatus::candidate_for_review,
        .simulation_ready = !synchronization_degraded,
        .plain_language_explanation = synchronization_degraded
            ? "Digital-twin synchronization is degraded because the physical observation differs from the current state estimate beyond the configured boundary or requires validation review. Scenario outputs are held for review."
            : "The digital twin has incorporated validated evidence and remains within the configured consistency boundary for scenario analysis."
    };
}

double DigitalTwin::consistency_metric() const noexcept {
    return consistency_metric_;
}

std::expected<void, CoreError>
DigitalTwin::set_synchronization_frequency(
    std::chrono::milliseconds characteristic_time) {

    if (characteristic_time <= std::chrono::milliseconds::zero()) {
        return std::unexpected(CoreError::invalid_time_interval);
    }

    return {};
}

std::expected<ParetoPlanningResult, CoreError>
ParetoPlanner::generate_pareto_front(
    const std::vector<PlanningScenario>& candidates,
    const EpsilonValues& constraints) const {

    if (candidates.empty() ||
        constraints.governance_decision_id.empty() ||
        constraints.appeal_or_correction_path.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    if (!finite_unit_interval(constraints.maximum_social_inequity) ||
        !finite_nonnegative(constraints.maximum_total_cost) ||
        !finite_unit_interval(
            constraints.minimum_accessibility_benefit) ||
        !finite_unit_interval(constraints.maximum_harm_risk)) {
        return std::unexpected(CoreError::invalid_numeric_input);
    }

    std::unordered_set<std::string> identifiers;
    std::vector<PlanningScenario> feasible;

    for (const auto& scenario : candidates) {
        if (scenario.scenario_id.empty() ||
            !identifiers.insert(scenario.scenario_id).second ||
            !finite_unit_interval(scenario.ecological_benefit) ||
            !finite_unit_interval(scenario.social_inequity) ||
            !finite_unit_interval(scenario.accessibility_benefit) ||
            !finite_nonnegative(scenario.total_cost) ||
            !finite_nonnegative(scenario.maintenance_burden) ||
            !finite_nonnegative(scenario.water_or_energy_burden) ||
            !finite_unit_interval(scenario.harm_risk) ||
            !finite_unit_interval(scenario.uncertainty)) {
            return std::unexpected(CoreError::invalid_numeric_input);
        }

        if (scenario_is_feasible(scenario, constraints)) {
            feasible.push_back(scenario);
        }
    }

    if (feasible.empty()) {
        return std::unexpected(CoreError::infeasible_scenario);
    }

    std::vector<PlanningScenario> front;

    for (const auto& scenario : feasible) {
        bool dominated_by_other = false;

        for (const auto& comparison : feasible) {
            if (scenario.scenario_id == comparison.scenario_id) {
                continue;
            }

            if (dominates(comparison, scenario)) {
                dominated_by_other = true;
                break;
            }
        }

        if (!dominated_by_other) {
            front.push_back(scenario);
        }
    }

    return ParetoPlanningResult{
        .feasible_scenarios = std::move(feasible),
        .pareto_front = std::move(front),
        .accessible_review_description =
            "Every listed scenario satisfies non-discrimination, essential-access, equity, harm-risk, accessibility, and budget constraints. Stakeholders review remaining ecological, cost, maintenance, water/energy, uncertainty, and distributional tradeoffs through accessible scenario cards.",
        .stakeholder_review_required = true
    };
}

std::expected<PlanningScenario, CoreError>
ParetoPlanner::select_epsilon_scenario(
    const std::vector<PlanningScenario>& front,
    const EpsilonValues& epsilon_values) const {

    if (front.empty() ||
        epsilon_values.governance_decision_id.empty() ||
        epsilon_values.appeal_or_correction_path.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    PlanningScenario const* selected = nullptr;

    for (const auto& scenario : front) {
        if (!scenario_is_feasible(scenario, epsilon_values)) {
            continue;
        }

        if (selected == nullptr ||
            scenario.ecological_benefit >
                selected->ecological_benefit) {
            selected = &scenario;
        }
    }

    if (selected == nullptr) {
        return std::unexpected(CoreError::infeasible_scenario);
    }

    return *selected;
}

std::expected<bool, CoreError>
FairnessValidator::validate_invariance(
    const std::function<ServiceResult(const ServiceRequest&)>& function,
    const ServiceRequest& request) const {

    if (!function ||
        request.request_id.empty() ||
        request.service_scope.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    const ServiceResult baseline = function(request);
    const ServiceResult equivalent =
        function(stripped_identity_equivalent(request));

    const bool invariant =
        baseline.outcome == equivalent.outcome &&
        baseline.identity_verification_required ==
            equivalent.identity_verification_required &&
        baseline.human_review_required ==
            equivalent.human_review_required;

    return invariant;
}

std::expected<void, CoreError>
FairnessValidator::perform_proxy_audit(
    const std::vector<std::string>& feature_names) const {

    if (feature_names.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    static const std::unordered_set<std::string> prohibited_or_proxy_risks{
        "identity",
        "identity_status",
        "augmentation_status",
        "cybernetic_host_status",
        "biometric",
        "neural",
        "health",
        "diagnosis",
        "disability",
        "private_motivation",
        "purposeful_reason_to_exist",
        "device_fingerprint",
        "external_identity_verification",
        "precise_personal_location"
    };

    for (const auto& feature : feature_names) {
        if (feature.empty()) {
            return std::unexpected(CoreError::empty_required_field);
        }

        if (prohibited_or_proxy_risks.contains(feature)) {
            return std::unexpected(CoreError::identity_linked_input);
        }
    }

    return {};
}

std::expected<ServiceResult, CoreError>
IdentityAgnosticService::process_request(
    const ServiceRequest& request,
    const AccessibilityPreferenceProfile* optional_preferences) const {

    if (request.request_id.empty() ||
        request.service_scope.empty() ||
        request.decision_inputs.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    if (!request.accessible_default_path_available ||
        !request.accessible_review_path_available) {
        return std::unexpected(CoreError::missing_review_path);
    }

    for (const auto input : request.decision_inputs) {
        if (identity_linked_input(input)) {
            return ServiceResult{
                .outcome = ServiceOutcome::identity_linked_decision_denied,
                .identity_verification_required = false,
                .accommodation_applied = false,
                .human_review_required = true,
                .plain_language_explanation =
                    "The decision path is denied because it includes an identity-linked or otherwise prohibited input. The service must proceed through request, safety, capacity, infrastructure, approved-policy, and voluntary interaction-adaptation inputs only."
            };
        }
    }

    if (optional_preferences != nullptr) {
        if (optional_preferences->profile_id.empty()) {
            return std::unexpected(CoreError::empty_required_field);
        }

        return ServiceResult{
            .outcome = ServiceOutcome::voluntary_interface_adaptation,
            .identity_verification_required = false,
            .accommodation_applied = true,
            .human_review_required = false,
            .plain_language_explanation =
                "The service is available through an identity-agnostic path with voluntary interaction adaptation. Preferences may change presentation, input, pacing, export, or authentication alternatives only; they do not change eligibility, priority, evidence weight, credibility, or access rights."
        };
    }

    return ServiceResult{
        .outcome = ServiceOutcome::equal_default_access,
        .identity_verification_required = false,
        .accommodation_applied = false,
        .human_review_required = request.essential_service,
        .plain_language_explanation =
            "The service is available through an equal, identity-agnostic, accessible default path. Identity disclosure, external verification, private purpose, augmentation status, and optional telemetry are not required."
    };
}

std::expected<void, CoreError>
IdentityAgnosticService::record_outcome(
    std::string_view aggregate_outcome_id,
    double quality_score) const {

    if (aggregate_outcome_id.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    if (!finite_unit_interval(quality_score)) {
        return std::unexpected(CoreError::invalid_numeric_input);
    }

    return {};
}

AugmentedHubCore::AugmentedHubCore(
    PolicySnapshot policy,
    CoreConfiguration configuration)
    : policy_(std::move(policy)),
      configuration_(configuration),
      question_generator_(configuration.minimum_aggregate_count),
      drift_discriminator_(configuration.drift_policy),
      digital_twin_(configuration.maximum_digital_twin_consistency_error) {
}

std::expected<ValidationKernelResult, CoreError>
AugmentedHubCore::validate_telemetry(
    const TelemetryEnvelope& envelope,
    std::string_view metric_id,
    std::string_view formula_identifier) const {

    if (envelope.artifact_id.empty() ||
        envelope.schema_version.empty() ||
        envelope.phenomenon.empty() ||
        envelope.unit.empty() ||
        envelope.source_provenance.empty() ||
        envelope.purpose.empty() ||
        envelope.non_goals.empty() ||
        envelope.privacy_class.empty() ||
        envelope.policy_version.empty() ||
        envelope.provenance_hash.empty() ||
        metric_id.empty() ||
        formula_identifier.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    if (!finite_nonnegative(envelope.uncertainty_value)) {
        return std::unexpected(CoreError::invalid_numeric_input);
    }

    if (envelope.quality_status == QualityStatus::rejected) {
        return ValidationKernelResult{
            .metric_id = std::string(metric_id),
            .metric_version = "core-validation-v1",
            .value = envelope.value,
            .unit = envelope.unit,
            .uncertainty_value = envelope.uncertainty_value,
            .validation_status = ValidationStatus::rejected,
            .validation_explanation =
                "The telemetry envelope has rejected quality status and cannot be used as validated evidence.",
            .input_artifact_ids = {envelope.artifact_id},
            .input_hashes = {envelope.provenance_hash},
            .formula_identifier = std::string(formula_identifier),
            .human_review_status = HumanReviewStatus::hold_for_review,
            .policy_version = envelope.policy_version
        };
    }

    if (envelope.policy_version != policy_.version) {
        return std::unexpected(CoreError::invalid_policy_snapshot);
    }

    const ValidationStatus status =
        envelope.quality_status == QualityStatus::validated ||
        envelope.quality_status == QualityStatus::calibrated
            ? ValidationStatus::accepted
            : ValidationStatus::accepted_with_limitations;

    return ValidationKernelResult{
        .metric_id = std::string(metric_id),
        .metric_version = "core-validation-v1",
        .value = envelope.value,
        .unit = envelope.unit,
        .uncertainty_value = envelope.uncertainty_value,
        .validation_status = status,
        .validation_explanation =
            status == ValidationStatus::accepted
                ? "The telemetry envelope contains calibrated or validated environmental evidence with required provenance, purpose, privacy, uncertainty, and policy fields."
                : "The telemetry envelope is retained as usable evidence with limitations because its quality status is observed, measured, or estimated rather than calibrated or validated.",
        .input_artifact_ids = {envelope.artifact_id},
        .input_hashes = {envelope.provenance_hash},
        .formula_identifier = std::string(formula_identifier),
        .human_review_status =
            status == ValidationStatus::accepted
                ? HumanReviewStatus::candidate_for_review
                : HumanReviewStatus::hold_for_review,
        .policy_version = envelope.policy_version
    };
}

std::expected<DriftAssessment, CoreError>
AugmentedHubCore::assess_drift(
    const TelemetryEnvelope& current,
    const CalibrationRecord& calibration,
    const std::vector<TelemetryEnvelope>& neighbors) const {

    return drift_discriminator_.assess(
        current,
        calibration,
        neighbors);
}

std::expected<GovernedImpactShard, CoreError>
AugmentedHubCore::create_governed_impact_shard(
    const ValidationKernelResult& result,
    std::string_view environmental_asset_id,
    std::string_view shard_id,
    UtcTime issued_at_utc) const {

    if (result.metric_id.empty() ||
        result.metric_version.empty() ||
        result.unit.empty() ||
        result.validation_explanation.empty() ||
        result.input_artifact_ids.empty() ||
        result.input_hashes.empty() ||
        result.formula_identifier.empty() ||
        result.policy_version.empty() ||
        environmental_asset_id.empty() ||
        shard_id.empty()) {
        return std::unexpected(CoreError::empty_required_field);
    }

    if (!finite_nonnegative(result.uncertainty_value)) {
        return std::unexpected(CoreError::invalid_numeric_input);
    }

    if (result.validation_status == ValidationStatus::rejected) {
        return std::unexpected(CoreError::missing_required_evidence);
    }

    if (result.policy_version != policy_.version) {
        return std::unexpected(CoreError::invalid_policy_snapshot);
    }

    const bool fully_accepted =
        result.validation_status == ValidationStatus::accepted;

    return GovernedImpactShard{
        .shard_id = std::string(shard_id),
        .schema_version = "governed-impact-shard-v1",
        .issued_at_utc = issued_at_utc,
        .environmental_asset_id = std::string(environmental_asset_id),
        .telemetry_artifact_ids = result.input_artifact_ids,
        .validation_result_ids = {result.metric_id},
        .impact_metric_name = result.metric_id,
        .impact_metric_value = result.value,
        .impact_metric_unit = result.unit,
        .impact_uncertainty = result.uncertainty_value,
        .knowledge_factor = fully_accepted ? 0.90 : 0.70,
        .eco_impact_value = 0.50,
        .harm_risk = 0.10,
        .accessibility_impact = 0.90,
        .rights_alignment = 0.95,
        .human_review_status = fully_accepted
            ? HumanReviewStatus::candidate_for_review
            : HumanReviewStatus::hold_for_review,
        .accessibility_review_status =
            HumanReviewStatus::candidate_for_review,
        .community_review_status =
            HumanReviewStatus::candidate_for_review,
        .appeal_or_correction_path =
            "accessible-grievance-protocol",
        .external_action_status =
            ExternalActionStatus::requires_separate_approval,
        .policy_shard_id = result.policy_version,
        .provenance_hash =
            result.input_hashes.front()
    };
}

std::expected<
    AccessibilityQuestionGenerationResult,
    CoreError>
AugmentedHubCore::generate_assistance_panel_questions(
    const AssistancePanelQuestionContext& context) const {

    return question_generator_.generate_assistance_panel_questions(context);
}

std::expected<
    AccessibilityQuestionGenerationResult,
    CoreError>
AugmentedHubCore::generate_accessible_path_questions(
    const AccessiblePathQuestionContext& context) const {

    return question_generator_.generate_accessible_path_questions(context);
}

std::expected<DigitalTwinUpdateResult, CoreError>
AugmentedHubCore::update_digital_twin(
    const TelemetryEnvelope& envelope,
    const ValidationKernelResult& validated) {

    return digital_twin_.update_state(envelope, validated);
}

std::expected<ParetoPlanningResult, CoreError>
AugmentedHubCore::generate_pareto_front(
    const std::vector<PlanningScenario>& candidates,
    const EpsilonValues& constraints) const {

    return pareto_planner_.generate_pareto_front(
        candidates,
        constraints);
}

std::expected<PlanningScenario, CoreError>
AugmentedHubCore::select_epsilon_scenario(
    const std::vector<PlanningScenario>& front,
    const EpsilonValues& epsilon_values) const {

    return pareto_planner_.select_epsilon_scenario(
        front,
        epsilon_values);
}

std::expected<ServiceResult, CoreError>
AugmentedHubCore::process_identity_agnostic_service(
    const ServiceRequest& request,
    const AccessibilityPreferenceProfile* optional_preferences) const {

    return service_layer_.process_request(
        request,
        optional_preferences);
}

SafetyViolation AugmentedHubCore::evaluate_safety_contract(
    const ProposedAction& action) const {

    return safety_stack_.evaluate_safety_contract(action, policy_);
}

std::expected<ActionAuthorizationResult, CoreError>
AugmentedHubCore::evaluate_action_approval(
    const GovernedImpactShard& shard,
    const ActionApproval& approval,
    UtcTime now) const {

    return safety_stack_.authorize_external_action(
        shard,
        approval,
        now);
}

std::expected<bool, CoreError>
AugmentedHubCore::validate_service_invariance(
    const std::function<ServiceResult(const ServiceRequest&)>& function,
    const ServiceRequest& request) const {

    return fairness_validator_.validate_invariance(
        function,
        request);
}

const PolicySnapshot& AugmentedHubCore::policy() const noexcept {
    return policy_;
}

}  // namespace augmented_hub::core
