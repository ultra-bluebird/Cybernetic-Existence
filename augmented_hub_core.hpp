#ifndef AUGMENTED_HUB_CORE_HPP
#define AUGMENTED_HUB_CORE_HPP

#include <chrono>
#include <cstddef>
#include <expected>
#include <functional>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace augmented_hub::core {

using UtcTime = std::chrono::sys_time<std::chrono::milliseconds>;

enum class CoreError {
    empty_required_field,
    invalid_numeric_input,
    invalid_time_interval,
    invalid_policy_snapshot,
    missing_required_evidence,
    missing_review_path,
    policy_denied,
    safety_boundary_denied,
    approval_denied,
    stale_digital_twin,
    stale_inference,
    incompatible_schema,
    incompatible_unit,
    identity_linked_input,
    insufficient_aggregation,
    insufficient_neighbor_evidence,
    infeasible_scenario,
    unsupported_action
};

enum class ExternalActionStatus {
    prohibited,
    informational_only,
    requires_separate_approval,
    approved_for_bounded_action
};

enum class HumanReviewStatus {
    not_required,
    candidate_for_review,
    hold_for_review,
    reviewed,
    approved_for_planning,
    superseded,
    appealed
};

enum class QualityStatus {
    observed,
    measured,
    calibrated,
    validated,
    estimated,
    rejected
};

