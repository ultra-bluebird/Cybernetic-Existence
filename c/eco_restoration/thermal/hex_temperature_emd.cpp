#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace augmented_hub::eco_restoration::thermal {

constexpr double kTolerance = 1e-12;

enum class FogState {
    Clear,
    HumanReviewPending,
    Withhold
};

enum class Status {
    AdvisoryCandidate,
    Withheld
};

struct Histogram {
    std::string map_id;
    std::string spatial_scheme_version;
    std::string variable_name;
    std::string unit;
    std::string aggregation_start_utc;
    std::string aggregation_end_utc;
    std::vector<double> bin_centers;
    std::vector<double> masses;
    bool source_valid{};
    bool consent_scope_valid{};
    bool retention_eligible{};
    bool identity_linkage_free{};
};

struct Result {
    double emd{};
    FogState fog_state{FogState::Withhold};
    Status status{Status::Withheld};
    std::string reason;
};

[[nodiscard]] bool finite(double value) {
    return std::isfinite(value);
}

void require_text(std::string_view name, const std::string& value) {
    if (value.empty()) {
        throw std::invalid_argument(std::string(name) + " must not be empty");
    }
}

[[nodiscard]] double total_mass(const std::vector<double>& masses) {
    double total = 0.0;

    for (double mass : masses) {
        if (!finite(mass) || mass < 0.0) {
            throw std::invalid_argument("histogram masses must be finite and non-negative");
        }

        total += mass;
    }

    return total;
}

void validate_histogram(const Histogram& histogram) {
    require_text("map_id", histogram.map_id);
    require_text("spatial_scheme_version", histogram.spatial_scheme_version);
    require_text("variable_name", histogram.variable_name);
    require_text("unit", histogram.unit);
    require_text("aggregation_start_utc", histogram.aggregation_start_utc);
    require_text("aggregation_end_utc", histogram.aggregation_end_utc);

    if (histogram.bin_centers.empty() ||
        histogram.bin_centers.size() != histogram.masses.size()) {
        throw std::invalid_argument("histogram bins and masses must be non-empty and equally sized");
    }

    for (std::size_t index = 0; index < histogram.bin_centers.size(); ++index) {
        if (!finite(histogram.bin_centers[index])) {
            throw std::invalid_argument("histogram bin centers must be finite");
        }

        if (index > 0 &&
            histogram.bin_centers[index] <= histogram.bin_centers[index - 1]) {
            throw std::invalid_argument("histogram bin centers must be strictly increasing");
        }
    }

    static_cast<void>(total_mass(histogram.masses));
}

[[nodiscard]] double one_dimensional_emd(
    const Histogram& left,
    const Histogram& right) {

    if (left.bin_centers.size() != right.bin_centers.size()) {
        throw std::invalid_argument("this bounded implementation requires aligned histogram bins");
    }

    for (std::size_t index = 0; index < left.bin_centers.size(); ++index) {
        if (std::abs(left.bin_centers[index] - right.bin_centers[index]) > kTolerance) {
            throw std::invalid_argument("this bounded implementation requires equal histogram bin centers");
        }
    }

    const double left_total = total_mass(left.masses);
    const double right_total = total_mass(right.masses);

    if (left_total <= kTolerance || right_total <= kTolerance) {
        throw std::invalid_argument("histogram total mass must be positive");
    }

    if (std::abs(left_total - right_total) > kTolerance) {
        throw std::invalid_argument("histograms must have equal total mass before EMD comparison");
    }

    double cumulative_difference = 0.0;
    double distance = 0.0;

    for (std::size_t index = 0; index + 1 < left.masses.size(); ++index) {
        cumulative_difference += left.masses[index] - right.masses[index];
        const double bin_width = left.bin_centers[index + 1] - left.bin_centers[index];
        distance += std::abs(cumulative_difference) * bin_width;
    }

    return distance;
}

[[nodiscard]] Result compare(
    const Histogram& left,
    const Histogram& right) {

    validate_histogram(left);
    validate_histogram(right);

    const bool eligible =
        left.source_valid &&
        left.consent_scope_valid &&
        left.retention_eligible &&
        right.source_valid &&
        right.consent_scope_valid &&
        right.retention_eligible;

    if (!eligible) {
        return {
            0.0,
            FogState::Withhold,
            Status::Withheld,
            "Source, consent, or retention eligibility is not valid."
        };
    }

    if (!left.identity_linkage_free || !right.identity_linkage_free) {
        return {
            0.0,
            FogState::Withhold,
            Status::Withheld,
            "Histogram comparison is withheld because identity-linkage protection is not satisfied."
        };
    }

    if (left.spatial_scheme_version != right.spatial_scheme_version ||
        left.variable_name != right.variable_name ||
        left.unit != right.unit ||
        left.aggregation_start_utc != right.aggregation_start_utc ||
        left.aggregation_end_utc != right.aggregation_end_utc) {
        return {
            0.0,
            FogState::HumanReviewPending,
            Status::Withheld,
            "Spatial scheme, variable, unit, or aggregation windows are not directly comparable."
        };
    }

    return {
        one_dimensional_emd(left, right),
        FogState::Clear,
        Status::AdvisoryCandidate,
        "Aggregate thermal-distribution displacement is available for human review."
    };
}

[[nodiscard]] std::string_view to_string(FogState value) {
    switch (value) {
        case FogState::Clear:
            return "clear";
        case FogState::HumanReviewPending:
            return "human_review_pending";
        case FogState::Withhold:
            return "withhold";
    }

    return "withhold";
}

[[nodiscard]] std::string_view to_string(Status value) {
    switch (value) {
        case Status::AdvisoryCandidate:
            return "advisory_candidate";
        case Status::Withheld:
            return "withheld";
    }

    return "withheld";
}

}  // namespace augmented_hub::eco_restoration::thermal

int main() {
    using namespace augmented_hub::eco_restoration::thermal;

    const Histogram baseline{
        "thermal-map-baseline",
        "phx-local-hex-v1",
        "surface_temperature",
        "degC",
        "2026-09-06T00:00:00Z",
        "2026-09-06T01:00:00Z",
        {30.0, 32.0, 34.0, 36.0},
        {2.0, 4.0, 3.0, 1.0},
        true,
        true,
        true,
        true
    };

    const Histogram comparison{
        "thermal-map-comparison",
        "phx-local-hex-v1",
        "surface_temperature",
        "degC",
        "2026-09-06T00:00:00Z",
        "2026-09-06T01:00:00Z",
        {30.0, 32.0, 34.0, 36.0},
        {1.0, 3.0, 4.0, 2.0},
        true,
        true,
        true,
        true
    };

    try {
        const Result result = compare(baseline, comparison);

        std::cout << std::fixed << std::setprecision(8)
                  << "{"
                  << "\"emd\":" << result.emd << ","
                  << "\"fog_state\":\"" << to_string(result.fog_state) << "\","
                  << "\"status\":\"" << to_string(result.status) << "\","
                  << "\"reason\":\"" << result.reason << "\""
                  << "}\n";

        return 0;
    } catch (const std::exception& error) {
        std::cerr << "{\"status\":\"withheld\",\"reason\":\""
                  << error.what() << "\"}\n";
        return 1;
    }
}
