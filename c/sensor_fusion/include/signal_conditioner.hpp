#pragma once

#include <cmath>
#include <cstddef>
#include <stdexcept>
#include <vector>

namespace augmented_hub::sensor_fusion {

struct RawObservation {
    double observed_at_s;
    double raw_value;
    double instrument_temperature_deg_c;
    bool sensor_health_valid;
    bool time_sync_valid;
};

struct ConditionerConfiguration {
    double minimum_value;
    double maximum_value;
    double maximum_rate_per_s;
    double rolling_window_s;
};

struct ConditionedObservation {
    double observed_at_s;
    double raw_value;
    double conditioned_value;
    bool accepted;
    bool range_valid;
    bool rate_valid;
    bool sensor_health_valid;
    bool time_sync_valid;
};

inline void require_finite(double value, const char* field) {
    if (!std::isfinite(value)) {
        throw std::invalid_argument(field);
    }
}

inline ConditionedObservation condition(
    const RawObservation& current,
    const RawObservation* previous,
    const ConditionerConfiguration& configuration
) {
    require_finite(current.observed_at_s, "observed_at_s must be finite");
    require_finite(current.raw_value, "raw_value must be finite");
    require_finite(
        current.instrument_temperature_deg_c,
        "instrument_temperature_deg_c must be finite"
    );
    require_finite(configuration.minimum_value, "minimum_value must be finite");
    require_finite(configuration.maximum_value, "maximum_value must be finite");
    require_finite(
        configuration.maximum_rate_per_s,
        "maximum_rate_per_s must be finite"
    );
    require_finite(
        configuration.rolling_window_s,
        "rolling_window_s must be finite"
    );

    if (configuration.maximum_value <= configuration.minimum_value
        || configuration.maximum_rate_per_s < 0.0
        || configuration.rolling_window_s <= 0.0) {
        throw std::invalid_argument("invalid conditioner configuration");
    }

    const bool range_valid =
        current.raw_value >= configuration.minimum_value
        && current.raw_value <= configuration.maximum_value;

    bool rate_valid = true;
    if (previous != nullptr) {
        require_finite(previous->observed_at_s, "previous observed_at_s must be finite");
        require_finite(previous->raw_value, "previous raw_value must be finite");

        const double elapsed_s = current.observed_at_s - previous->observed_at_s;
        if (elapsed_s <= 0.0) {
            throw std::invalid_argument("observations must be time ordered");
        }

        const double rate_per_s =
            std::abs(current.raw_value - previous->raw_value) / elapsed_s;

        rate_valid = rate_per_s <= configuration.maximum_rate_per_s;
    }

    const bool accepted =
        current.sensor_health_valid
        && current.time_sync_valid
        && range_valid
        && rate_valid;

    return ConditionedObservation{
        .observed_at_s = current.observed_at_s,
        .raw_value = current.raw_value,
        .conditioned_value = current.raw_value,
        .accepted = accepted,
        .range_valid = range_valid,
        .rate_valid = rate_valid,
        .sensor_health_valid = current.sensor_health_valid,
        .time_sync_valid = current.time_sync_valid
    };
}

inline double median(std::vector<double> values) {
    if (values.empty()) {
        throw std::invalid_argument("median requires at least one value");
    }

    const std::size_t middle = values.size() / 2;
    std::nth_element(values.begin(), values.begin() + static_cast<std::ptrdiff_t>(middle), values.end());

    if (values.size() % 2 == 1) {
        return values[middle];
    }

    const double upper = values[middle];
    std::nth_element(
        values.begin(),
        values.begin() + static_cast<std::ptrdiff_t>(middle - 1),
        values.end()
    );

    return 0.5 * (values[middle - 1] + upper);
}

}  // namespace augmented_hub::sensor_fusion
