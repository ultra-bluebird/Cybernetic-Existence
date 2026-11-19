#ifndef AUGMENTED_HUB_ACCESSIBILITY_DEMAND_FIELD_HPP
#define AUGMENTED_HUB_ACCESSIBILITY_DEMAND_FIELD_HPP

#include <algorithm>
#include <cmath>
#include <expected>
#include <limits>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace augmented_hub::accessibility {

enum class DemandFieldError {
    empty_cells,
    invalid_h3_resolution,
    invalid_aggregation_count,
    non_finite_input,
    negative_input,
    duplicate_cell,
    insufficient_publication_threshold
};

struct HexCellDemandInput {
    std::string h3_cell;
    double centroid_x{};
    double centroid_y{};
    double population_density_per_km2{};
    double voluntary_aggregate_need_weight{};
    std::size_t aggregate_participant_count{};
};

struct DemandFieldPolicy {
    int h3_resolution{8};
    std::size_t minimum_aggregation_count{20};
    double gaussian_bandwidth_km{1.5};
    double publication_threshold{0.0};
};

struct HexCellDemandResult {
    std::string h3_cell;
    double demand_value{};
    bool publishable{};
    std::string plain_language_explanation;
};

inline bool finite_non_negative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

inline double gaussian_kernel(
    double source_x,
    double source_y,
    double target_x,
    double target_y,
    double bandwidth_km) noexcept {

    const double dx = source_x - target_x;
    const double dy = source_y - target_y;
    const double distance_squared = dx * dx + dy * dy;
    const double bandwidth_squared = bandwidth_km * bandwidth_km;

    return std::exp(-distance_squared / (2.0 * bandwidth_squared));
}

inline std::expected<std::vector<HexCellDemandResult>, DemandFieldError>
compute_accessibility_demand_field(
    const std::vector<HexCellDemandInput>& cells,
    const DemandFieldPolicy& policy) {

    if (cells.empty()) {
        return std::unexpected(DemandFieldError::empty_cells);
    }

    if (policy.h3_resolution != 8 ||
        policy.minimum_aggregation_count < 20 ||
        !finite_non_negative(policy.gaussian_bandwidth_km) ||
        policy.gaussian_bandwidth_km == 0.0 ||
        !finite_non_negative(policy.publication_threshold)) {
        return std::unexpected(DemandFieldError::invalid_h3_resolution);
    }

    std::vector<HexCellDemandResult> results;
    results.reserve(cells.size());

    for (std::size_t target_index = 0; target_index < cells.size(); ++target_index) {
        const auto& target = cells[target_index];

        if (target.h3_cell.empty() ||
            !finite_non_negative(target.centroid_x) ||
            !finite_non_negative(target.centroid_y) ||
            !finite_non_negative(target.population_density_per_km2) ||
            !finite_non_negative(target.voluntary_aggregate_need_weight)) {
            return std::unexpected(DemandFieldError::non_finite_input);
        }

        if (target.aggregate_participant_count < policy.minimum_aggregation_count) {
            return std::unexpected(DemandFieldError::invalid_aggregation_count);
        }

        for (std::size_t prior_index = 0; prior_index < target_index; ++prior_index) {
            if (cells[prior_index].h3_cell == target.h3_cell) {
                return std::unexpected(DemandFieldError::duplicate_cell);
            }
        }

        double demand = 0.0;

        for (const auto& source : cells) {
            if (source.aggregate_participant_count < policy.minimum_aggregation_count) {
                return std::unexpected(DemandFieldError::invalid_aggregation_count);
            }

            const double source_density =
                source.population_density_per_km2 *
                source.voluntary_aggregate_need_weight;

            demand += source_density * gaussian_kernel(
                source.centroid_x,
                source.centroid_y,
                target.centroid_x,
                target.centroid_y,
                policy.gaussian_bandwidth_km);
        }

        const bool publishable = demand >= policy.publication_threshold;

        results.push_back(HexCellDemandResult{
            .h3_cell = target.h3_cell,
            .demand_value = demand,
            .publishable = publishable,
            .plain_language_explanation =
                publishable
                    ? "This aggregate hex-cell demand estimate supports accessibility infrastructure planning. It contains no individual identity, augmentation, diagnostic, or device information."
                    : "This aggregate estimate remains below the publication threshold and is retained for protected planning review only."
        });
    }

    return results;
}

}  // namespace augmented_hub::accessibility

#endif
