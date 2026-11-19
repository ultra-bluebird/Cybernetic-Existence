#include <array>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <limits>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace cyboquatic {

struct Axial {
    std::int64_t q{};
    std::int64_t r{};

    constexpr bool operator==(const Axial&) const = default;
};

struct Anchor {
    std::string anchor_id;
    std::string grid_id;
    std::string corridor_id;
    std::string basin_crs;
    std::int64_t revision{};
    Axial cell{};
};

struct SharedEdgeClaim {
    Anchor anchor;
    std::uint8_t edge_index{};
    std::string neighbor_anchor_id;
};

struct SegmentObservation {
    double measured_distance_m{};
    double predicted_distance_m{};
    double variance_m2{};
    double maximum_normalized_residual{};
};

struct ValidationResult {
    bool accepted{false};
    std::string reason;
    double normalized_residual{};
};

constexpr std::array<Axial, 6> kAxialDeltas{{
    {1, 0},
    {1, -1},
    {0, -1},
    {-1, 0},
    {-1, 1},
    {0, 1},
}};

constexpr bool valid_edge(const std::uint8_t edge) noexcept {
    return edge < kAxialDeltas.size();
}

constexpr std::uint8_t opposite_edge(const std::uint8_t edge) noexcept {
    return static_cast<std::uint8_t>((edge + 3U) % 6U);
}

constexpr Axial neighbor_cell(const Axial cell, const std::uint8_t edge) noexcept {
    const Axial delta = kAxialDeltas[edge];
    return {cell.q + delta.q, cell.r + delta.r};
}

bool finite_nonnegative(const double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_positive(const double value) noexcept {
    return std::isfinite(value) && value > 0.0;
}

ValidationResult validate_shared_edge(
    const SharedEdgeClaim& left,
    const SharedEdgeClaim& right
) {
    if (!valid_edge(left.edge_index) || !valid_edge(right.edge_index)) {
        return {false, "edge index is outside the closed interval [0, 5]", 0.0};
    }

    if (left.anchor.anchor_id.empty() || right.anchor.anchor_id.empty()) {
        return {false, "anchor identifiers must be non-empty", 0.0};
    }

    if (left.neighbor_anchor_id != right.anchor.anchor_id ||
        right.neighbor_anchor_id != left.anchor.anchor_id) {
        return {false, "neighbor identifiers are not reciprocal", 0.0};
    }

    if (left.anchor.grid_id != right.anchor.grid_id) {
        return {false, "claims use different grid identifiers", 0.0};
    }

    if (left.anchor.corridor_id != right.anchor.corridor_id) {
        return {false, "claims use different corridor identifiers", 0.0};
    }

    if (left.anchor.basin_crs != right.anchor.basin_crs) {
        return {false, "claims use different basin coordinate references", 0.0};
    }

    if (left.anchor.revision != right.anchor.revision) {
        return {false, "claims use different geometry revisions", 0.0};
    }

    if (right.edge_index != opposite_edge(left.edge_index)) {
        return {false, "edge indices are not opposite directions", 0.0};
    }

    if (neighbor_cell(left.anchor.cell, left.edge_index) != right.anchor.cell) {
        return {false, "axial cells are not neighbors in the asserted direction", 0.0};
    }

    if (neighbor_cell(right.anchor.cell, right.edge_index) != left.anchor.cell) {
        return {false, "reverse axial neighbor assertion does not hold", 0.0};
    }

    return {true, "reciprocal corridor edge is topologically consistent", 0.0};
}

ValidationResult calculate_whitened_residual(
    const std::vector<SegmentObservation>& segments,
    const double corridor_threshold
) {
    if (!finite_nonnegative(corridor_threshold)) {
        return {false, "corridor threshold must be finite and non-negative", 0.0};
    }

    if (segments.empty()) {
        return {false, "at least one segment observation is required", 0.0};
    }

    long double sum = 0.0L;

    for (const SegmentObservation& segment : segments) {
        if (!finite_nonnegative(segment.measured_distance_m) ||
            !finite_nonnegative(segment.predicted_distance_m) ||
            !finite_positive(segment.variance_m2) ||
            !finite_nonnegative(segment.maximum_normalized_residual)) {
            return {false, "segment input violates finite non-negative or positive-variance invariants", 0.0};
        }

        const long double error =
            static_cast<long double>(segment.measured_distance_m) -
            static_cast<long double>(segment.predicted_distance_m);

        const long double normalized_square =
            (error * error) / static_cast<long double>(segment.variance_m2);

        if (!std::isfinite(static_cast<double>(normalized_square))) {
            return {false, "normalized segment residual is non-finite", 0.0};
        }

        if (normalized_square >
            static_cast<long double>(segment.maximum_normalized_residual)) {
            return {
                false,
                "a segment exceeds its declared maximum normalized residual",
                static_cast<double>(normalized_square)
            };
        }

        sum += normalized_square;
    }

    const double residual = static_cast<double>(
        sum / static_cast<long double>(segments.size())
    );

    if (!std::isfinite(residual)) {
        return {false, "corridor residual is non-finite", 0.0};
    }

    if (residual > corridor_threshold) {
        return {false, "corridor residual exceeds the declared threshold", residual};
    }

    return {true, "corridor calibration residual is accepted", residual};
}

}  // namespace cyboquatic

int main() {
    using namespace cyboquatic;

    const SharedEdgeClaim west{
        .anchor = {
            .anchor_id = "phx-corridor-a",
            .grid_id = "phoenix-basin-axial-r1",
            .corridor_id = "north-drainage-corridor",
            .basin_crs = "local-basin-metre-grid-r1",
            .revision = 1,
            .cell = {17, -8},
        },
        .edge_index = 0,
        .neighbor_anchor_id = "phx-corridor-b",
    };

    const SharedEdgeClaim east{
        .anchor = {
            .anchor_id = "phx-corridor-b",
            .grid_id = "phoenix-basin-axial-r1",
            .corridor_id = "north-drainage-corridor",
            .basin_crs = "local-basin-metre-grid-r1",
            .revision = 1,
            .cell = {18, -8},
        },
        .edge_index = 3,
        .neighbor_anchor_id = "phx-corridor-a",
    };

    const ValidationResult topology = validate_shared_edge(west, east);
    if (!topology.accepted) {
        std::cerr << "topology rejected: " << topology.reason << '\n';
        return 1;
    }

    const std::vector<SegmentObservation> segments{
        {100.10, 100.00, 0.04, 9.00},
        {84.90, 85.00, 0.04, 9.00},
        {52.00, 51.95, 0.01, 9.00},
    };

    const ValidationResult calibration =
        calculate_whitened_residual(segments, 4.00);

    if (!calibration.accepted) {
        std::cerr << "calibration rejected: " << calibration.reason
                  << "; residual=" << calibration.normalized_residual << '\n';
        return 1;
    }

    std::cout << "accepted: " << topology.reason
              << "; residual=" << calibration.normalized_residual << '\n';
    return 0;
}
