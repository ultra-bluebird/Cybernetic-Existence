#include <algorithm>
#include <cmath>
#include <cstddef>
#include <optional>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace augmentedhub::fog {

struct FogConfidence {
    std::string hex;
    int resolution;
    double unmodeled_confidence;

    FogConfidence(
        std::string hex_value,
        int resolution_value,
        double confidence_value
    )
        : hex(std::move(hex_value)),
          resolution(resolution_value),
          unmodeled_confidence(confidence_value) {
        if (hex.empty()) {
            throw std::invalid_argument("hex must not be empty");
        }
        if (resolution < 0 || resolution > 15) {
            throw std::invalid_argument("resolution must be in [0, 15]");
        }
        if (unmodeled_confidence < 0.0 || unmodeled_confidence > 1.0) {
            throw std::invalid_argument(
                "unmodeled confidence must be in [0, 1]"
            );
        }
    }
};

struct ParentChildComparison {
    std::string parent_hex;
    int parent_resolution;
    int child_resolution;
    double parent_unmodeled_confidence;
    double mean_child_unmodeled_confidence;
    double child_variance;
    double absolute_error;
    std::size_t observed_child_count;
};

struct ResolutionErrorSummary {
    double mean_absolute_error;
    double maximum_absolute_error;
    double mean_child_variance;
    std::size_t comparable_parent_count;
};

class H3Hierarchy {
public:
    virtual ~H3Hierarchy() = default;

    virtual std::optional<std::string> parent_of(
        const std::string& child_hex,
        int parent_resolution
    ) const = 0;
};

[[nodiscard]] ParentChildComparison compare_parent_to_children(
    const FogConfidence& parent,
    const std::vector<FogConfidence>& children
) {
    if (children.empty()) {
        throw std::invalid_argument("at least one child confidence is required");
    }

    const int child_resolution = children.front().resolution;
    if (child_resolution <= parent.resolution) {
        throw std::invalid_argument(
            "child resolution must be finer than parent resolution"
        );
    }

    for (const FogConfidence& child : children) {
        if (child.resolution != child_resolution) {
            throw std::invalid_argument(
                "all children must use the same child resolution"
            );
        }
    }

    double sum = 0.0;
    for (const FogConfidence& child : children) {
        sum += child.unmodeled_confidence;
    }

    const double mean = sum / static_cast<double>(children.size());

    double squared_difference_sum = 0.0;
    for (const FogConfidence& child : children) {
        const double difference = child.unmodeled_confidence - mean;
        squared_difference_sum += difference * difference;
    }

    const double variance =
        squared_difference_sum / static_cast<double>(children.size());

    return ParentChildComparison{
        .parent_hex = parent.hex,
        .parent_resolution = parent.resolution,
        .child_resolution = child_resolution,
        .parent_unmodeled_confidence = parent.unmodeled_confidence,
        .mean_child_unmodeled_confidence = mean,
        .child_variance = variance,
        .absolute_error = std::abs(parent.unmodeled_confidence - mean),
        .observed_child_count = children.size()
    };
}

[[nodiscard]] std::vector<ParentChildComparison> compare_resolution_levels(
    const std::vector<FogConfidence>& parents,
    const std::vector<FogConfidence>& children,
    const H3Hierarchy& hierarchy
) {
    std::unordered_map<std::string, std::vector<FogConfidence>> by_parent;

    for (const FogConfidence& child : children) {
        for (const FogConfidence& parent : parents) {
            if (child.resolution <= parent.resolution) {
                continue;
            }

            const std::optional<std::string> candidate_parent =
                hierarchy.parent_of(child.hex, parent.resolution);

            if (candidate_parent.has_value()
                && candidate_parent.value() == parent.hex) {
                by_parent[parent.hex].push_back(child);
                break;
            }
        }
    }

    std::vector<ParentChildComparison> comparisons;
    comparisons.reserve(parents.size());

    for (const FogConfidence& parent : parents) {
        const auto iterator = by_parent.find(parent.hex);
        if (iterator == by_parent.end() || iterator->second.empty()) {
            continue;
        }

        comparisons.push_back(
            compare_parent_to_children(parent, iterator->second)
        );
    }

    return comparisons;
}

[[nodiscard]] ResolutionErrorSummary summarize_resolution_error(
    const std::vector<ParentChildComparison>& comparisons
) {
    if (comparisons.empty()) {
        return ResolutionErrorSummary{
            .mean_absolute_error = 0.0,
            .maximum_absolute_error = 0.0,
            .mean_child_variance = 0.0,
            .comparable_parent_count = 0
        };
    }

    double error_sum = 0.0;
    double variance_sum = 0.0;
    double maximum_error = 0.0;

    for (const ParentChildComparison& comparison : comparisons) {
        error_sum += comparison.absolute_error;
        variance_sum += comparison.child_variance;
        maximum_error = std::max(maximum_error, comparison.absolute_error);
    }

    const double count = static_cast<double>(comparisons.size());

    return ResolutionErrorSummary{
        .mean_absolute_error = error_sum / count,
        .maximum_absolute_error = maximum_error,
        .mean_child_variance = variance_sum / count,
        .comparable_parent_count = comparisons.size()
    };
}

[[nodiscard]] bool should_flag_resolution_mismatch(
    const ParentChildComparison& comparison,
    double maximum_permitted_error,
    double maximum_permitted_child_variance
) {
    if (maximum_permitted_error < 0.0 || maximum_permitted_error > 1.0) {
        throw std::invalid_argument(
            "maximum permitted error must be in [0, 1]"
        );
    }
    if (maximum_permitted_child_variance < 0.0
        || maximum_permitted_child_variance > 0.25) {
        throw std::invalid_argument(
            "maximum permitted child variance must be in [0, 0.25]"
        );
    }

    return comparison.absolute_error > maximum_permitted_error
        || comparison.child_variance > maximum_permitted_child_variance;
}

}  // namespace augmentedhub::fog
