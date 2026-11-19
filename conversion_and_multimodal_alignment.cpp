#include "conversion_and_multimodal_alignment.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <unordered_set>

namespace augmented_hub::integration {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

double source_efficiency(const SourceConversionPath& source) noexcept {
    return source.source_front_end_efficiency *
        source.mppt_or_extraction_efficiency *
        source.bus_stage_efficiency;
}

double recommend_switching_frequency(
    const SourceConversionPath& source,
    const ConversionPolicy& policy) noexcept {

    const double loss_total =
        source.switching_loss_coefficient +
        source.conduction_loss_coefficient;

    const double switching_fraction =
        loss_total > kEpsilon
            ? source.switching_loss_coefficient / loss_total
            : 0.5;

    const double temperature_fraction =
        std::clamp(
            (source.temperature_celsius -
             policy.minimum_temperature_celsius) /
            (policy.maximum_temperature_celsius -
             policy.minimum_temperature_celsius),
            0.0,
            1.0);

    const double normalized_frequency_preference =
        std::clamp(
            0.85 -
            0.50 * switching_fraction -
            0.25 * temperature_fraction,
            0.0,
            1.0);

    return policy.minimum_switching_frequency_hz +
        normalized_frequency_preference *
        (policy.maximum_switching_frequency_hz -
         policy.minimum_switching_frequency_hz);
}

bool valid_residual(const TransformResidual& residual) {
    return !residual.sensor_pair_id.empty() &&
        std::isfinite(residual.timestamp_seconds) &&
        finite_nonnegative(residual.translation_residual_m) &&
        finite_nonnegative(residual.rotation_residual_degrees) &&
        finite_nonnegative(
            residual.vibration_rms_acceleration_m_per_s2) &&
        finite_nonnegative(residual.thermal_delta_celsius) &&
        finite_unit_interval(residual.static_feature_inlier_ratio);
}

}  // namespace

