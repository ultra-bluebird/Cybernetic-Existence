#pragma once

#include <cmath>
#include <cstddef>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace augmented_hub::causal_discovery {

enum class EdgeStatus {
    RetainedCandidate,
    RemovedConditionalIndependence,
    InsufficientEvidence
};

struct ConditionalIndependenceResult {
    std::string source;
    std::string target;
    std::vector<std::string> conditioning_set;
    double p_value;
    double adjusted_p_value;
    EdgeStatus status;
};

inline EdgeStatus classify_edge(
    double adjusted_p_value,
    double alpha,
    std::size_t effective_sample_size,
    std::size_t minimum_effective_sample_size
) {
    if (!std::isfinite(adjusted_p_value)
        || !std::isfinite(alpha)
        || alpha <= 0.0
        || alpha >= 1.0) {
        throw std::invalid_argument("invalid conditional-independence thresholds");
    }

    if (effective_sample_size < minimum_effective_sample_size) {
        return EdgeStatus::InsufficientEvidence;
    }

    return adjusted_p_value > alpha
        ? EdgeStatus::RemovedConditionalIndependence
        : EdgeStatus::RetainedCandidate;
}

inline bool temporal_order_is_allowed(
    int source_time_order,
    int target_time_order
) {
    return source_time_order <= target_time_order;
}

inline std::pair<std::string, std::string> canonical_edge(
    std::string left,
    std::string right
) {
    if (left.empty() || right.empty()) {
        throw std::invalid_argument("edge variables must be non-empty");
    }

    return left < right
        ? std::make_pair(std::move(left), std::move(right))
        : std::make_pair(std::move(right), std::move(left));
}

}  // namespace augmented_hub::causal_discovery