enum class ValidationStatus {
    accepted,
    accepted_with_limitations,
    review_required,
    rejected
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

enum class SensorState {
    stable,
    recalibration_window,
    post_recalibration_stabilization,
    validated
};

enum class SafetyLayer {
    design_time,
    compile_time,
    runtime,
    post_incident
};

enum class SafetyMode {
    normal,
    restricted,
    safe_open,
    halted,
    degraded_hold_for_review
};

enum class ServiceInputClass {
    request_parameter,
    operational_safety,
    service_capacity,
    infrastructure_condition,
    approved_policy,
    voluntary_accessibility_preference,
    prohibited_identity_linked
};

enum class ServiceOutcome {
    equal_default_access,
    voluntary_interface_adaptation,
    identity_linked_decision_denied,
    hold_for_review
};

struct TimeInterval {
    UtcTime start{};
    UtcTime end{};
};

struct AggregateEvidenceReference {
    std::string dataset_id;
    TimeInterval measurement_window;
    std::string spatial_or_interface_precision;
    std::size_t aggregation_count{};
    bool non_identifying{true};
    bool uncertainty_disclosed{true};
    bool methodology_versioned{true};
};

struct TelemetryEnvelope {
    std::string artifact_id;
    std::string schema_version;
    UtcTime observed_at_utc{};
    std::string phenomenon;
    double value{};
    std::string unit;
    QualityStatus quality_status{QualityStatus::observed};
    double uncertainty_value{};
    std::string uncertainty_method;
    std::string source_provenance;
    std::string purpose;
    std::string non_goals;
    std::string privacy_class;
    HumanReviewStatus human_review_status{
        HumanReviewStatus::candidate_for_review
    };
    std::string plain_language_summary;
    std::string policy_version;
    std::string provenance_hash;
};

struct ValidationKernelResult {
    std::string metric_id;
    std::string metric_version;
    double value{};
    std::string unit;
    double uncertainty_value{};
    ValidationStatus validation_status{ValidationStatus::review_required};
    std::string validation_explanation;
    std::vector<std::string> input_artifact_ids;
    std::vector<std::string> input_hashes;
    std::string formula_identifier;
    HumanReviewStatus human_review_status{
        HumanReviewStatus::hold_for_review
    };
    std::string policy_version;
};

struct GovernedImpactShard {
    std::string shard_id;
    std::string schema_version;
    UtcTime issued_at_utc{};
    std::string environmental_asset_id;
    std::vector<std::string> telemetry_artifact_ids;
    std::vector<std::string> validation_result_ids;
    std::string impact_metric_name;
    double impact_metric_value{};
    std::string impact_metric_unit;
    double impact_uncertainty{};
    double knowledge_factor{};
    double eco_impact_value{};
    double harm_risk{};
    double accessibility_impact{};
    double rights_alignment{};
    HumanReviewStatus human_review_status{
        HumanReviewStatus::hold_for_review
    };
    HumanReviewStatus accessibility_review_status{
        HumanReviewStatus::candidate_for_review
    };
    HumanReviewStatus community_review_status{
        HumanReviewStatus::candidate_for_review
    };
    std::string appeal_or_correction_path;
    ExternalActionStatus external_action_status{
        ExternalActionStatus::requires_separate_approval
    };
    std::string policy_shard_id;
    std::string provenance_hash;
};

struct AccessibilityPreferenceProfile {
    std::string profile_id;
    std::vector<std::string> output_modalities;
    std::vector<std::string> input_modalities;
    bool slow_pacing{false};
    bool offline_sync{false};
    std::string preferred_export_format;
    std::string authentication_alternative;
};

struct PolicySnapshot {
    std::string policy_id;
    std::string version;
    std::vector<std::string> prohibited_uses;
    std::vector<std::string> required_fields;
    std::string retention_policy;
    std::string publication_precision;
};

struct CalibrationRecord {
    std::string sensor_artifact_id;
    UtcTime calibrated_at_utc{};
    UtcTime valid_until_utc{};
    double expected_standard_deviation{};
    bool calibration_accepted{};
    std::string calibration_reference;
};

struct DriftPolicy {
    double baseline_z_threshold{3.0};
    double recalibration_z_threshold{4.5};
    std::chrono::seconds stabilization_window{3600};
    std::size_t minimum_neighbor_count{2};
    double required_neighbor_anomaly_fraction{0.50};
};

struct DriftAssessment {
    SensorState sensor_state{SensorState::stable};
    double residual{};
    double standardized_score{};
    double spatial_corroboration_score{};
    double candidate_corrected_value{};
    bool raw_value_preserved{true};
    bool correction_candidate_available{};
    HumanReviewStatus review_status{
        HumanReviewStatus::hold_for_review
    };
    std::string plain_language_explanation;
};

struct GeneratedAccessibilityQuestion {
    AccessibilityQuestionCategory category{};
    std::string question;
    std::string required_evidence;
    std::string privacy_and_rights_boundary;
    bool requires_human_review{true};
};

struct AccessibilityQuestionGenerationResult {
    std::vector<GeneratedAccessibilityQuestion> questions;
    std::string plain_language_explanation;
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

struct SafetyEvidence {
    bool design_time_property_verified{false};
    bool compile_time_checks_passed{false};
    bool runtime_watchdog_healthy{false};
    bool independent_safety_sensors_healthy{false};
    bool post_incident_audit_ready{false};
};

struct ProposedAction {
    std::string action_id;
    std::string action_type;
    std::string exact_scope;
    bool affects_physical_infrastructure{false};
    bool is_irreversible{false};
    bool requested_by_ml{false};
    bool ml_output_within_safe_envelope{false};
    SafetyEvidence safety_evidence;
};

struct SafetyViolation {
    bool violated{true};
    SafetyMode required_mode{SafetyMode::degraded_hold_for_review};
    std::string reason;
    std::string plain_language_explanation;
};

struct ActionApproval {
    std::string approval_id;
    std::string action_type;
    std::string exact_scope;
    UtcTime valid_from{};
    UtcTime expires_at{};
    std::vector<std::string> evidence_references;
    std::vector<std::string> human_signoff_roles;
    std::string policy_version;
    std::string appeal_or_correction_path;
    bool accessibility_continuity_verified{false};
    bool ecological_impact_reviewed{false};
    bool safety_reviewed{false};
};

struct ActionAuthorizationResult {
    bool authorized{false};
    ExternalActionStatus status{
        ExternalActionStatus::requires_separate_approval
    };
    HumanReviewStatus review_status{
        HumanReviewStatus::hold_for_review
    };
    std::string plain_language_explanation;
};

struct DigitalTwinUpdateResult {
    std::string twin_state_version;
    double innovation_magnitude{};
    double state_uncertainty{};
    double consistency_metric{};
    HumanReviewStatus review_status{
        HumanReviewStatus::candidate_for_review
    };
    bool simulation_ready{false};
    std::string plain_language_explanation;
};

struct PlanningScenario {
    std::string scenario_id;
    double ecological_benefit{};
    double social_inequity{};
    double accessibility_benefit{};
    double total_cost{};
    double maintenance_burden{};
    double water_or_energy_burden{};
    double harm_risk{};
    double uncertainty{};
    bool preserves_essential_access{false};
    bool satisfies_non_discrimination_invariant{false};
    HumanReviewStatus review_status{
        HumanReviewStatus::candidate_for_review
    };
    std::string plain_language_summary;
};

struct EpsilonValues {
    double maximum_social_inequity{};
    double maximum_total_cost{};
    double minimum_accessibility_benefit{};
    double maximum_harm_risk{};
    std::string governance_decision_id;
    std::string appeal_or_correction_path;
};

struct ParetoPlanningResult {
    std::vector<PlanningScenario> feasible_scenarios;
    std::vector<PlanningScenario> pareto_front;
    std::string accessible_review_description;
    bool stakeholder_review_required{true};
};

struct ServiceRequest {
    std::string request_id;
    std::string service_scope;
    bool essential_service{false};
    bool accessible_default_path_available{true};
    bool accessible_review_path_available{true};
    std::vector<ServiceInputClass> decision_inputs;
};

struct ServiceResult {
    ServiceOutcome outcome{ServiceOutcome::hold_for_review};
    bool identity_verification_required{false};
    bool accommodation_applied{false};
    bool human_review_required{true};
    std::string plain_language_explanation;
};

struct CoreConfiguration {
    DriftPolicy drift_policy;
    double maximum_digital_twin_consistency_error{0.25};
    std::size_t minimum_aggregate_count{20};
    bool require_accessibility_review_for_actions{true};
};

class AccessibilityQuestionGenerator final {
public:
    explicit AccessibilityQuestionGenerator(
        std::size_t minimum_aggregate_count);

