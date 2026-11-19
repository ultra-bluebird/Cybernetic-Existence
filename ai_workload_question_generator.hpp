#ifndef AUGMENTED_HUB_AI_WORKLOAD_QUESTION_GENERATOR_HPP
#define AUGMENTED_HUB_AI_WORKLOAD_QUESTION_GENERATOR_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::ai_workloads {

enum class QuestionGenerationError {
    empty_required_field,
    invalid_numeric_input,
    invalid_quality_status,
    unsafe_task_context
};

enum class QualityStatus {
    observed,
    measured,
    calibrated,
    validated,
    estimated,
    rejected
};

enum class QuestionCategory {
    sensor_drift_discrimination,
    failure_mode_hypothesis,
    adjacent_sensor_cross_reference,
    safety_approach,
    energy_efficient_sequence,
    ecological_impact,
    pedestrian_disruption,
    accessibility_maintenance
};

struct SensorHealthContext {
    std::string sensor_id;
    std::string sensor_type;
    double current_reading{};
    double historical_mean{};
    double historical_standard_deviation{};
    std::string unit;
    QualityStatus quality_status{QualityStatus::observed};
    std::string last_calibration_utc;
    std::vector<std::string> known_failure_modes;
    std::vector<std::string> adjacent_sensor_ids;
    std::string evidence_provenance_reference;
};

struct MaintenanceTaskContext {
    std::string task_id;
    std::string task_description;
    std::string bot_state;
    std::vector<std::string> available_tools;
    std::vector<std::string> safety_constraints;
    std::vector<std::string> accessibility_requirements;
    std::vector<std::string> ecological_constraints;
    bool external_action_preapproved{false};
    std::string governed_impact_shard_reference;
};

struct GeneratedQuestion {
    QuestionCategory category{};
    std::string question;
    std::string required_evidence;
    std::string prohibited_assumptions;
    bool requires_human_review{};
};

struct QuestionGenerationResult {
    std::vector<GeneratedQuestion> questions;
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<QuestionGenerationResult, QuestionGenerationError>
generate_sensor_health_questions(
    const SensorHealthContext& context);

[[nodiscard]] std::expected<QuestionGenerationResult, QuestionGenerationError>
generate_maintenance_task_questions(
    const MaintenanceTaskContext& context);

}  // namespace augmented_hub::ai_workloads

#endif
