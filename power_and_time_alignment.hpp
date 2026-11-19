#ifndef AUGMENTED_HUB_POWER_AND_TIME_ALIGNMENT_HPP
#define AUGMENTED_HUB_POWER_AND_TIME_ALIGNMENT_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::power_time {

enum class EngineeringError {
    empty_input,
    invalid_numeric_input,
    invalid_temperature_range,
    invalid_timestamp_budget,
    insufficient_bus_power,
    unsupported_clock_domain
};

enum class EnergySourceKind {
    piezoelectric_ac,
    solar_dc,
    thermal_dc
};

enum class ClockTransport {
    ethernet_ptp,
    can_bus,
    lorawan,
    cellular_5g,
    local_oscillator
};

struct ConverterStage {
    std::string stage_id;
    double nominal_input_voltage_v{};
    double nominal_output_voltage_v{};
    double rated_output_power_w{};
    double conduction_loss_w{};
    double switching_loss_w{};
    double magnetic_loss_w{};
    double control_loss_w{};
    double temperature_celsius{};
    double temperature_derating_fraction{};
};

struct HarvestSource {
    std::string source_id;
    EnergySourceKind kind{};
    double available_input_power_w{};
    double source_stage_efficiency{};
    double mppt_efficiency{};
    double estimated_open_circuit_voltage_v{};
    bool mppt_enabled{};
};

struct PowerBusPolicy {
    double bus_voltage_v{24.0};
    double minimum_bus_power_w{};
    double minimum_overall_efficiency{0.92};
    double minimum_operating_temperature_celsius{-20.0};
    double maximum_operating_temperature_celsius{60.0};
    double maximum_switching_frequency_hz{500000.0};
    double minimum_switching_frequency_hz{20000.0};
};

struct PowerConversionResult {
    double usable_input_power_w{};
    double delivered_bus_power_w{};
    double weighted_conversion_efficiency{};
    double recommended_switching_frequency_hz{};
    double piezo_mpp_voltage_v{};
    bool bus_power_sufficient{};
    bool efficiency_target_satisfied{};
    std::string plain_language_explanation;
};

struct ClockObservation {
    std::string sensor_id;
    ClockTransport transport{};
    double local_timestamp_seconds{};
    double estimated_offset_seconds{};
    double estimated_drift_seconds_per_second{};
    double synchronization_uncertainty_seconds{};
    double sample_period_seconds{};
    bool hardware_timestamped{};
};

struct TimeAlignmentPolicy {
    double target_spatial_resolution_m{0.5};
    double propagation_speed_m_per_second{1500.0};
    double maximum_relative_timestamp_error_seconds{0.0002};
    double maximum_interpolation_gap_seconds{0.1};
};

struct TimeAlignmentAssessment {
    double theoretical_one_way_time_resolution_seconds{};
    double allocated_relative_timestamp_budget_seconds{};
    double maximum_observed_relative_error_seconds{};
    bool fusion_ready{};
    std::string recommended_alignment_method;
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<PowerConversionResult, EngineeringError>
evaluate_multi_input_power_bus(
    const std::vector<HarvestSource>& sources,
    const std::vector<ConverterStage>& stages,
    const PowerBusPolicy& policy);

[[nodiscard]] std::expected<TimeAlignmentAssessment, EngineeringError>
assess_sensor_time_alignment(
    const std::vector<ClockObservation>& observations,
    const TimeAlignmentPolicy& policy);

}  // namespace augmented_hub::power_time

#endif