    [[nodiscard]]
    std::expected<AccessibilityQuestionGenerationResult, CoreError>
    generate_assistance_panel_questions(
        const AssistancePanelQuestionContext& context) const;

    [[nodiscard]]
    std::expected<AccessibilityQuestionGenerationResult, CoreError>
    generate_accessible_path_questions(
        const AccessiblePathQuestionContext& context) const;

private:
    std::size_t minimum_aggregate_count_;
};

class DriftDiscriminator final {
public:
    explicit DriftDiscriminator(DriftPolicy policy);

    [[nodiscard]]
    std::expected<DriftAssessment, CoreError>
    assess(
        const TelemetryEnvelope& current,
        const CalibrationRecord& calibration,
        const std::vector<TelemetryEnvelope>& neighbors) const;

private:
    DriftPolicy policy_;
};

class SafetyStack final {
public:
    [[nodiscard]]
    SafetyViolation evaluate_safety_contract(
        const ProposedAction& action,
        const PolicySnapshot& policy) const;

    [[nodiscard]]
    std::expected<ActionAuthorizationResult, CoreError>
    authorize_external_action(
        const GovernedImpactShard& shard,
        const ActionApproval& approval,
        UtcTime now) const;
};

class DigitalTwin final {
public:
    explicit DigitalTwin(double maximum_consistency_error);

    [[nodiscard]]
    std::expected<DigitalTwinUpdateResult, CoreError>
    update_state(
        const TelemetryEnvelope& envelope,
        const ValidationKernelResult& validated);

    [[nodiscard]]
    double consistency_metric() const noexcept;

    [[nodiscard]]
    std::expected<void, CoreError>
    set_synchronization_frequency(
        std::chrono::milliseconds characteristic_time);

private:
    double maximum_consistency_error_;
    double state_estimate_{};
    double state_uncertainty_{1.0};
    double consistency_metric_{};
    std::string state_version_{"twin-v1"};
    bool initialized_{false};
};

class ParetoPlanner final {
public:
    [[nodiscard]]
    std::expected<ParetoPlanningResult, CoreError>
    generate_pareto_front(
        const std::vector<PlanningScenario>& candidates,
        const EpsilonValues& constraints) const;

