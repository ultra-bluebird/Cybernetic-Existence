#ifndef AUGMENTED_HUB_CONVERSION_AND_MULTIMODAL_ALIGNMENT_HPP
#define AUGMENTED_HUB_CONVERSION_AND_MULTIMODAL_ALIGNMENT_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::integration {

enum class IntegrationError {
    empty_input,
    invalid_numeric_input,
    duplicate_identifier,
    invalid_temperature_range,
    insufficient_alignment_evidence,
    incompatible_timestamp_window
};

enum class SourceType {
    solar_dc,
    piezoelectric_ac,
    thermal_dc,
    regenerative_braking_ac
};

enum class LoadVoltageClass {
    sensor_3v3,
    lighting_12v,
    actuator_24v,
    kiosk_48v
};

struct SourceConversionPath {
    std::string source_id;
    SourceType source_type{};
    double available_power_w{};
    double source_front_end_efficiency{};
    double mppt_or_extraction_efficiency{};
    double bus_stage_efficiency{};
    double nominal_input_voltage_v{};
    double switching_loss_coefficient{};
    double conduction_loss_coefficient{};
    double temperature_celsius{};
};

struct LoadConversionPath {
    std::string load_id;
    LoadVoltageClass voltage_class{};
    double demanded_power_w{};
    double load_stage_efficiency{};
    double switching_frequency_hz{};
    double estimated_thd_fraction{};
    bool essential_load{};
};

struct ConversionPolicy {
    double common_bus_voltage_v{24.0};
    double minimum_end_to_end_efficiency{0.90};
    double maximum_temperature_celsius{60.0};
    double minimum_temperature_celsius{-20.0};
    double maximum_thd_fraction{0.05};
    double minimum_switching_frequency_hz{20000.0};
    double maximum_switching_frequency_hz{500000.0};
};

struct ConversionArchitectureAssessment {
    double available_bus_power_w{};
    double delivered_load_power_w{};
    double weighted_source_efficiency{};
    double weighted_load_efficiency{};
    double estimated_end_to_end_efficiency{};
    bool essential_loads_supported{};
    bool efficiency_target_satisfied{};
    std::vector<double> recommended_switching_frequencies_hz;
    std::string plain_language_explanation;
};

struct TransformResidual {
    std::string sensor_pair_id;
    double timestamp_seconds{};
    double translation_residual_m{};
    double rotation_residual_degrees{};
    double vibration_rms_acceleration_m_per_s2{};
    double thermal_delta_celsius{};
    double static_feature_inlier_ratio{};
    bool calibration_target_or_static_scene_available{};
};

struct AlignmentMaintenancePolicy {
    double maximum_translation_residual_m{0.005};
    double maximum_rotation_residual_degrees{0.10};
    double maximum_vibration_rms_acceleration_m_per_s2{2.0};
    double maximum_thermal_delta_celsius{10.0};
    double minimum_static_feature_inlier_ratio{0.65};
    double maximum_recalibration_interval_seconds{900.0};
    std::size_t minimum_evidence_windows{3};
};

enum class AlignmentMaintenanceStatus {
    aligned,
    monitor_closely,
    recalibration_required,
    hold_for_review
};

struct AlignmentMaintenanceAssessment {
    double maximum_translation_residual_m{};
    double maximum_rotation_residual_degrees{};
    double maximum_vibration_rms_acceleration_m_per_s2{};
    double maximum_thermal_delta_celsius{};
    double minimum_static_feature_inlier_ratio{};
    bool time_triggered{};
    bool vibration_triggered{};
    bool performance_triggered{};
    AlignmentMaintenanceStatus status{
        AlignmentMaintenanceStatus::hold_for_review
    };
    std::string plain_language_explanation;
};

[[nodiscard]]
std::expected<ConversionArchitectureAssessment, IntegrationError>
assess_conversion_architecture(
    const std::vector<SourceConversionPath>& sources,
    const std::vector<LoadConversionPath>& loads,
    const ConversionPolicy& policy);

[[nodiscard]]
std::expected<AlignmentMaintenanceAssessment, IntegrationError>
assess_multimodal_alignment_maintenance(
    const std::vector<TransformResidual>& evidence_windows,
    double last_verified_calibration_seconds,
    double current_time_seconds,
    const AlignmentMaintenancePolicy& policy);

}  // namespace augmented_hub::integration

#endif
