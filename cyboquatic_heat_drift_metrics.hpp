#ifndef AUGMENTED_HUB_CYBOQUATIC_HEAT_DRIFT_METRICS_HPP
#define AUGMENTED_HUB_CYBOQUATIC_HEAT_DRIFT_METRICS_HPP

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace augmented_hub::cyboquatic {

enum class DriftDecision : std::uint8_t {
    Simulate = 0,
    Derate = 1,
    Hold = 2,
    Reject = 3
};

enum class DriftDirection : std::uint8_t {
    None = 0,
    Positive = 1,
    Negative = 2,
    Both = 3
};

struct PlanarSample {
    double east_m;
    double north_m;
    double surface_temperature_c;
    double weight;
};

struct AnisotropyResult {
    double weighted_mean_temperature_c;
    double covariance_east_east;
    double covariance_east_north;
    double covariance_north_north;
    double principal_eigenvalue;
    double secondary_eigenvalue;
    double anisotropy_ratio;
    double anisotropy_score;
    double principal_axis_azimuth_degrees;
    bool valid;
};

struct CusumConfiguration {
    double target_mean;
    double baseline_standard_deviation;
    double reference_shift_standard_deviations;
    double decision_interval_standard_deviations;
    std::size_t minimum_observations;
};

struct CusumState {
    std::size_t observation_count;
    double positive_sum;
    double negative_sum;
    DriftDirection direction;
    DriftDecision decision;
};

struct CusumUpdate {
    CusumState state;
    double standardized_residual;
    double positive_boundary;
    double negative_boundary;
    bool out_of_control;
};

inline bool is_finite(double value) noexcept {
    return std::isfinite(value);
}

inline double clamp(double value, double minimum, double maximum) noexcept {
    return std::max(minimum, std::min(maximum, value));
}

inline double radians_to_degrees(double radians) noexcept {
    return radians * (180.0 / 3.14159265358979323846);
}

inline double normalize_azimuth_degrees(double azimuth) noexcept {
    double normalized = std::fmod(azimuth, 180.0);

    if (normalized < 0.0) {
        normalized += 180.0;
    }

    return normalized;
}

inline AnisotropyResult analyze_local_heat_anisotropy(
    const PlanarSample* samples,
    std::size_t sample_count
) noexcept {
    AnisotropyResult result{
        .weighted_mean_temperature_c = 0.0,
        .covariance_east_east = 0.0,
        .covariance_east_north = 0.0,
        .covariance_north_north = 0.0,
        .principal_eigenvalue = 0.0,
        .secondary_eigenvalue = 0.0,
        .anisotropy_ratio = 1.0,
        .anisotropy_score = 0.0,
        .principal_axis_azimuth_degrees = 0.0,
        .valid = false
    };

    if (samples == nullptr || sample_count < 3U) {
        return result;
    }

    double weight_sum = 0.0;
    double mean_east = 0.0;
    double mean_north = 0.0;
    double mean_temperature = 0.0;

    for (std::size_t index = 0U; index < sample_count; ++index) {
        const PlanarSample& sample = samples[index];

        if (!is_finite(sample.east_m)
            || !is_finite(sample.north_m)
            || !is_finite(sample.surface_temperature_c)
            || !is_finite(sample.weight)
            || sample.weight <= 0.0) {
            return result;
        }

        weight_sum += sample.weight;
        mean_east += sample.weight * sample.east_m;
        mean_north += sample.weight * sample.north_m;
        mean_temperature += sample.weight * sample.surface_temperature_c;
    }

    if (!is_finite(weight_sum) || weight_sum <= 0.0) {
        return result;
    }

    mean_east /= weight_sum;
    mean_north /= weight_sum;
    mean_temperature /= weight_sum;

    double c_ee = 0.0;
    double c_en = 0.0;
    double c_nn = 0.0;

    for (std::size_t index = 0U; index < sample_count; ++index) {
        const PlanarSample& sample = samples[index];
        const double temperature_anomaly = sample.surface_temperature_c - mean_temperature;
        const double east_weighted_gradient = (sample.east_m - mean_east) * temperature_anomaly;
        const double north_weighted_gradient = (sample.north_m - mean_north) * temperature_anomaly;

        c_ee += sample.weight * east_weighted_gradient * east_weighted_gradient;
        c_en += sample.weight * east_weighted_gradient * north_weighted_gradient;
        c_nn += sample.weight * north_weighted_gradient * north_weighted_gradient;
    }

    c_ee /= weight_sum;
    c_en /= weight_sum;
    c_nn /= weight_sum;

    const double trace = c_ee + c_nn;
    const double determinant = c_ee * c_nn - c_en * c_en;
    const double discriminant = std::max(0.0, trace * trace - 4.0 * determinant);
    const double root = std::sqrt(discriminant);

    const double lambda_major = std::max(0.0, 0.5 * (trace + root));
    const double lambda_minor = std::max(0.0, 0.5 * (trace - root));
    const double epsilon = 1e-12;

    const double anisotropy_ratio = lambda_major / std::max(lambda_minor, epsilon);
    const double anisotropy_score = clamp(
        (lambda_major - lambda_minor) / std::max(lambda_major + lambda_minor, epsilon),
        0.0,
        1.0
    );

    const double principal_axis_radians = 0.5 * std::atan2(2.0 * c_en, c_ee - c_nn);
    const double azimuth_from_north_degrees = normalize_azimuth_degrees(
        90.0 - radians_to_degrees(principal_axis_radians)
    );

    result.weighted_mean_temperature_c = mean_temperature;
    result.covariance_east_east = c_ee;
    result.covariance_east_north = c_en;
    result.covariance_north_north = c_nn;
    result.principal_eigenvalue = lambda_major;
    result.secondary_eigenvalue = lambda_minor;
    result.anisotropy_ratio = anisotropy_ratio;
    result.anisotropy_score = anisotropy_score;
    result.principal_axis_azimuth_degrees = azimuth_from_north_degrees;
    result.valid = true;

    return result;
}

inline bool is_valid_cusum_configuration(
    const CusumConfiguration& configuration
) noexcept {
    return is_finite(configuration.target_mean)
        && is_finite(configuration.baseline_standard_deviation)
        && is_finite(configuration.reference_shift_standard_deviations)
        && is_finite(configuration.decision_interval_standard_deviations)
        && configuration.baseline_standard_deviation > 0.0
        && configuration.reference_shift_standard_deviations > 0.0
        && configuration.decision_interval_standard_deviations > 0.0
        && configuration.minimum_observations > 0U;
}

inline CusumUpdate update_two_sided_cusum(
    const CusumConfiguration& configuration,
    CusumState prior,
    double observed_residual
) noexcept {
    CusumUpdate update{
        .state = prior,
        .standardized_residual = 0.0,
        .positive_boundary = 0.0,
        .negative_boundary = 0.0,
        .out_of_control = false
    };

    if (!is_valid_cusum_configuration(configuration)
        || !is_finite(observed_residual)) {
        update.state.decision = DriftDecision::Hold;
        update.state.direction = DriftDirection::Both;
        return update;
    }

    const double standardized = (
        observed_residual - configuration.target_mean
    ) / configuration.baseline_standard_deviation;

    const double allowance = configuration.reference_shift_standard_deviations / 2.0;
    const double decision_boundary = configuration.decision_interval_standard_deviations;

    const double positive_sum = std::max(
        0.0,
        prior.positive_sum + standardized - allowance
    );

    const double negative_sum = std::max(
        0.0,
        prior.negative_sum - standardized - allowance
    );

    DriftDirection direction = DriftDirection::None;

    if (positive_sum >= decision_boundary && negative_sum >= decision_boundary) {
        direction = DriftDirection::Both;
    } else if (positive_sum >= decision_boundary) {
        direction = DriftDirection::Positive;
    } else if (negative_sum >= decision_boundary) {
        direction = DriftDirection::Negative;
    }

    const std::size_t observation_count = prior.observation_count + 1U;
    const bool out_of_control = direction != DriftDirection::None
        && observation_count >= configuration.minimum_observations;

    DriftDecision decision = prior.decision;

    if (out_of_control) {
        decision = DriftDecision::Hold;
    }

    update.state = CusumState{
        .observation_count = observation_count,
        .positive_sum = positive_sum,
        .negative_sum = negative_sum,
        .direction = direction,
        .decision = decision
    };

    update.standardized_residual = standardized;
    update.positive_boundary = decision_boundary;
    update.negative_boundary = -decision_boundary;
    update.out_of_control = out_of_control;

    return update;
}

}  // namespace augmented_hub::cyboquatic

#endif