std::expected<ConversionArchitectureAssessment, IntegrationError>
assess_conversion_architecture(
    const std::vector<SourceConversionPath>& sources,
    const std::vector<LoadConversionPath>& loads,
    const ConversionPolicy& policy) {

    if (sources.empty() || loads.empty()) {
        return std::unexpected(IntegrationError::empty_input);
    }

    if (!finite_nonnegative(policy.common_bus_voltage_v) ||
        policy.common_bus_voltage_v <= 0.0 ||
        !finite_unit_interval(policy.minimum_end_to_end_efficiency) ||
        !std::isfinite(policy.minimum_temperature_celsius) ||
        !std::isfinite(policy.maximum_temperature_celsius) ||
        policy.minimum_temperature_celsius >=
            policy.maximum_temperature_celsius ||
        !finite_unit_interval(policy.maximum_thd_fraction) ||
        !finite_nonnegative(policy.minimum_switching_frequency_hz) ||
        !finite_nonnegative(policy.maximum_switching_frequency_hz) ||
        policy.minimum_switching_frequency_hz <= 0.0 ||
        policy.minimum_switching_frequency_hz >
            policy.maximum_switching_frequency_hz) {
        return std::unexpected(IntegrationError::invalid_numeric_input);
    }

    std::unordered_set<std::string> identifiers;
    double available_bus_power_w = 0.0;
    double weighted_source_efficiency_numerator = 0.0;
    double source_power_total_w = 0.0;
    std::vector<double> recommended_frequencies;

    for (const auto& source : sources) {
        if (source.source_id.empty() ||
            !identifiers.insert(source.source_id).second ||
            !finite_nonnegative(source.available_power_w) ||
            !finite_unit_interval(source.source_front_end_efficiency) ||
            !finite_unit_interval(
                source.mppt_or_extraction_efficiency) ||
            !finite_unit_interval(source.bus_stage_efficiency) ||
            !finite_nonnegative(source.nominal_input_voltage_v) ||
            !finite_nonnegative(source.switching_loss_coefficient) ||
            !finite_nonnegative(source.conduction_loss_coefficient) ||
            !std::isfinite(source.temperature_celsius)) {
            return std::unexpected(IntegrationError::invalid_numeric_input);
        }

        if (source.temperature_celsius <
                policy.minimum_temperature_celsius ||
            source.temperature_celsius >
                policy.maximum_temperature_celsius) {
            return std::unexpected(IntegrationError::invalid_temperature_range);
        }

        const double efficiency = source_efficiency(source);
        const double delivered_power =
            source.available_power_w * efficiency;

        available_bus_power_w += delivered_power;
        weighted_source_efficiency_numerator +=
            source.available_power_w * efficiency;
        source_power_total_w += source.available_power_w;

        recommended_frequencies.push_back(
            recommend_switching_frequency(source, policy));
    }

    identifiers.clear();

    double total_demanded_power_w = 0.0;
    double delivered_load_power_w = 0.0;
    double weighted_load_efficiency_numerator = 0.0;
    bool essential_loads_supported = true;

    for (const auto& load : loads) {
        if (load.load_id.empty() ||
            !identifiers.insert(load.load_id).second ||
            !finite_nonnegative(load.demanded_power_w) ||
            !finite_unit_interval(load.load_stage_efficiency) ||
            !finite_nonnegative(load.switching_frequency_hz) ||
            !finite_unit_interval(load.estimated_thd_fraction)) {
            return std::unexpected(IntegrationError::invalid_numeric_input);
        }

        if (load.estimated_thd_fraction > policy.maximum_thd_fraction) {
            return std::unexpected(IntegrationError::invalid_numeric_input);
        }

        total_demanded_power_w += load.demanded_power_w;

        const double source_power_required =
            load.load_stage_efficiency > kEpsilon
                ? load.demanded_power_w / load.load_stage_efficiency
                : std::numeric_limits<double>::infinity();

        if (load.essential_load &&
            available_bus_power_w + kEpsilon < source_power_required) {
            essential_loads_supported = false;
        }

        delivered_load_power_w += load.demanded_power_w;
        weighted_load_efficiency_numerator +=
            load.demanded_power_w * load.load_stage_efficiency;
    }

    const double weighted_source_efficiency =
        source_power_total_w > kEpsilon
            ? weighted_source_efficiency_numerator / source_power_total_w
            : 0.0;

    const double weighted_load_efficiency =
        total_demanded_power_w > kEpsilon
            ? weighted_load_efficiency_numerator / total_demanded_power_w
            : 0.0;

    const double estimated_end_to_end_efficiency =
        weighted_source_efficiency * weighted_load_efficiency;

    return ConversionArchitectureAssessment{
        .available_bus_power_w = available_bus_power_w,
        .delivered_load_power_w = delivered_load_power_w,
        .weighted_source_efficiency = weighted_source_efficiency,
        .weighted_load_efficiency = weighted_load_efficiency,
        .estimated_end_to_end_efficiency =
            estimated_end_to_end_efficiency,
        .essential_loads_supported = essential_loads_supported,
        .efficiency_target_satisfied =
            estimated_end_to_end_efficiency + kEpsilon >=
            policy.minimum_end_to_end_efficiency,
        .recommended_switching_frequencies_hz =
            std::move(recommended_frequencies),
        .plain_language_explanation =
            "Each source is evaluated through its own rectification or extraction, MPPT or source-control stage, and common-bus stage. Each load receives a dedicated regulated conversion path. Frequency recommendations balance stated switching loss, conduction loss, and thermal exposure; bench validation remains required for efficiency, electromagnetic compatibility, and harmonic performance."
    };
}

