#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <stdexcept>
#include <vector>

namespace augmented_hub::telemetry {

struct DirectedEdge {
    std::size_t source{};
    std::size_t destination{};
    double logit{};
    bool physically_allowed{};
    bool source_quality_ok{};
    bool within_staleness_limit{};
};

struct AttentionResult {
    std::vector<double> weights{};
    bool valid{};
};

static bool finite(double value) {
    return std::isfinite(value);
}

AttentionResult masked_softmax_for_destination(
    const std::vector<DirectedEdge>& edges,
    std::size_t destination
) {
    std::vector<std::size_t> accepted;
    accepted.reserve(edges.size());

    double max_logit = -std::numeric_limits<double>::infinity();

    for (std::size_t index = 0; index < edges.size(); ++index) {
        const DirectedEdge& edge = edges[index];

        if (edge.destination != destination) {
            continue;
        }

        if (!edge.physically_allowed ||
            !edge.source_quality_ok ||
            !edge.within_staleness_limit ||
            !finite(edge.logit)) {
            continue;
        }

        accepted.push_back(index);
        max_logit = std::max(max_logit, edge.logit);
    }

    if (accepted.empty() || !finite(max_logit)) {
        return {{}, false};
    }

    std::vector<double> weights(edges.size(), 0.0);
    double denominator = 0.0;

    for (const std::size_t index : accepted) {
        const double shifted = edges[index].logit - max_logit;
        const double value = std::exp(shifted);

        if (!finite(value) || value < 0.0) {
            return {{}, false};
        }

        weights[index] = value;
        denominator += value;
    }

    if (!finite(denominator) || denominator <= 0.0) {
        return {{}, false};
    }

    double sum = 0.0;

    for (const std::size_t index : accepted) {
        weights[index] /= denominator;
        sum += weights[index];
    }

    if (std::abs(sum - 1.0) > 1.0e-10) {
        return {{}, false};
    }

    return {std::move(weights), true};
}

}  // namespace augmented_hub::telemetry
