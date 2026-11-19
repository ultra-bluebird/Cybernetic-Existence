#include "power_and_time_alignment.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <unordered_set>

namespace augmented_hub::power_time {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

double stage_efficiency(const ConverterStage& stage) noexcept {
    const double total_loss_w =
        stage.conduction_loss_w +
        stage.switching_loss_w +
        stage.magnetic_loss_w +
        stage.control_loss_w;

    const double pre_derating_output_w =
        std::max(stage.rated_output_power_w - total_loss_w, 0.0);

    const double derated_output_w =
        pre_derating_output_w *
        (1.0 - stage.temperature_derating_fraction);

    return stage.rated_output_power_w > kEpsilon
        ? std::clamp(
            derated_output_w / stage.rated_output_power_w,
            0.0,
            1.0)
        : 0.0;
}

double recommended_switching_frequency_hz(
    const ConverterStage& stage,
    const PowerBusPolicy& policy) noexcept {

    const double total_loss_w =
        stage.conduction_loss_w +
        stage.switching_loss_w +
        stage.magnetic_loss_w +
        stage.control_loss_w;

    const double switching_loss_fraction =
        total_loss_w > kEpsilon
            ? stage.switching_loss_w / total_loss_w
            : 0.0;

    const double thermal_penalty =
        std::clamp(
            (stage.temperature_celsius -
             policy.minimum_operating_temperature_celsius) /
            (policy.maximum_operating_temperature_celsius -
             policy.minimum_operating_temperature_celsius),
            0.0,
            1.0);

    const double preference =
        std::clamp(
            0.75 -
            0.45 * switching_loss_fraction -
            0.25 * thermal_penalty,
            0.0,
            1.0);

    return policy.minimum_switching_frequency_hz +
        preference *
        (policy.maximum_switching_frequency_hz -
         policy.minimum_switching_frequency_hz);
}

bool transport_supports_sub_millisecond_sync(
    ClockTransport transport,
    bool hardware_timestamped) noexcept {

    return (transport == ClockTransport::ethernet_ptp &&
            hardware_timestamped) ||
        transport == ClockTransport::can_bus;
}

}  // namespace

std::expected<PowerConversionResult, EngineeringError>
evaluate_multi_input_power_bus(
    const std::vector<HarvestSource>& sources,
    const std::vector<ConverterStage>& stages,
    const PowerBusPolicy& policy) {

    if (sources.empty() || stages.empty()) {
        return std::unexpected(EngineeringError::empty_input);
    }

    if (!finite_nonnegative(policy.bus_voltage_v) ||
        policy.bus_voltage_v <= 0.0 ||
        !finite_nonnegative(policy.minimum_bus_power_w) ||
        !finite_unit_interval(policy.minimum_overall_efficiency) ||
        !std::isfinite(policy.minimum_operating_temperature_celsius) ||
        !std::isfinite(policy.maximum_operating_temperature_celsius) ||
        policy.minimum_operating_temperature_celsius >=
            policy.maximum_operating_temperature_celsius ||
        !finite_nonnegative(policy.minimum_switching_frequency_hz) ||
        !finite_nonnegative(policy.maximum_switching_frequency_hz) ||
        policy.minimum_switching_frequency_hz <= 0.0 ||
        policy.minimum_switching_frequency_hz >
            policy.maximum_switching_frequency_hz) {
        return std::unexpected(EngineeringError::invalid_numeric_input);
    }

    std::unordered_set<std::string> source_identifiers;
    double source_usable_power_w = 0.0;
    double piezo_mpp_voltage_v = 0.0;

    for (const auto& source : sources) {
        if (source.source_id.empty() ||
            !source_identifiers.insert(source.source_id).second ||
            !finite_nonnegative(source.available_input_power_w) ||
            !finite_unit_interval(source.source_stage_efficiency) ||
            !finite_unit_interval(source.mppt_efficiency) ||
            !finite_nonnegative(source.estimated_open_circuit_voltage_v)) {
            return std::unexpected(EngineeringError::invalid_numeric_input);
        }

        const double source_power =
            source.available_input_power_w *
            source.source_stage_efficiency *
            (source.mppt_enabled ? source.mppt_efficiency : 1.0);

        source_usable_power_w += source_power;

        if (source.kind == EnergySourceKind::piezoelectric_ac) {
            piezo_mpp_voltage_v =
                std::max(
                    piezo_mpp_voltage_v,
                    source.estimated_open_circuit_voltage_v / 2.0);
        }
    }

    std::unordered_set<std::string> stage_identifiers;
    double converter_efficiency = 1.0;
    double frequency_sum_hz = 0.0;

    for (const auto& stage : stages) {
        if (stage.stage_id.empty() ||
            !stage_identifiers.insert(stage.stage_id).second ||
            !finite_nonnegative(stage.nominal_input_voltage_v) ||
            !finite_nonnegative(stage.nominal_output_voltage_v) ||
            !finite_nonnegative(stage.rated_output_power_w) ||
            !finite_nonnegative(stage.conduction_loss_w) ||
            !finite_nonnegative(stage.switching_loss_w) ||
            !finite_nonnegative(stage.magnetic_loss_w) ||
            !finite_nonnegative(stage.control_loss_w) ||
            !std::isfinite(stage.temperature_celsius) ||
            !finite_unit_interval(stage.temperature_derating_fraction)) {
            return std::unexpected(EngineeringError::invalid_numeric_input);
        }

        if (stage.temperature_celsius <
                policy.minimum_operating_temperature_celsius ||
            stage.temperature_celsius >
                policy.maximum_operating_temperature_celsius) {
            return std::unexpected(EngineeringError::invalid_temperature_range);
        }

        converter_efficiency *= stage_efficiency(stage);
        frequency_sum_hz += recommended_switching_frequency_hz(stage, policy);
    }

    const double delivered_bus_power_w =
        source_usable_power_w * converter_efficiency;

    const double recommended_frequency_hz =
        frequency_sum_hz / static_cast<double>(stages.size());

    return PowerConversionResult{
        .usable_input_power_w = source_usable_power_w,
        .delivered_bus_power_w = delivered_bus_power_w,
        .weighted_conversion_efficiency = converter_efficiency,
        .recommended_switching_frequency_hz = recommended_frequency_hz,
        .piezo_mpp_voltage_v = piezo_mpp_voltage_v,
        .bus_power_sufficient =
            delivered_bus_power_w + kEpsilon >= policy.minimum_bus_power_w,
        .efficiency_target_satisfied =
            converter_efficiency + kEpsilon >=
            policy.minimum_overall_efficiency,
        .plain_language_explanation =
            "The assessment combines source-stage efficiency, MPPT efficiency, converter losses, temperature derating, and the 24 V bus demand. Switching frequency is selected from the stated loss and thermal model; component-level validation remains required before field deployment."
    };
}