std::expected<AlignmentMaintenanceAssessment, IntegrationError>
assess_multimodal_alignment_maintenance(
    const std::vector<TransformResidual>& evidence_windows,
    double last_verified_calibration_seconds,
    double current_time_seconds,
    const AlignmentMaintenancePolicy& policy) {

    if (evidence_windows.size() < policy.minimum_evidence_windows) {
        return std::unexpected(
            IntegrationError::insufficient_alignment_evidence);
    }

    if (!std::isfinite(last_verified_calibration_seconds) ||
        !std::isfinite(current_time_seconds) ||
        current_time_seconds < last_verified_calibration_seconds ||
        !finite_nonnegative(policy.maximum_translation_residual_m) ||
        !finite_nonnegative(policy.maximum_rotation_residual_degrees) ||
        !finite_nonnegative(
            policy.maximum_vibration_rms_acceleration_m_per_s2) ||
        !finite_nonnegative(policy.maximum_thermal_delta_celsius) ||
        !finite_unit_interval(policy.minimum_static_feature_inlier_ratio) ||
        !finite_nonnegative(
            policy.maximum_recalibration_interval_seconds) ||
        policy.minimum_evidence_windows == 0U) {
        return std::unexpected(IntegrationError::invalid_numeric_input);
    }

    std::unordered_set<std::string> sensor_pairs;
    double maximum_translation_residual_m = 0.0;
    double maximum_rotation_residual_degrees = 0.0;
    double maximum_vibration_rms_acceleration_m_per_s2 = 0.0;
    double maximum_thermal_delta_celsius = 0.0;
    double minimum_static_feature_inlier_ratio = 1.0;

    for (const auto& residual : evidence_windows) {
        if (!valid_residual(residual) ||
            !sensor_pairs.insert(residual.sensor_pair_id).second ||
            residual.timestamp_seconds > current_time_seconds) {
            return std::unexpected(IntegrationError::invalid_numeric_input);
        }

        maximum_translation_residual_m = std::max(
            maximum_translation_residual_m,
            residual.translation_residual_m);

        maximum_rotation_residual_degrees = std::max(
            maximum_rotation_residual_degrees,
            residual.rotation_residual_degrees);

        maximum_vibration_rms_acceleration_m_per_s2 = std::max(
            maximum_vibration_rms_acceleration_m_per_s2,
            residual.vibration_rms_acceleration_m_per_s2);

        maximum_thermal_delta_celsius = std::max(
            maximum_thermal_delta_celsius,
            residual.thermal_delta_celsius);

        minimum_static_feature_inlier_ratio = std::min(
            minimum_static_feature_inlier_ratio,
            residual.static_feature_inlier_ratio);
    }

    const bool time_triggered =
        current_time_seconds - last_verified_calibration_seconds >
        policy.maximum_recalibration_interval_seconds;

    const bool vibration_triggered =
        maximum_vibration_rms_acceleration_m_per_s2 >
            policy.maximum_vibration_rms_acceleration_m_per_s2 ||
        maximum_thermal_delta_celsius >
            policy.maximum_thermal_delta_celsius;

    const bool performance_triggered =
        maximum_translation_residual_m >
            policy.maximum_translation_residual_m ||
        maximum_rotation_residual_degrees >
            policy.maximum_rotation_residual_degrees ||
        minimum_static_feature_inlier_ratio <
            policy.minimum_static_feature_inlier_ratio;

    const bool recalibration_required =
        time_triggered ||
        vibration_triggered ||
        performance_triggered;

    const bool static_evidence_available =
        std::all_of(
            evidence_windows.begin(),
            evidence_windows.end(),
            [](const TransformResidual& residual) {
                return residual.calibration_target_or_static_scene_available;
            });

    const AlignmentMaintenanceStatus status =
        recalibration_required && static_evidence_available
            ? AlignmentMaintenanceStatus::recalibration_required
            : recalibration_required
                ? AlignmentMaintenanceStatus::hold_for_review
                : vibration_triggered || performance_triggered
                    ? AlignmentMaintenanceStatus::monitor_closely
                    : AlignmentMaintenanceStatus::aligned;

    return AlignmentMaintenanceAssessment{
        .maximum_translation_residual_m =
            maximum_translation_residual_m,
        .maximum_rotation_residual_degrees =
            maximum_rotation_residual_degrees,
        .maximum_vibration_rms_acceleration_m_per_s2 =
            maximum_vibration_rms_acceleration_m_per_s2,
        .maximum_thermal_delta_celsius =
            maximum_thermal_delta_celsius,
        .minimum_static_feature_inlier_ratio =
            minimum_static_feature_inlier_ratio,
        .time_triggered = time_triggered,
        .vibration_triggered = vibration_triggered,
        .performance_triggered = performance_triggered,
        .status = status,
        .plain_language_explanation =
            status == AlignmentMaintenanceStatus::recalibration_required
                ? "The alignment has exceeded a time, vibration/thermal, or performance trigger and has sufficient static-scene or calibration-target evidence for recalibration. The prior transform remains versioned and auditable."
                : status == AlignmentMaintenanceStatus::hold_for_review
                    ? "A recalibration trigger is active, but current evidence lacks sufficient static-scene or calibration-target support. The fusion pipeline remains in hold-for-review rather than applying an unverified transform update."
                    : status == AlignmentMaintenanceStatus::monitor_closely
                        ? "Alignment evidence is approaching or crossing a maintenance boundary. The system retains its current transform with elevated monitoring and a reviewable evidence record."
                        : "The current multi-modal alignment satisfies stated translation, rotation, vibration, thermal, and static-feature evidence boundaries."
    };
}

}  // namespace augmented_hub::integration
