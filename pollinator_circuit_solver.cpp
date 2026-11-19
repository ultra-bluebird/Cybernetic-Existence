#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace augmented_hub::pollinator {

struct Edge {
    std::size_t from{};
    std::size_t to{};
    double resistance{};
};

struct Network {
    std::vector<std::string> patch_labels;
    std::vector<Edge> edges;
};

struct ConnectivityResult {
    bool connected{false};
    double effective_resistance{std::numeric_limits<double>::infinity()};
    double connection_score{0.0};
    std::vector<double> node_voltage;
    std::vector<double> edge_current_magnitude;
    std::string reason;
};

class CircuitConnectivitySolver {
public:
    [[nodiscard]] ConnectivityResult solve(
        const Network& network,
        std::size_t source,
        std::size_t sink) const {

        validate_network(network, source, sink);

        const std::size_t node_count = network.patch_labels.size();
        std::vector<std::vector<double>> laplacian(
            node_count, std::vector<double>(node_count, 0.0));

        for (const Edge& edge : network.edges) {
            const double conductance = 1.0 / edge.resistance;

            laplacian[edge.from][edge.from] += conductance;
            laplacian[edge.to][edge.to] += conductance;
            laplacian[edge.from][edge.to] -= conductance;
            laplacian[edge.to][edge.from] -= conductance;
        }

        std::vector<double> injections(node_count, 0.0);
        injections[source] = 1.0;
        injections[sink] = -1.0;

        const std::vector<double> voltages =
            solve_with_grounded_sink(laplacian, injections, sink);

        if (voltages.empty()) {
            return {
                false,
                std::numeric_limits<double>::infinity(),
                0.0,
                {},
                {},
                "No solvable conductive path exists between the selected habitat patches."
            };
        }

        const double effective_resistance = voltages[source] - voltages[sink];
        if (!std::isfinite(effective_resistance) || effective_resistance <= epsilon_) {
            return {
                false,
                std::numeric_limits<double>::infinity(),
                0.0,
                {},
                {},
                "Effective resistance is invalid for the selected network."
            };
        }

        std::vector<double> currents;
        currents.reserve(network.edges.size());

        for (const Edge& edge : network.edges) {
            const double current =
                std::abs((voltages[edge.from] - voltages[edge.to]) / edge.resistance);
            currents.push_back(current);
        }

        return {
            true,
            effective_resistance,
            1.0 / effective_resistance,
            voltages,
            currents,
            "Connectivity was calculated using a unit-current circuit solution."
        };
    }

private:
    static constexpr double epsilon_ = 1e-12;

    static void validate_network(
        const Network& network,
        std::size_t source,
        std::size_t sink) {

        if (network.patch_labels.size() < 2U ||
            source >= network.patch_labels.size() ||
            sink >= network.patch_labels.size() ||
            source == sink) {
            throw std::invalid_argument(
                "At least two distinct, valid habitat-patch indices are required.");
        }

        for (const Edge& edge : network.edges) {
            if (edge.from >= network.patch_labels.size() ||
                edge.to >= network.patch_labels.size() ||
                edge.from == edge.to ||
                !std::isfinite(edge.resistance) ||
                edge.resistance <= 0.0) {
                throw std::invalid_argument(
                    "Each edge must join distinct valid nodes with positive finite resistance.");
            }
        }
    }

    static std::vector<double> solve_with_grounded_sink(
        const std::vector<std::vector<double>>& laplacian,
        const std::vector<double>& injections,
        std::size_t sink) {

        const std::size_t node_count = laplacian.size();
        const std::size_t reduced_count = node_count - 1U;

        std::vector<std::vector<double>> matrix(
            reduced_count, std::vector<double>(reduced_count + 1U, 0.0));

        auto reduced_index = [sink](std::size_t index) {
            return index < sink ? index : index - 1U;
        };

        for (std::size_t row = 0; row < node_count; ++row) {
            if (row == sink) {
                continue;
            }

            const std::size_t reduced_row = reduced_index(row);

            for (std::size_t column = 0; column < node_count; ++column) {
                if (column == sink) {
                    continue;
                }

                matrix[reduced_row][reduced_index(column)] = laplacian[row][column];
            }

            matrix[reduced_row][reduced_count] = injections[row];
        }

        for (std::size_t pivot = 0; pivot < reduced_count; ++pivot) {
            std::size_t best_row = pivot;

            for (std::size_t candidate = pivot + 1U;
                 candidate < reduced_count;
                 ++candidate) {
                if (std::abs(matrix[candidate][pivot]) >
                    std::abs(matrix[best_row][pivot])) {
                    best_row = candidate;
                }
            }

            if (std::abs(matrix[best_row][pivot]) <= epsilon_) {
                return {};
            }

            std::swap(matrix[pivot], matrix[best_row]);

            const double divisor = matrix[pivot][pivot];
            for (std::size_t column = pivot; column <= reduced_count; ++column) {
                matrix[pivot][column] /= divisor;
            }

            for (std::size_t row = 0; row < reduced_count; ++row) {
                if (row == pivot) {
                    continue;
                }

                const double factor = matrix[row][pivot];
                for (std::size_t column = pivot; column <= reduced_count; ++column) {
                    matrix[row][column] -= factor * matrix[pivot][column];
                }
            }
        }

        std::vector<double> voltages(node_count, 0.0);

        for (std::size_t node = 0; node < node_count; ++node) {
            if (node != sink) {
                voltages[node] = matrix[reduced_index(node)][reduced_count];
            }
        }

        return voltages;
    }
};

} // namespace augmented_hub::pollinator
