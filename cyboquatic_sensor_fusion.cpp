#include "cyboquatic_sensor_fusion.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>

namespace augmented_hub::sensor_fusion {
namespace {

constexpr double kProbabilityFloor = 1e-12;
constexpr double kEnvironmentalChangeNisThreshold = 6.63;

double clamp_probability(double value) noexcept {
    return std::clamp(value, kProbabilityFloor, 1.0 - kProbabilityFloor);
}

}  // namespace

bool finite_probability(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

std::expected<FusionResult, FusionError> fuse_event_window(
    std::span<const TimedMeasurement> measurements,
    const FusionPolicy& policy) {

    if (measurements.empty()) {
        return std::unexpected(FusionError::empty_window);
    }

    if (!finite_probability(policy.event_prior) ||
        !finite_probability(policy.detection_threshold) ||
        !finite_nonnegative(policy.temporal_window_seconds) ||
        policy.minimum_modalities == 0U) {
        return std::unexpected(FusionError::invalid_probability);
    }

    const double reference_time = measurements.front().observed_at_seconds;
    std::array<bool, 4> modality_present{};

    double log_odds = std::log(
        clamp_probability(policy.event_prior) /
        (1.0 - clamp_probability(policy.event_prior)));

    for (const auto& measurement : measurements) {
        if (!std::isfinite(measurement.observed_at_seconds)) {
            return std::unexpected(FusionError::invalid_timestamp);
        }

        if (std::abs(measurement.observed_at_seconds - reference_time) >
            policy.temporal_window_seconds) {
            return std::unexpected(FusionError::outside_temporal_window);
        }

        if (!finite_probability(measurement.anomaly_likelihood) ||
            !finite_nonnegative(measurement.measurement_uncertainty)) {
            return std::unexpected(FusionError::invalid_measurement);
        }

        const auto modality_index =
            static_cast<std::size_t>(measurement.modality);

        if (modality_index >= modality_present.size()) {
            return std::unexpected(FusionError::invalid_measurement);
        }

        modality_present[modality_index] = true;

        const double calibration_weight =
            measurement.calibration_current ? 1.0 : 0.5;

        const double uncertainty_weight =
            1.0 / (1.0 + measurement.measurement_uncertainty);

        const double likelihood =
            clamp_probability(measurement.anomaly_likelihood);

        log_odds += calibration_weight * uncertainty_weight *
            std::log(likelihood / (1.0 - likelihood));
    }

    const std::size_t aligned_modalities = static_cast<std::size_t>(
        std::count(modality_present.begin(), modality_present.end(), true));

    const double posterior_event_probability =
        1.0 / (1.0 + std::exp(-log_odds));

    const bool event_candidate =
        aligned_modalities >= policy.minimum_modalities &&
        posterior_event_probability >= policy.detection_threshold;

    return FusionResult{
        .posterior_event_probability = posterior_event_probability,
        .aligned_modalities = aligned_modalities,
        .evidence_status = event_candidate
            ? EvidenceStatus::hold_for_review
            : EvidenceStatus::accepted_with_limitations,
        .plain_language_explanation = event_candidate
            ? "Multiple aligned environmental modalities support an event candidate. The result is held for accountable review before any external action."
            : "The evidence remains available for environmental trend analysis with stated uncertainty and modality limitations."
    };
}

std::expected<DriftUpdate, FusionError> update_drift_state(
    DriftState previous,
    double observed_at_seconds,
    double measurement,
    double measurement_variance,
    const DriftPolicy& policy) {

    if (!std::isfinite(observed_at_seconds) ||
        !std::isfinite(measurement) ||
        !finite_nonnegative(measurement_variance) ||
        !finite_nonnegative(policy.mean_reversion_rate_per_second) ||
        !std::isfinite(policy.long_run_drift) ||
        !finite_nonnegative(policy.process_noise_true_value) ||
        !finite_nonnegative(policy.process_noise_drift) ||
        !finite_nonnegative(policy.minimum_measurement_variance) ||
        !finite_nonnegative(policy.review_drift_ratio)) {
        return std::unexpected(FusionError::invalid_filter_parameter);
    }

    if (!previous.initialized) {
        previous = DriftState{
            .estimated_true_value = measurement,
            .estimated_drift = 0.0,
            .true_value_variance = std::max(
                measurement_variance,
                policy.minimum_measurement_variance),
            .drift_variance = policy.minimum_measurement_variance,
            .covariance = 0.0,
            .last_update_seconds = observed_at_seconds,
            .initialized = true
        };

        return DriftUpdate{
            .state = previous,
            .innovation = 0.0,
            .innovation_variance =
                previous.true_value_variance + measurement_variance,
            .normalized_innovation_squared = 0.0,
            .probable_environmental_change = false,
            .drift_review_required = false,
            .evidence_status = EvidenceStatus::accepted_with_limitations,
            .plain_language_explanation =
                "The drift estimator has initialized from a validated measurement. Subsequent observations will establish the sensor-specific drift model."
        };
    }

    if (!std::isfinite(previous.estimated_true_value) ||
        !std::isfinite(previous.estimated_drift) ||
        !finite_nonnegative(previous.true_value_variance) ||
        !finite_nonnegative(previous.drift_variance) ||
        !std::isfinite(previous.covariance) ||
        !std::isfinite(previous.last_update_seconds) ||
        observed_at_seconds <= previous.last_update_seconds) {
        return std::unexpected(FusionError::non_monotonic_time);
    }

    const double delta_seconds =
        observed_at_seconds - previous.last_update_seconds;

    const double mean_reversion =
        std::exp(-policy.mean_reversion_rate_per_second * delta_seconds);

    const double predicted_true_value = previous.estimated_true_value;

    const double predicted_drift =
        policy.long_run_drift +
        mean_reversion * (previous.estimated_drift - policy.long_run_drift);

    const double predicted_p00 =
        previous.true_value_variance +
        policy.process_noise_true_value * delta_seconds;

    const double predicted_p01 =
        mean_reversion * previous.covariance;

    const double predicted_p11 =
        mean_reversion * mean_reversion * previous.drift_variance +
        policy.process_noise_drift * delta_seconds;

    const double predicted_measurement =
        predicted_true_value + predicted_drift;

    const double innovation =
        measurement - predicted_measurement;

    const double effective_measurement_variance =
        std::max(
            measurement_variance,
            policy.minimum_measurement_variance);

    const double innovation_variance =
        predicted_p00 +
        (2.0 * predicted_p01) +
        predicted_p11 +
        effective_measurement_variance;

    if (!finite_nonnegative(innovation_variance) ||
        innovation_variance <= std::numeric_limits<double>::epsilon()) {
        return std::unexpected(FusionError::invalid_filter_parameter);
    }

    const double true_value_gain =
        (predicted_p00 + predicted_p01) / innovation_variance;

    const double drift_gain =
        (predicted_p01 + predicted_p11) / innovation_variance;

    DriftState updated{
        .estimated_true_value =
            predicted_true_value + true_value_gain * innovation,
        .estimated_drift =
            predicted_drift + drift_gain * innovation,
        .true_value_variance =
            predicted_p00 -
            true_value_gain * (predicted_p00 + predicted_p01),
        .drift_variance =
            predicted_p11 -
            drift_gain * (predicted_p01 + predicted_p11),
        .covariance =
            predicted_p01 -
            true_value_gain * (predicted_p01 + predicted_p11),
        .last_update_seconds = observed_at_seconds,
        .initialized = true
    };

    if (!std::isfinite(updated.estimated_true_value) ||
        !std::isfinite(updated.estimated_drift) ||
        !finite_nonnegative(updated.true_value_variance) ||
        !finite_nonnegative(updated.drift_variance) ||
        !std::isfinite(updated.covariance)) {
        return std::unexpected(FusionError::invalid_filter_parameter);
    }

    const double normalized_innovation_squared =
        (innovation * innovation) / innovation_variance;

    const double magnitude_reference =
        std::max(std::abs(updated.estimated_true_value), kProbabilityFloor);

    const bool drift_review_required =
        std::abs(updated.estimated_drift) / magnitude_reference >=
        policy.review_drift_ratio;

    const bool probable_environmental_change =
        normalized_innovation_squared >= kEnvironmentalChangeNisThreshold &&
        !drift_review_required;

    return DriftUpdate{
        .state = updated,
        .innovation = innovation,
        .innovation_variance = innovation_variance,
        .normalized_innovation_squared = normalized_innovation_squared,
        .probable_environmental_change = probable_environmental_change,
        .drift_review_required = drift_review_required,
        .evidence_status = drift_review_required
            ? EvidenceStatus::hold_for_review
            : EvidenceStatus::accepted_with_limitations,
        .plain_language_explanation = drift_review_required
            ? "The estimated sensor drift exceeds the configured review limit. The observation remains preserved with a hold-for-review state and traceable environmental provenance."
            : probable_environmental_change
                ? "The deviation is not sufficiently explained by modeled sensor drift or expected noise. It is retained as a possible environmental change for multi-modal review."
                : "The observation is consistent with the current drift and uncertainty model."
    };
}

}  // namespace augmented_hub::sensor_fusion