std::expected<TimeAlignmentAssessment, EngineeringError>
assess_sensor_time_alignment(
    const std::vector<ClockObservation>& observations,
    const TimeAlignmentPolicy& policy) {

    if (observations.size() < 2U) {
        return std::unexpected(EngineeringError::empty_input);
    }

    if (!finite_nonnegative(policy.target_spatial_resolution_m) ||
        policy.target_spatial_resolution_m <= 0.0 ||
        !finite_nonnegative(policy.propagation_speed_m_per_second) ||
        policy.propagation_speed_m_per_second <= 0.0 ||
        !finite_nonnegative(policy.maximum_relative_timestamp_error_seconds) ||
        policy.maximum_relative_timestamp_error_seconds <= 0.0 ||
        !finite_nonnegative(policy.maximum_interpolation_gap_seconds) ||
        policy.maximum_interpolation_gap_seconds <= 0.0) {
        return std::unexpected(EngineeringError::invalid_timestamp_budget);
    }

    std::unordered_set<std::string> sensor_identifiers;
    double maximum_relative_error_seconds = 0.0;
    bool all_high_precision_capable = true;
    bool requires_resampling = false;

    for (const auto& observation : observations) {
        if (observation.sensor_id.empty() ||
            !sensor_identifiers.insert(observation.sensor_id).second ||
            !std::isfinite(observation.local_timestamp_seconds) ||
            !std::isfinite(observation.estimated_offset_seconds) ||
            !std::isfinite(observation.estimated_drift_seconds_per_second) ||
            !finite_nonnegative(observation.synchronization_uncertainty_seconds) ||
            !finite_nonnegative(observation.sample_period_seconds) ||
            observation.sample_period_seconds <= 0.0) {
            return std::unexpected(EngineeringError::invalid_numeric_input);
        }

        maximum_relative_error_seconds = std::max(
            maximum_relative_error_seconds,
            observation.synchronization_uncertainty_seconds);

        all_high_precision_capable =
            all_high_precision_capable &&
            transport_supports_sub_millisecond_sync(
                observation.transport,
                observation.hardware_timestamped);

        requires_resampling =
            requires_resampling ||
            observation.sample_period_seconds >
                policy.maximum_interpolation_gap_seconds;
    }

    const double one_way_time_resolution_seconds =
        policy.target_spatial_resolution_m /
        policy.propagation_speed_m_per_second;

    const bool fusion_ready =
        maximum_relative_error_seconds <=
            policy.maximum_relative_timestamp_error_seconds &&
        all_high_precision_capable;

    return TimeAlignmentAssessment{
        .theoretical_one_way_time_resolution_seconds =
            one_way_time_resolution_seconds,
        .allocated_relative_timestamp_budget_seconds =
            policy.maximum_relative_timestamp_error_seconds,
        .maximum_observed_relative_error_seconds =
            maximum_relative_error_seconds,
        .fusion_ready = fusion_ready,
        .recommended_alignment_method =
            requires_resampling
                ? "hardware-timestamped PTP reference clock with rate-aware resampling, uncertainty-bounded interpolation, and correlation-window alignment"
                : "hardware-timestamped PTP reference clock with direct correlation-window alignment",
        .plain_language_explanation =
            fusion_ready
                ? "The observed synchronization uncertainty satisfies the configured relative-time budget for acoustic and pressure-sensor correlation. Each fusion result should retain its clock offset, drift estimate, timestamp uncertainty, and resampling method."
                : "The current timing evidence does not satisfy the configured relative-time budget or lacks an adequate high-precision clock transport. The result remains unsuitable for high-resolution acoustic-pressure correlation until the clock path is improved or the spatial target is relaxed."
    };
}

}  // namespace augmented_hub::power_time
