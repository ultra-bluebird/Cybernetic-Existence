#include <array>
#include <cmath>
#include <cstddef>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

namespace cyboquatic {

struct Contribution {
    std::string observation_id;
    std::size_t component_index{};
    double normalized_observation{};
    double estimated_component{};
    double innovation_variance{};
};

struct ResidualResult {
    bool accepted{false};
    double residual_norm{};
    std::string reason;
};

bool finite_unit_interval(const double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

bool finite_positive(const double value) noexcept {
    return std::isfinite(value) && value > 0.0;
}

ResidualResult calculate_residual(
    const std::vector<Contribution>& contributions,
    const double maximum_residual_norm
) {
    if (!finite_positive(maximum_residual_norm)) {
        return {false, 0.0, "maximum residual norm must be finite and positive"};
    }

    if (contributions.empty()) {
        return {false, 0.0, "at least one contribution is required"};
    }

    long double normalized_sum = 0.0L;

    for (const Contribution& contribution : contributions) {
        if (contribution.observation_id.empty()) {
            return {false, 0.0, "contribution observation identifier must be non-empty"};
        }

        if (contribution.component_index > 2U) {
            return {false, 0.0, "component index must identify BOD, TSS, or CEC"};
        }

        if (!finite_unit_interval(contribution.normalized_observation) ||
            !finite_unit_interval(contribution.estimated_component) ||
            !finite_positive(contribution.innovation_variance)) {
            return {
                false,
                0.0,
                "contribution violates normalized-value or positive-variance invariants"
            };
        }

        const long double innovation =
            static_cast<long double>(contribution.normalized_observation) -
            static_cast<long double>(contribution.estimated_component);

        const long double squared_mahalanobis =
            (innovation * innovation) /
            static_cast<long double>(contribution.innovation_variance);

        if (!std::isfinite(static_cast<double>(squared_mahalanobis))) {
            return {false, 0.0, "non-finite normalized residual"};
        }

        normalized_sum += squared_mahalanobis;
    }

    const double residual_norm = std::sqrt(static_cast<double>(normalized_sum));

    if (!std::isfinite(residual_norm)) {
        return {false, 0.0, "non-finite residual norm"};
    }

    if (residual_norm > maximum_residual_norm) {
        return {
            false,
            residual_norm,
            "drainage-decay residual exceeds declared review threshold"
        };
    }

    return {
        true,
        residual_norm,
        "residual accepted; individual contributions remain independently auditable"
    };
}

}  // namespace cyboquatic

int main() {
    using namespace cyboquatic;

    const std::vector<Contribution> contributions{
        {"obs-bod-001", 0U, 0.42, 0.40, 0.010},
        {"obs-tss-001", 1U, 0.35, 0.37, 0.010},
        {"obs-cec-001", 2U, 0.61, 0.60, 0.015},
    };

    const ResidualResult result = calculate_residual(contributions, 3.0);

    if (!result.accepted) {
        std::cerr << "rejected: " << result.reason
                  << "; residual_norm=" << result.residual_norm << '\n';
        return 1;
    }

    std::cout << "accepted: " << result.reason
              << "; residual_norm=" << result.residual_norm << '\n';
    return 0;
}
