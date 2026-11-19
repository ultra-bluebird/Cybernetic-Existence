#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <string>
#include <vector>

namespace augmentedhub::fog {

struct WindowEvaluation {
    std::string window_id;
    double false_withhold_rate;
    double miss_rate;
    double compute_energy_joules;
    double coverage_ratio;
    bool calibration_supported;
};

struct WindowConstraints {
    double maximum_false_withhold_rate;
    double maximum_miss_rate;
    double minimum_coverage_ratio;
};

struct ParetoResult {
    std::vector<WindowEvaluation> feasible_candidates;
    std::vector<WindowEvaluation> non_dominated_candidates;
};

void validate_unit_interval(double value, const char* field) {
    if (!std::isfinite(value) || value < 0.0 || value > 1.0) {
        throw std::invalid_argument(
            std::string(field) + " must be finite and within [0, 1]"
        );
    }
}

void validate_window(const WindowEvaluation& item) {
    if (item.window_id.empty()) {
        throw std::invalid_argument("window_id must not be empty");
    }

    validate_unit_interval(
        item.false_withhold_rate,
        "false_withhold_rate"
    );
    validate_unit_interval(item.miss_rate, "miss_rate");
    validate_unit_interval(item.coverage_ratio, "coverage_ratio");

    if (!std::isfinite(item.compute_energy_joules)
        || item.compute_energy_joules < 0.0) {
        throw std::invalid_argument(
            "compute_energy_joules must be finite and non-negative"
        );
    }
}

[[nodiscard]] bool is_feasible(
    const WindowEvaluation& item,
    const WindowConstraints& constraints
) {
    return item.calibration_supported
        && item.false_withhold_rate
            <= constraints.maximum_false_withhold_rate
        && item.miss_rate <= constraints.maximum_miss_rate
        && item.coverage_ratio >= constraints.minimum_coverage_ratio;
}

[[nodiscard]] bool dominates(
    const WindowEvaluation& left,
    const WindowEvaluation& right
) {
    const bool no_worse =
        left.false_withhold_rate <= right.false_withhold_rate
        && left.miss_rate <= right.miss_rate
        && left.compute_energy_joules <= right.compute_energy_joules;

    const bool strictly_better =
        left.false_withhold_rate < right.false_withhold_rate
        || left.miss_rate < right.miss_rate
        || left.compute_energy_joules < right.compute_energy_joules;

    return no_worse && strictly_better;
}

[[nodiscard]] ParetoResult pareto_front(
    const std::vector<WindowEvaluation>& candidates,
    const WindowConstraints& constraints
) {
    validate_unit_interval(
        constraints.maximum_false_withhold_rate,
        "maximum_false_withhold_rate"
    );
    validate_unit_interval(
        constraints.maximum_miss_rate,
        "maximum_miss_rate"
    );
    validate_unit_interval(
        constraints.minimum_coverage_ratio,
        "minimum_coverage_ratio"
    );

    ParetoResult result;

    for (const WindowEvaluation& candidate : candidates) {
        validate_window(candidate);

        if (is_feasible(candidate, constraints)) {
            result.feasible_candidates.push_back(candidate);
        }
    }

    for (const WindowEvaluation& candidate : result.feasible_candidates) {
        bool dominated = false;

        for (const WindowEvaluation& alternative
            : result.feasible_candidates) {
            if (alternative.window_id != candidate.window_id
                && dominates(alternative, candidate)) {
                dominated = true;
                break;
            }
        }

        if (!dominated) {
            result.non_dominated_candidates.push_back(candidate);
        }
    }

    std::sort(
        result.non_dominated_candidates.begin(),
        result.non_dominated_candidates.end(),
        [](const WindowEvaluation& left,
           const WindowEvaluation& right) {
            return left.window_id < right.window_id;
        }
    );

    return result;
}

}  // namespace augmentedhub::fog
