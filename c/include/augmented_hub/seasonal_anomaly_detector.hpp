#ifndef AUGMENTED_HUB_SEASONAL_ANOMALY_DETECTOR_HPP
#define AUGMENTED_HUB_SEASONAL_ANOMALY_DETECTOR_HPP

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace augmented_hub {

struct TelemetrySample {
    std::int64_t timestamp_unix_seconds;
    double value;
    bool sensor_quality_ok;
    bool redundant_measurement_available;
    std::optional<double> redundant_value;
    bool intervention_recorded;
    bool physical_model_consistent;
};

struct AnomalyAssessment {
    bool anomaly_candidate;
    bool probable_sensor_failure;
    bool probable_verified_improvement;
    double expected_value;
    double residual;
    double robust_scale;
    double robust_z_score;
    std::string explanation_code;
};

class SeasonalAnomalyDetector final {
public:
    explicit SeasonalAnomalyDetector(
        std::size_t seasonal_period,
        double anomaly_threshold = 3.5,
        double minimum_scale = 1e-9
    )
        : seasonal_period_(seasonal_period),
          anomaly_threshold_(anomaly_threshold),
          minimum_scale_(minimum_scale) {
        if (seasonal_period_ == 0) {
            throw std::invalid_argument(
                "seasonal_period must be greater than zero."
            );
        }

        if (!std::isfinite(anomaly_threshold_) ||
            anomaly_threshold_ <= 0.0) {
            throw std::invalid_argument(
                "anomaly_threshold must be finite and greater than zero."
            );
        }

        if (!std::isfinite(minimum_scale_) ||
            minimum_scale_ <= 0.0) {
            throw std::invalid_argument(
                "minimum_scale must be finite and greater than zero."
            );
        }
    }

    [[nodiscard]] AnomalyAssessment assess(
        const std::vector<TelemetrySample>& history,
        const TelemetrySample& candidate
    ) const {
        validate_sample(candidate);

        if (history.size() < seasonal_period_ * 2) {
            return {
                false,
                false,
                false,
                0.0,
                0.0,
                0.0,
                0.0,
                "INSUFFICIENT_SEASONAL_HISTORY_REVIEW_REQUIRED"
            };
        }

        const double expected = seasonal_expected_value(history);
        const double residual = candidate.value - expected;
        const double scale = robust_residual_scale(history);
        const double z_score = std::abs(residual) / std::max(scale, minimum_scale_);
        const bool anomaly = z_score >= anomaly_threshold_;

        if (!anomaly) {
            return {
                false,
                false,
                false,
                expected,
                residual,
                scale,
                z_score,
                "TELEMETRY_WITHIN_SEASONAL_EXPECTATION"
            };
        }

        const bool redundant_disagrees =
            candidate.redundant_measurement_available &&
            candidate.redundant_value.has_value() &&
            !approximately_equal(
                candidate.value,
                candidate.redundant_value.value(),
                0.05
            );

        const bool sensor_failure =
            !candidate.sensor_quality_ok ||
            !candidate.physical_model_consistent ||
            redundant_disagrees;

        if (sensor_failure) {
            return {
                true,
                true,
                false,
                expected,
                residual,
                scale,
                z_score,
                "ANOMALY_PROBABLE_SENSOR_FAILURE_REVIEW_REQUIRED"
            };
        }

        if (candidate.intervention_recorded &&
            candidate.sensor_quality_ok &&
            candidate.physical_model_consistent &&
            candidate.redundant_measurement_available &&
            candidate.redundant_value.has_value() &&
            approximately_equal(
                candidate.value,
                candidate.redundant_value.value(),
                0.05
            )) {
            return {
                true,
                false,
                true,
                expected,
                residual,
                scale,
                z_score,
                "ANOMALY_POSSIBLE_VERIFIED_ECO_IMPROVEMENT_REVIEW_REQUIRED"
            };
        }

        return {
            true,
            false,
            false,
            expected,
            residual,
            scale,
            z_score,
            "UNEXPLAINED_ANOMALY_HUMAN_REVIEW_REQUIRED"
        };
    }

private:
    std::size_t seasonal_period_;
    double anomaly_threshold_;
    double minimum_scale_;

    static void validate_sample(const TelemetrySample& sample) {
        if (!std::isfinite(sample.value)) {
            throw std::invalid_argument(
                "Telemetry sample value must be finite."
            );
        }

        if (sample.redundant_value.has_value() &&
            !std::isfinite(sample.redundant_value.value())) {
            throw std::invalid_argument(
                "Redundant telemetry value must be finite when supplied."
            );
        }
    }

    [[nodiscard]] double seasonal_expected_value(
        const std::vector<TelemetrySample>& history
    ) const {
        std::vector<double> matching_phase_values;

        for (std::size_t index = history.size() % seasonal_period_;
             index < history.size();
             index += seasonal_period_) {
            if (history[index].sensor_quality_ok &&
                std::isfinite(history[index].value)) {
                matching_phase_values.push_back(history[index].value);
            }
        }

        if (matching_phase_values.empty()) {
            throw std::runtime_error(
                "No valid seasonal phase values are available."
            );
        }

        return median(std::move(matching_phase_values));
    }

    [[nodiscard]] double robust_residual_scale(
        const std::vector<TelemetrySample>& history
    ) const {
        std::vector<double> residuals;
        residuals.reserve(history.size());

        for (std::size_t index = seasonal_period_;
             index < history.size();
             ++index) {
            const TelemetrySample& current = history[index];
            const TelemetrySample& seasonal_reference =
                history[index - seasonal_period_];

            if (current.sensor_quality_ok &&
                seasonal_reference.sensor_quality_ok &&
                std::isfinite(current.value) &&
                std::isfinite(seasonal_reference.value)) {
                residuals.push_back(
                    current.value - seasonal_reference.value
                );
            }
        }

        if (residuals.empty()) {
            throw std::runtime_error(
                "No valid seasonal residuals are available."
            );
        }

        const double residual_median = median(residuals);

        std::vector<double> absolute_deviations;
        absolute_deviations.reserve(residuals.size());

        for (const double residual : residuals) {
            absolute_deviations.push_back(
                std::abs(residual - residual_median)
            );
        }

        return 1.4826 * median(std::move(absolute_deviations));
    }

    static bool approximately_equal(
        double left,
        double right,
        double relative_tolerance
    ) {
        const double scale = std::max(
            {std::abs(left), std::abs(right), 1.0}
        );

        return std::abs(left - right) <= relative_tolerance * scale;
    }

    static double median(std::vector<double> values) {
        if (values.empty()) {
            throw std::invalid_argument(
                "Median requires at least one value."
            );
        }

        const std::size_t middle = values.size() / 2;

        std::nth_element(
            values.begin(),
            values.begin() + static_cast<std::ptrdiff_t>(middle),
            values.end()
        );

        double upper = values[middle];

        if (values.size() % 2 == 1) {
            return upper;
        }

        std::nth_element(
            values.begin(),
            values.begin() + static_cast<std::ptrdiff_t>(middle - 1),
            values.end()
        );

        return (values[middle - 1] + upper) / 2.0;
    }
};

}  // namespace augmented_hub

#endif
