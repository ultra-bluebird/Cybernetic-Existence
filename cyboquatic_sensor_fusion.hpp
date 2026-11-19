#ifndef AUGMENTED_HUB_CYBOQUATIC_SENSOR_FUSION_HPP
#define AUGMENTED_HUB_CYBOQUATIC_SENSOR_FUSION_HPP

#include <cstddef>
#include <expected>
#include <span>
#include <string>

namespace augmented_hub::sensor_fusion {

enum class SensorModality {
    water_quality,
    air_quality,
    thermal_infrared,
    acoustic
};

enum class EvidenceStatus {
    accepted,
    accepted_with_limitations,
    hold_for_review,
    rejected
};

enum class FusionError {
    empty_window,
    invalid_timestamp,
    outside_temporal_window,
    invalid_measurement,
    invalid_probability,
    invalid_filter_parameter,
    non_monotonic_time
};

struct TimedMeasurement {
    SensorModality modality{};
    double observed_at_seconds{};
    double anomaly_likelihood{};
    double measurement_uncertainty{};
    bool calibration_current{};
};

struct FusionPolicy {
    double event_prior{0.01};
    double detection_threshold{0.80};
    double temporal_window_seconds{15.0 * 60.0};
    std::size_t minimum_modalities{2};
};

struct FusionResult {
    double posterior_event_probability{};
    std::size_t aligned_modalities{};
    EvidenceStatus evidence_status{EvidenceStatus::hold_for_review};
    std::string plain_language_explanation;
};

struct DriftState {
    double estimated_true_value{};
    double estimated_drift{};
    double true_value_variance{};
    double drift_variance{};
    double covariance{};
    double last_update_seconds{};
    bool initialized{};
};

struct DriftPolicy {
    double mean_reversion_rate_per_second{};
    double long_run_drift{};
    double process_noise_true_value{};
    double process_noise_drift{};
    double minimum_measurement_variance{1e-12};
    double review_drift_ratio{0.005};
};

struct DriftUpdate {
    DriftState state;
    double innovation{};
    double innovation_variance{};
    double normalized_innovation_squared{};
    bool probable_environmental_change{};
    bool drift_review_required{};
    EvidenceStatus evidence_status{EvidenceStatus::hold_for_review};
    std::string plain_language_explanation;
};

[[nodiscard]] bool finite_probability(double value) noexcept;

[[nodiscard]] bool finite_nonnegative(double value) noexcept;

[[nodiscard]] std::expected<FusionResult, FusionError> fuse_event_window(
    std::span<const TimedMeasurement> measurements,
    const FusionPolicy& policy);

[[nodiscard]] std::expected<DriftUpdate, FusionError> update_drift_state(
    DriftState previous,
    double observed_at_seconds,
    double measurement,
    double measurement_variance,
    const DriftPolicy& policy);

}  // namespace augmented_hub::sensor_fusion

#endif
