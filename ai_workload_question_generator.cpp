#include "ai_workload_question_generator.hpp"

#include <cmath>
#include <sstream>

namespace augmented_hub::ai_workloads {
namespace {

bool finite_value(double value) noexcept {
    return std::isfinite(value);
}

bool valid_quality_status(QualityStatus status) noexcept {
    switch (status) {
        case QualityStatus::observed:
        case QualityStatus::measured:
        case QualityStatus::calibrated:
        case QualityStatus::validated:
        case QualityStatus::estimated:
        case QualityStatus::rejected:
            return true;
    }

    return false;
}

std::string join(const std::vector<std::string>& values) {
    std::ostringstream stream;

    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index > 0U) {
            stream << ", ";
        }

        stream << values[index];
    }

    return stream.str();
}

std::string quality_status_name(QualityStatus status) {
    switch (status) {
        case QualityStatus::observed:
            return "observed";
        case QualityStatus::measured:
            return "measured";
        case QualityStatus::calibrated:
            return "calibrated";
        case QualityStatus::validated:
            return "validated";
        case QualityStatus::estimated:
            return "estimated";
        case QualityStatus::rejected:
            return "rejected";
    }

    return "unknown";
}

}  // namespace

std::expected<QuestionGenerationResult, QuestionGenerationError>
generate_sensor_health_questions(
    const SensorHealthContext& context) {

    if (context.sensor_id.empty() ||
        context.sensor_type.empty() ||
        context.unit.empty() ||
        context.last_calibration_utc.empty() ||
        context.evidence_provenance_reference.empty() ||
        context.known_failure_modes.empty() ||
        context.adjacent_sensor_ids.empty()) {
        return std::unexpected(
            QuestionGenerationError::empty_required_field);
    }

    if (!finite_value(context.current_reading) ||
        !finite_value(context.historical_mean) ||
        !finite_value(context.historical_standard_deviation) ||
        context.historical_standard_deviation < 0.0) {
        return std::unexpected(
            QuestionGenerationError::invalid_numeric_input);
    }

    if (!valid_quality_status(context.quality_status)) {
        return std::unexpected(
            QuestionGenerationError::invalid_quality_status);
    }

    const double z_score =
        context.historical_standard_deviation > 0.0
            ? (context.current_reading - context.historical_mean) /
                context.historical_standard_deviation
            : 0.0;

    const std::string failure_modes = join(context.known_failure_modes);
    const std::string adjacent_sensors = join(context.adjacent_sensor_ids);
    const std::string status = quality_status_name(context.quality_status);

    return QuestionGenerationResult{
        .questions = {
            GeneratedQuestion{
                .category = QuestionCategory::sensor_drift_discrimination,
                .question =
                    "For sensor " + context.sensor_id +
                    " (" + context.sensor_type + "), the current reading is " +
                    std::to_string(context.current_reading) + " " +
                    context.unit + " versus a historical mean of " +
                    std::to_string(context.historical_mean) + " " +
                    context.unit + " with a z-score of " +
                    std::to_string(z_score) +
                    ". What evidence from calibration history, time-series residuals, and adjacent sensors distinguishes probable sensor drift from a true environmental change?",
                .required_evidence =
                    "Use telemetry provenance " +
                    context.evidence_provenance_reference +
                    ", quality status " + status +
                    ", last calibration " +
                    context.last_calibration_utc +
                    ", uncertainty records, and time-aligned neighboring observations.",
                .prohibited_assumptions =
                    "Do not assume that an anomaly is an environmental event or a sensor failure without evidence. Do not use personal, identity, biometric, or assistive-device data.",
                .requires_human_review = true
            },
            GeneratedQuestion{
                .category = QuestionCategory::failure_mode_hypothesis,
                .question =
                    "Which known failure mode is best supported for sensor " +
                    context.sensor_id + " among: " + failure_modes +
                    "? Compare predicted signatures for each failure mode against the observed deviation, calibration age, environmental exposure, and sensor-health diagnostics.",
                .required_evidence =
                    "Use documented failure-mode signatures, calibration metadata, maintenance history, uncertainty estimates, and validated sensor-health indicators.",
                .prohibited_assumptions =
                    "Do not convert a failure hypothesis into an automated maintenance command. Preserve alternate hypotheses and uncertainty.",
                .requires_human_review = true
            },
            GeneratedQuestion{
                .category =
                    QuestionCategory::adjacent_sensor_cross_reference,
                .question =
                    "Which adjacent sensors should be cross-referenced with " +
                    context.sensor_id + " to test spatial and physical consistency, given the available neighboring sensor set: " +
                    adjacent_sensors +
                    "? What synchronization window, unit conversion, and expected parameter relationship should be applied for each comparison?",
                .required_evidence =
                    "Use sensor coordinates or approved spatial cells, modality relationships, timestamp uncertainty, calibration state, and approved data-sharing scope.",
                .prohibited_assumptions =
                    "Do not infer missing readings from unrelated personal data or treat a neighboring sensor as a ground-truth reference without stated calibration evidence.",
                .requires_human_review = false
            }
        },
        .plain_language_explanation =
            "The generated questions help an analyst or AI assistant investigate sensor health using stated telemetry evidence, calibration history, uncertainty, and neighboring observations. They do not authorize repairs or external actions."
    };
}

