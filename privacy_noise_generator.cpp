#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <random>
#include <stdexcept>

namespace augmented_hub::privacy {

struct NoiseParameters {
    double epsilon{};
    double sensitivity{};
    std::uint64_t random_seed{};
};

struct NoisyRelease {
    double raw_value{};
    double noise{};
    double released_value{};
    bool bounded{};
};

class LaplaceNoiseGenerator {
public:
    [[nodiscard]] static NoisyRelease bounded_release(
        double raw_value,
        double lower_bound,
        double upper_bound,
        const NoiseParameters& parameters) {

        if (!std::isfinite(raw_value) ||
            !std::isfinite(lower_bound) ||
            !std::isfinite(upper_bound) ||
            lower_bound >= upper_bound ||
            !std::isfinite(parameters.epsilon) ||
            parameters.epsilon <= 0.0 ||
            !std::isfinite(parameters.sensitivity) ||
            parameters.sensitivity <= 0.0) {
            throw std::invalid_argument("Invalid bounded-release parameters.");
        }

        if (raw_value < lower_bound || raw_value > upper_bound) {
            throw std::invalid_argument("Raw value must be within the approved bounds.");
        }

        const double scale = parameters.sensitivity / parameters.epsilon;

        std::mt19937_64 engine(parameters.random_seed);
        std::uniform_real_distribution<double> distribution(-0.5, 0.5);

        const double uniform = distribution(engine);
        const double noise = -scale * std::copysign(
            std::log(1.0 - 2.0 * std::abs(uniform)),
            uniform);

        return {
            raw_value,
            noise,
            std::clamp(raw_value + noise, lower_bound, upper_bound),
            true
        };
    }
};

} // namespace augmented_hub::privacy
