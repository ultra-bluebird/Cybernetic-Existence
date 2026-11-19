#include "civic_edge_interaction.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <numbers>

namespace augmented_hub::civic_edge {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool valid_confidence(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

DoorCommand command_for_gesture(DoorGesture gesture) noexcept {
    switch (gesture) {
        case DoorGesture::open:
        case DoorGesture::wave:
            return DoorCommand::open;
        case DoorGesture::close:
            return DoorCommand::close;
        case DoorGesture::hold:
            return DoorCommand::hold_open;
        case DoorGesture::emergency_stop:
            return DoorCommand::emergency_stop;
        case DoorGesture::assist_mode:
            return DoorCommand::assist_mode;
        case DoorGesture::slow_open:
            return DoorCommand::slow_open;
        case DoorGesture::slow_close:
            return DoorCommand::slow_close;
        case DoorGesture::partial_open:
            return DoorCommand::partial_open;
        case DoorGesture::full_open:
            return DoorCommand::full_open;
        case DoorGesture::reset:
            return DoorCommand::reset;
        case DoorGesture::maintenance_mode:
            return DoorCommand::maintenance_mode;
    }

    return DoorCommand::none;
}

bool requires_interlock(DoorCommand command) noexcept {
    return command == DoorCommand::close ||
           command == DoorCommand::reset ||
           command == DoorCommand::maintenance_mode;
}

double signal_energy(std::span<const double> signal) noexcept {
    double energy = 0.0;

    for (const double sample : signal) {
        energy += sample * sample;
    }

    return energy;
}

double zero_mean(std::span<const double> signal, std::vector<double>& output) {
    double sum = 0.0;

    for (const double sample : signal) {
        sum += sample;
    }

    const double mean = sum / static_cast<double>(signal.size());

    output.clear();
    output.reserve(signal.size());

    for (const double sample : signal) {
        output.push_back(sample - mean);
    }

    return mean;
}

double normalized_cross_correlation_at_lag(
    std::span<const double> first,
    std::span<const double> second,
    int lag) {

    double numerator = 0.0;
    double first_energy = 0.0;
    double second_energy = 0.0;

    for (std::size_t i = 0; i < first.size(); ++i) {
        const int shifted_index = static_cast<int>(i) + lag;

        if (shifted_index < 0 ||
            shifted_index >= static_cast<int>(second.size())) {
            continue;
        }

        const double left = first[i];
        const double right = second[static_cast<std::size_t>(shifted_index)];

        numerator += left * right;
        first_energy += left * left;
        second_energy += right * right;
    }

    const double denominator = std::sqrt(first_energy * second_energy);

    return denominator > kEpsilon ? numerator / denominator : 0.0;
}

double low_frequency_energy_ratio(
    std::span<const double> signal,
    double sampling_rate_hz) {

    const std::size_t n = signal.size();
    const std::size_t max_bin = n / 2U;
    const double frequency_resolution = sampling_rate_hz / static_cast<double>(n);

    double total_energy = 0.0;
    double traffic_band_energy = 0.0;

    for (std::size_t bin = 1; bin < max_bin; ++bin) {
        double real = 0.0;
        double imaginary = 0.0;

        for (std::size_t sample = 0; sample < n; ++sample) {
            const double phase =
                2.0 * std::numbers::pi *
                static_cast<double>(bin) *
                static_cast<double>(sample) /
                static_cast<double>(n);

            real += signal[sample] * std::cos(phase);
            imaginary -= signal[sample] * std::sin(phase);
        }

        const double bin_energy = real * real + imaginary * imaginary;
        const double frequency_hz = static_cast<double>(bin) * frequency_resolution;

        total_energy += bin_energy;

        if (frequency_hz >= 1.0 && frequency_hz <= 80.0) {
            traffic_band_energy += bin_energy;
        }
    }

    return total_energy > kEpsilon
        ? traffic_band_energy / total_energy
        : 1.0;
}

}  // namespace

std::expected<GestureDecision, GestureError> decide_door_command(
    const GestureInference& inference,
    const GesturePolicy& policy) {

    if (!valid_confidence(inference.confidence) ||
        !valid_confidence(policy.minimum_confidence)) {
        return std::unexpected(GestureError::invalid_confidence);
    }

    if (!inference.on_device_processed ||
        inference.raw_point_cloud_persisted ||
        inference.raw_data_age_milliseconds >
            policy.maximum_raw_retention_milliseconds) {
        return std::unexpected(GestureError::raw_data_retention_exceeded);
    }

    const DoorCommand command = command_for_gesture(inference.gesture);

    const bool is_assist_mode = command == DoorCommand::assist_mode;

    const std::int64_t applicable_latency_budget =
        is_assist_mode
            ? policy.assist_latency_budget_milliseconds
            : policy.general_latency_budget_milliseconds;

    if (inference.inference_latency_milliseconds > applicable_latency_budget) {
        return std::unexpected(GestureError::unsafe_command);
    }

    if (inference.confidence < policy.minimum_confidence) {
        return std::unexpected(GestureError::ambiguous_gesture);
    }

    return GestureDecision{
        .command = command,
        .requires_safety_interlock = requires_interlock(command),
        .requires_human_review =
            command == DoorCommand::maintenance_mode ||
            command == DoorCommand::reset,
        .plain_language_explanation =
            is_assist_mode
                ? "Assist mode was recognized and prioritized through on-device, non-biometric gesture processing. The door controller must still apply its physical safety interlocks."
                : "A transient non-biometric gesture was recognized on-device. No facial, gait, identity, or raw depth-point-cloud record is retained."
    };
}

std::expected<LeakLocationEstimate, LeakError> estimate_leak_location(
    std::span<const double> sensor_one_signal,
    std::span<const double> sensor_two_signal,
    AcousticSensorPosition sensor_one,
    AcousticSensorPosition sensor_two,
    const LeakDetectionPolicy& policy) {

    if (sensor_one_signal.size() < 32U ||
        sensor_two_signal.size() < 32U) {
        return std::unexpected(LeakError::insufficient_samples);
    }

    if (sensor_one_signal.size() != sensor_two_signal.size()) {
        return std::unexpected(LeakError::mismatched_signal_lengths);
    }

    if (!finite_nonnegative(policy.sampling_rate_hz) ||
        policy.sampling_rate_hz <= 0.0) {
        return std::unexpected(LeakError::invalid_sampling_rate);
    }

    if (!finite_nonnegative(policy.wave_speed_m_per_second) ||
        policy.wave_speed_m_per_second <= 0.0) {
        return std::unexpected(LeakError::invalid_wave_speed);
    }

    if (!finite_nonnegative(policy.minimum_coherence) ||
        !finite_nonnegative(policy.minimum_snr) ||
        !finite_nonnegative(policy.maximum_traffic_band_energy_ratio)) {
        return std::unexpected(LeakError::invalid_threshold);
    }

    const double sensor_distance =
        std::abs(
            sensor_two.longitudinal_pipe_distance_m -
            sensor_one.longitudinal_pipe_distance_m);

    if (sensor_distance <= 0.0) {
        return std::unexpected(LeakError::invalid_sensor_geometry);
    }

    std::vector<double> first_centered;
    std::vector<double> second_centered;

    zero_mean(sensor_one_signal, first_centered);
    zero_mean(sensor_two_signal, second_centered);

    const int maximum_lag_samples = static_cast<int>(
        std::ceil(
            sensor_distance /
            policy.wave_speed_m_per_second *
            policy.sampling_rate_hz));

    int best_lag = 0;
    double best_correlation = 0.0;

    for (int lag = -maximum_lag_samples;
         lag <= maximum_lag_samples;
         ++lag) {
        const double correlation =
            normalized_cross_correlation_at_lag(
                first_centered,
                second_centered,
                lag);

        if (std::abs(correlation) > std::abs(best_correlation)) {
            best_correlation = correlation;
            best_lag = lag;
        }
    }

    const double time_delay_seconds =
        static_cast<double>(best_lag) / policy.sampling_rate_hz;

    const double distance_from_sensor_one =
        std::clamp(
            (sensor_distance +
             policy.wave_speed_m_per_second * time_delay_seconds) /
                2.0,
            0.0,
            sensor_distance);

    const double first_energy = signal_energy(first_centered);
    const double second_energy = signal_energy(second_centered);

    const double enhanced_snr =
        std::sqrt(std::min(first_energy, second_energy) /
                  static_cast<double>(sensor_one_signal.size()));

    const double first_traffic_ratio =
        low_frequency_energy_ratio(first_centered, policy.sampling_rate_hz);

    const double second_traffic_ratio =
        low_frequency_energy_ratio(second_centered, policy.sampling_rate_hz);

    const double traffic_band_energy_ratio =
        std::max(first_traffic_ratio, second_traffic_ratio);

    const double coherence_proxy = std::abs(best_correlation);

    const bool leak_candidate =
        coherence_proxy >= policy.minimum_coherence &&
        enhanced_snr >= policy.minimum_snr &&
        traffic_band_energy_ratio <= policy.maximum_traffic_band_energy_ratio;

    return LeakLocationEstimate{
        .time_delay_seconds = time_delay_seconds,
        .estimated_distance_from_sensor_one_m = distance_from_sensor_one,
        .normalized_cross_correlation = best_correlation,
        .coherence_proxy = coherence_proxy,
        .enhanced_snr = enhanced_snr,
        .traffic_band_energy_ratio = traffic_band_energy_ratio,
        .leak_candidate = leak_candidate,
        .evidence_status = leak_candidate
            ? LeakEvidenceStatus::hold_for_review
            : LeakEvidenceStatus::accepted_with_limitations,
        .plain_language_explanation = leak_candidate
            ? "Cross-correlation, signal coherence, and frequency-domain screening support a potential leak location. The estimate is retained for utility and field review before repair dispatch."
            : "The acoustic evidence does not meet the configured leak-candidate thresholds. It remains available for trend analysis and sensor-health review."
    };
}

}  // namespace augmented_hub::civic_edge
