#ifndef AUGMENTED_HUB_CIVIC_EDGE_INTERACTION_HPP
#define AUGMENTED_HUB_CIVIC_EDGE_INTERACTION_HPP

#include <cstddef>
#include <cstdint>
#include <expected>
#include <span>
#include <string>
#include <vector>

namespace augmented_hub::civic_edge {

enum class DoorGesture {
    open,
    close,
    hold,
    emergency_stop,
    assist_mode,
    slow_open,
    slow_close,
    partial_open,
    full_open,
    reset,
    maintenance_mode,
    wave
};

enum class GestureError {
    empty_point_cloud,
    raw_data_retention_exceeded,
    invalid_confidence,
    unsafe_command,
    ambiguous_gesture
};

enum class DoorCommand {
    none,
    open,
    close,
    hold_open,
    emergency_stop,
    assist_mode,
    slow_open,
    slow_close,
    partial_open,
    full_open,
    reset,
    maintenance_mode
};

struct Point3d {
    float x{};
    float y{};
    float z{};
};

struct GesturePolicy {
    double minimum_confidence{0.995};
    std::int64_t maximum_raw_retention_milliseconds{500};
    std::int64_t assist_latency_budget_milliseconds{25};
    std::int64_t general_latency_budget_milliseconds{50};
};

struct GestureInference {
    DoorGesture gesture{DoorGesture::wave};
    double confidence{};
    std::int64_t inference_latency_milliseconds{};
    std::int64_t raw_data_age_milliseconds{};
    bool on_device_processed{true};
    bool raw_point_cloud_persisted{false};
};

struct GestureDecision {
    DoorCommand command{DoorCommand::none};
    bool requires_safety_interlock{};
    bool requires_human_review{};
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<GestureDecision, GestureError> decide_door_command(
    const GestureInference& inference,
    const GesturePolicy& policy);

enum class LeakEvidenceStatus {
    accepted_with_limitations,
    hold_for_review,
    rejected
};

enum class LeakError {
    insufficient_samples,
    mismatched_signal_lengths,
    invalid_sampling_rate,
    invalid_sensor_geometry,
    invalid_wave_speed,
    invalid_threshold
};

struct AcousticSensorPosition {
    double longitudinal_pipe_distance_m{};
};

struct LeakDetectionPolicy {
    double sampling_rate_hz{4096.0};
    double wave_speed_m_per_second{1200.0};
    double minimum_coherence{0.65};
    double minimum_snr{3.0};
    double maximum_traffic_band_energy_ratio{0.50};
};

struct LeakLocationEstimate {
    double time_delay_seconds{};
    double estimated_distance_from_sensor_one_m{};
    double normalized_cross_correlation{};
    double coherence_proxy{};
    double enhanced_snr{};
    double traffic_band_energy_ratio{};
    bool leak_candidate{};
    LeakEvidenceStatus evidence_status{LeakEvidenceStatus::hold_for_review};
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<LeakLocationEstimate, LeakError>
estimate_leak_location(
    std::span<const double> sensor_one_signal,
    std::span<const double> sensor_two_signal,
    AcousticSensorPosition sensor_one,
    AcousticSensorPosition sensor_two,
    const LeakDetectionPolicy& policy);

}  // namespace augmented_hub::civic_edge

#endif
