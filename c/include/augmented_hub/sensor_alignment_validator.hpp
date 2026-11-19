#ifndef AUGMENTED_HUB_SENSOR_ALIGNMENT_VALIDATOR_HPP
#define AUGMENTED_HUB_SENSOR_ALIGNMENT_VALIDATOR_HPP

#include <cmath>
#include <cstddef>
#include <optional>
#include <stdexcept>
#include <string_view>

namespace augmented_hub {

enum class SensorType {
    VoltageV,
    CurrentA,
    FlowM3S,
    TemperatureC,
    DissolvedOxygenMgL,
    TurbidityNtu
};

struct SensorMeasurement {
    SensorType type;
    double primary_value;
    double redundant_value;
    std::optional<double> physical_model_value;
    bool physical_model_checked;
};

struct AlignmentResult {
    bool accepted;
    double absolute_difference;
    double allowed_difference;
    std::string_view reason;
};

class SensorAlignmentValidator final {
public:
    [[nodiscard]] static constexpr double epsilon_for(SensorType type) {
        switch (type) {
            case SensorType::VoltageV:
                return 0.02;
            case SensorType::CurrentA:
                return 0.03;
            case SensorType::FlowM3S:
                return 0.05;
            case SensorType::TemperatureC:
                return 0.02;
            case SensorType::DissolvedOxygenMgL:
                return 0.05;
            case SensorType::TurbidityNtu:
                return 0.10;
        }

        throw std::invalid_argument("Unsupported sensor type.");
    }

    [[nodiscard]] static AlignmentResult validate(
        const SensorMeasurement& measurement
    ) {
        require_finite(measurement.primary_value, "primary_value");
        require_finite(measurement.redundant_value, "redundant_value");

        if (measurement.physical_model_checked) {
            if (!measurement.physical_model_value.has_value()) {
                throw std::invalid_argument(
                    "physical_model_value is required when physical_model_checked is true."
                );
            }

            require_finite(
                measurement.physical_model_value.value(),
                "physical_model_value"
            );
        }

        const double epsilon = epsilon_for(measurement.type);
        const double absolute_difference = std::abs(
            measurement.primary_value - measurement.redundant_value
        );
        const double allowed_difference = epsilon * std::max(
            std::abs(measurement.primary_value),
            1.0
        );

        const bool redundant_measurement_aligned =
            absolute_difference <= allowed_difference;

        const bool physical_model_aligned =
            !measurement.physical_model_checked
            || physical_model_within_bound(
                measurement.primary_value,
                measurement.physical_model_value.value(),
                epsilon
            );

        if (!redundant_measurement_aligned) {
            return {
                false,
                absolute_difference,
                allowed_difference,
                "PRIMARY_REDUNDANT_ALIGNMENT_FAILED"
            };
        }

        if (!physical_model_aligned) {
            return {
                false,
                absolute_difference,
                allowed_difference,
                "PHYSICAL_MODEL_ALIGNMENT_FAILED"
            };
        }

        return {
            true,
            absolute_difference,
            allowed_difference,
            "SENSOR_ALIGNMENT_ACCEPTED"
        };
    }

private:
    static void require_finite(double value, std::string_view name) {
        if (!std::isfinite(value)) {
            throw std::invalid_argument(
                std::string(name) + " must be finite."
            );
        }
    }

    [[nodiscard]] static bool physical_model_within_bound(
        double sensor_value,
        double model_value,
        double epsilon
    ) {
        const double difference = std::abs(sensor_value - model_value);
        const double limit = epsilon * std::max(std::abs(sensor_value), 1.0);
        return difference <= limit;
    }
};

}  // namespace augmented_hub

#endif
