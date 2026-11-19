#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace augmented_hub {

struct RightsConstraints {
    bool non_discrimination_verified;
    bool privacy_preserved;
    bool accessibility_guaranteed;
    bool dignity_protected;
};

struct TechnicalConstraints {
    bool within_force_limit;
    bool within_speed_limit;
    bool within_energy_budget;
    bool safety_envelope_preserved;
};

struct FeasibilityDecision {
    bool admissible;
    std::vector<std::string> failed_rights;
    std::vector<std::string> failed_technical_constraints;
};

inline FeasibilityDecision evaluate_feasibility(
    const RightsConstraints& rights,
    const TechnicalConstraints& technical
) {
    std::vector<std::string> failed_rights;
    std::vector<std::string> failed_technical;

    if (!rights.non_discrimination_verified) {
        failed_rights.emplace_back("non_discrimination_verified");
    }

    if (!rights.privacy_preserved) {
        failed_rights.emplace_back("privacy_preserved");
    }

    if (!rights.accessibility_guaranteed) {
        failed_rights.emplace_back("accessibility_guaranteed");
    }

    if (!rights.dignity_protected) {
        failed_rights.emplace_back("dignity_protected");
    }

    if (!technical.within_force_limit) {
        failed_technical.emplace_back("within_force_limit");
    }

    if (!technical.within_speed_limit) {
        failed_technical.emplace_back("within_speed_limit");
    }

    if (!technical.within_energy_budget) {
        failed_technical.emplace_back("within_energy_budget");
    }

    if (!technical.safety_envelope_preserved) {
        failed_technical.emplace_back("safety_envelope_preserved");
    }

    return {
        failed_rights.empty() && failed_technical.empty(),
        std::move(failed_rights),
        std::move(failed_technical)
    };
}

struct DecisionUncertainty {
    std::vector<double> input_covariance;
    std::vector<double> decision_jacobian;
    std::size_t dimension;
};

inline double propagated_variance(
    const DecisionUncertainty& uncertainty
) {
    const std::size_t n = uncertainty.dimension;

    if (n == 0U) {
        throw std::invalid_argument("Uncertainty dimension must be positive.");
    }

    if (uncertainty.input_covariance.size() != n * n) {
        throw std::invalid_argument("Covariance matrix dimensions are invalid.");
    }

    if (uncertainty.decision_jacobian.size() != n) {
        throw std::invalid_argument("Decision Jacobian dimensions are invalid.");
    }

    double variance = 0.0;

    for (std::size_t row = 0; row < n; ++row) {
        for (std::size_t column = 0; column < n; ++column) {
            const double covariance =
                uncertainty.input_covariance[row * n + column];

            variance += uncertainty.decision_jacobian[row]
                * covariance
                * uncertainty.decision_jacobian[column];
        }
    }

    if (variance < -1e-12) {
        throw std::invalid_argument(
            "Propagated variance cannot be negative."
        );
    }

    return std::max(0.0, variance);
}

enum class ConservativeAction {
    Proceed,
    ExtendAccessWindow,
    ReduceSpeed,
    RequireHumanAssistance,
    FullManualMode
};

inline ConservativeAction select_conservative_action(
    double unsafe_probability_upper_bound,
    double safety_epsilon,
    bool manual_override_available
) {
    if (unsafe_probability_upper_bound < 0.0 ||
        unsafe_probability_upper_bound > 1.0 ||
        safety_epsilon < 0.0 ||
        safety_epsilon > 1.0) {
        throw std::invalid_argument(
            "Probability bounds must be within [0, 1]."
        );
    }

    if (!manual_override_available) {
        return ConservativeAction::FullManualMode;
    }

    if (unsafe_probability_upper_bound <= safety_epsilon) {
        return ConservativeAction::Proceed;
    }

    if (unsafe_probability_upper_bound <= 2.0 * safety_epsilon) {
        return ConservativeAction::ExtendAccessWindow;
    }

    if (unsafe_probability_upper_bound <= 4.0 * safety_epsilon) {
        return ConservativeAction::ReduceSpeed;
    }

    return ConservativeAction::RequireHumanAssistance;
}

struct GroupServiceLevel {
    std::string group_label;
    double service_level;
    std::size_t aggregate_sample_count;
};

struct FairnessAssessment {
    double service_fairness_ratio;
    bool meets_target;
    std::string least_served_group;
    std::string most_served_group;
};

inline FairnessAssessment assess_service_fairness(
    const std::vector<GroupServiceLevel>& groups,
    double target = 0.95,
    std::size_t minimum_aggregate_sample_count = 20U
) {
    if (groups.empty()) {
        throw std::invalid_argument(
            "At least one aggregate service group is required."
        );
    }

    if (target <= 0.0 || target > 1.0) {
        throw std::invalid_argument("Fairness target must be within (0, 1].");
    }

    double minimum_level = std::numeric_limits<double>::infinity();
    double maximum_level = 0.0;
    std::string least_served_group;
    std::string most_served_group;

    for (const auto& group : groups) {
        if (group.service_level < 0.0 || group.service_level > 1.0) {
            throw std::invalid_argument(
                "Service level must be within [0, 1]."
            );
        }

        if (group.aggregate_sample_count < minimum_aggregate_sample_count) {
            throw std::invalid_argument(
                "Group sample count is below privacy-preserving aggregation minimum."
            );
        }

        if (group.service_level < minimum_level) {
            minimum_level = group.service_level;
            least_served_group = group.group_label;
        }

        if (group.service_level > maximum_level) {
            maximum_level = group.service_level;
            most_served_group = group.group_label;
        }
    }

    const double ratio = maximum_level == 0.0
        ? 1.0
        : minimum_level / maximum_level;

    return {
        ratio,
        ratio >= target,
        least_served_group,
        most_served_group
    };
}

}  // namespace augmented_hub