std::expected<QuestionGenerationResult, QuestionGenerationError>
generate_maintenance_task_questions(
    const MaintenanceTaskContext& context) {

    if (context.task_id.empty() ||
        context.task_description.empty() ||
        context.bot_state.empty() ||
        context.available_tools.empty() ||
        context.safety_constraints.empty() ||
        context.accessibility_requirements.empty() ||
        context.ecological_constraints.empty() ||
        context.governed_impact_shard_reference.empty()) {
        return std::unexpected(
            QuestionGenerationError::empty_required_field);
    }

    const std::string tools = join(context.available_tools);
    const std::string safety = join(context.safety_constraints);
    const std::string accessibility = join(context.accessibility_requirements);
    const std::string ecology = join(context.ecological_constraints);

    return QuestionGenerationResult{
        .questions = {
            GeneratedQuestion{
                .category = QuestionCategory::safety_approach,
                .question =
                    "For maintenance task " + context.task_id + ": " +
                    context.task_description +
                    ", what is the safest feasible approach given current bot state \"" +
                    context.bot_state + "\", available tools [" + tools +
                    "], and safety constraints [" + safety +
                    "]? Identify the required preconditions, exclusion zones, independent safety checks, and conditions requiring a human decision.",
                .required_evidence =
                    "Use the governed impact shard " +
                    context.governed_impact_shard_reference +
                    ", current weather, task-site sensor evidence, equipment status, and applicable safety rules.",
                .prohibited_assumptions =
                    "Do not assume authority to enter restricted areas, bypass safety interlocks, alter door safety behavior, or execute an irreversible action without separate approval.",
                .requires_human_review = true
            },
            GeneratedQuestion{
                .category = QuestionCategory::energy_efficient_sequence,
                .question =
                    "What sequence of inspection, travel, tooling, repair, verification, and return operations minimizes energy use for task " +
                    context.task_id +
                    " while retaining the required energy reserve and all safety constraints?",
                .required_evidence =
                    "Use bot battery state, route distance, tool energy consumption, charging availability, weather forecast, return-reserve policy, and task dependencies.",
                .prohibited_assumptions =
                    "Do not reduce safety margins, accessibility measures, or required verification steps solely to improve energy efficiency.",
                .requires_human_review = false
            },
            GeneratedQuestion{
                .category = QuestionCategory::ecological_impact,
                .question =
                    "What ecological effects could each feasible repair method for task " +
                    context.task_id +
                    " produce, considering material use, waste diversion, water or soil exposure, noise, energy demand, and expected service-life improvement?",
                .required_evidence =
                    "Use approved material records, environmental constraints [" +
                    ecology +
                    "], validated site conditions, and uncertainty statements.",
                .prohibited_assumptions =
                    "Do not claim an ecological benefit without a measurable mechanism, stated units, evidence provenance, and a reviewable calculation.",
                .requires_human_review = true
            },
            GeneratedQuestion{
                .category = QuestionCategory::pedestrian_disruption,
                .question =
                    "How can task " + context.task_id +
                    " be staged to minimize disruption to pedestrian flow while maintaining safety buffers, clear wayfinding, alternate routes, and emergency access?",
                .required_evidence =
                    "Use approved site layout, occupancy estimates at aggregate level, route accessibility requirements, and temporary-work-zone controls.",
                .prohibited_assumptions =
                    "Do not use facial recognition, gait analysis, identity inference, or individual tracking to manage pedestrian flow.",
                .requires_human_review = true
            },
            GeneratedQuestion{
                .category = QuestionCategory::accessibility_maintenance,
                .question =
                    "Which accessibility functions must remain continuously available during task " +
                    context.task_id +
                    ", based on the stated requirements [" +
                    accessibility +
                    "]? What accessible alternate route, interface, repair schedule, notification format, and contingency plan preserve equivalent access?",
                .required_evidence =
                    "Use accessible-design requirements, functional service dependencies, non-proprietary alternatives, and the stated review/appeal path.",
                .prohibited_assumptions =
                    "Do not require identity disclosure, medical documentation, proprietary devices, continuous connectivity, or unrelated telemetry to access a temporary accommodation.",
                .requires_human_review = true
            }
        },
        .plain_language_explanation =
            context.external_action_preapproved
                ? "The generated questions support an approved, bounded maintenance workflow. They remain evidence-bound and must preserve safety, accessible access, environmental limits, and review records."
                : "The generated questions support planning and review of a maintenance workflow. They do not authorize physical repair, dispatch, access to restricted space, or other external action."
    };
}

}  // namespace augmented_hub::ai_workloads
