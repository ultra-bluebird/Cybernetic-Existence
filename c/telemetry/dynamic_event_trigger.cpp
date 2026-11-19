#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace augmented_hub::telemetry {

enum class TriggerDecision {
    Hold,
    Transmit,
    EmergencyTransmit,
    Indeterminate
};

struct TriggerInput {
    double weighted_error_norm{};
    double base_threshold{};
    double minimum_threshold{};
    double maximum_threshold{};
    double surcharge_margin{};
    double surcharge_scale{};
    double covariance_trace{};
    double maximum_covariance_trace{};
    double drift_score{};
    double battery_energy_j{};
    double battery_reserve_j{};
    double battery_nominal_j{};
    double seconds_since_last_transmission{};
    double minimum_inter_event_seconds{};
    double maximum_heartbeat_seconds{};
    bool sensor_quality_ok{};
};

struct TriggerResult {
    double threshold{};
    TriggerDecision decision{};
};

static bool finite(double value) {
    return std::isfinite(value);
}

static void require_nonnegative_finite(double value) {
    if (!finite(value) || value < 0.0) {
        throw std::invalid_argument("expected finite non-negative value");
    }
}

TriggerResult evaluate_dynamic_trigger(const TriggerInput& input) {
    const double values[] = {
        input.weighted_error_norm,
        input.base_threshold,
        input.minimum_threshold,
        input.maximum_threshold,
        input.surcharge_margin,
        input.surcharge_scale,
        input.covariance_trace,
        input.maximum_covariance_trace,
        input.drift_score,
        input.battery_energy_j,
        input.battery_reserve_j,
        input.battery_nominal_j,
        input.seconds_since_last_transmission,
        input.minimum_inter_event_seconds,
        input.maximum_heartbeat_seconds
    };

    for (const double value : values) {
        require_nonnegative_finite(value);
    }

    if (input.maximum_threshold < input.minimum_threshold ||
        input.surcharge_scale <= 0.0 ||
        input.maximum_covariance_trace <= 0.0 ||
        input.battery_nominal_j <= input.battery_reserve_j ||
        input.maximum_heartbeat_seconds < input.minimum_inter_event_seconds) {
        throw std::invalid_argument("invalid trigger bounds");
    }

    if (!input.sensor_quality_ok ||
        input.surcharge_margin <= 0.0 ||
        input.covariance_trace > input.maximum_covariance_trace ||
        input.seconds_since_last_transmission >= input.maximum_heartbeat_seconds) {
        return {
            input.minimum_threshold,
            TriggerDecision::EmergencyTransmit
        };
    }

    const double margin_factor =
        input.surcharge_margin /
        (input.surcharge_margin + input.surcharge_scale);

    const double uncertainty_factor =
        1.0 /
        (1.0 + input.covariance_trace / input.maximum_covariance_trace);

    const double drift_factor = 1.0 / (1.0 + input.drift_score);

    const double battery_factor = std::clamp(
        (input.battery_energy_j - input.battery_reserve_j) /
            (input.battery_nominal_j - input.battery_reserve_j),
        0.0,
        1.0
    );

    const double threshold = std::clamp(
        input.base_threshold *
            margin_factor *
            uncertainty_factor *
            drift_factor *
            battery_factor,
        input.minimum_threshold,
        input.maximum_threshold
    );

    if (input.seconds_since_last_transmission <
        input.minimum_inter_event_seconds) {
        return {threshold, TriggerDecision::Hold};
    }

    return {
        threshold,
        input.weighted_error_norm > threshold
            ? TriggerDecision::Transmit
            : TriggerDecision::Hold
    };
}

}  // namespace augmented_hub::telemetry