    [[nodiscard]]
    std::expected<PlanningScenario, CoreError>
    select_epsilon_scenario(
        const std::vector<PlanningScenario>& front,
        const EpsilonValues& epsilon_values) const;
};

class FairnessValidator final {
public:
    [[nodiscard]]
    std::expected<bool, CoreError>
    validate_invariance(
        const std::function<ServiceResult(const ServiceRequest&)>& function,
        const ServiceRequest& request) const;

    [[nodiscard]]
    std::expected<void, CoreError>
    perform_proxy_audit(
        const std::vector<std::string>& feature_names) const;
};

class IdentityAgnosticService final {
public:
    [[nodiscard]]
    std::expected<ServiceResult, CoreError>
    process_request(
        const ServiceRequest& request,
        const AccessibilityPreferenceProfile* optional_preferences) const;

    [[nodiscard]]
    std::expected<void, CoreError>
    record_outcome(
        std::string_view aggregate_outcome_id,
        double quality_score) const;
};

class AugmentedHubCore final {
public:
    AugmentedHubCore(
        PolicySnapshot policy,
        CoreConfiguration configuration);

    [[nodiscard]]
    std::expected<ValidationKernelResult, CoreError>
    validate_telemetry(
        const TelemetryEnvelope& envelope,
        std::string_view metric_id,
        std::string_view formula_identifier) const;

    [[nodiscard]]
    std::expected<DriftAssessment, CoreError>
    assess_drift(
        const TelemetryEnvelope& current,
        const CalibrationRecord& calibration,
        const std::vector<TelemetryEnvelope>& neighbors) const;

    [[nodiscard]]
    std::expected<GovernedImpactShard, CoreError>
    create_governed_impact_shard(
        const ValidationKernelResult& result,
        std::string_view environmental_asset_id,
        std::string_view shard_id,
        UtcTime issued_at_utc) const;

    [[nodiscard]]
    std::expected<AccessibilityQuestionGenerationResult, CoreError>
    generate_assistance_panel_questions(
        const AssistancePanelQuestionContext& context) const;

    [[nodiscard]]
    std::expected<AccessibilityQuestionGenerationResult, CoreError>
    generate_accessible_path_questions(
        const AccessiblePathQuestionContext& context) const;

    [[nodiscard]]
    std::expected<DigitalTwinUpdateResult, CoreError>
    update_digital_twin(
        const TelemetryEnvelope& envelope,
        const ValidationKernelResult& validated);

    [[nodiscard]]
    std::expected<ParetoPlanningResult, CoreError>
    generate_pareto_front(
        const std::vector<PlanningScenario>& candidates,
        const EpsilonValues& constraints) const;

    [[nodiscard]]
    std::expected<PlanningScenario, CoreError>
    select_epsilon_scenario(
        const std::vector<PlanningScenario>& front,
        const EpsilonValues& epsilon_values) const;

    [[nodiscard]]
    std::expected<ServiceResult, CoreError>
    process_identity_agnostic_service(
        const ServiceRequest& request,
        const AccessibilityPreferenceProfile* optional_preferences) const;

    [[nodiscard]]
    SafetyViolation evaluate_safety_contract(
        const ProposedAction& action) const;

    [[nodiscard]]
    std::expected<ActionAuthorizationResult, CoreError>
    evaluate_action_approval(
        const GovernedImpactShard& shard,
        const ActionApproval& approval,
        UtcTime now) const;

    [[nodiscard]]
    std::expected<bool, CoreError>
    validate_service_invariance(
        const std::function<ServiceResult(const ServiceRequest&)>& function,
        const ServiceRequest& request) const;

    [[nodiscard]]
    const PolicySnapshot& policy() const noexcept;

private:
    PolicySnapshot policy_;
    CoreConfiguration configuration_;
    AccessibilityQuestionGenerator question_generator_;
    DriftDiscriminator drift_discriminator_;
    SafetyStack safety_stack_;
    DigitalTwin digital_twin_;
    ParetoPlanner pareto_planner_;
    FairnessValidator fairness_validator_;
    IdentityAgnosticService service_layer_;
};

}  // namespace augmented_hub::core

#endif
