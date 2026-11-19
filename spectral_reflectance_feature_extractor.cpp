#include <algorithm>
#include <cmath>
#include <cstddef>
#include <iomanip>
#include <iostream>
#include <limits>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace cyboquatic {

struct ReflectancePoint {
    double wavelength_nm{};
    double reflectance{};
};

struct FeatureVector {
    double mean_reflectance{};
    double standard_deviation{};
    double minimum_reflectance{};
    double maximum_reflectance{};
    double visible_slope{};
    double near_ir_slope{};
    double normalized_difference_index{};
};

bool finite_value(const double value) noexcept {
    return std::isfinite(value);
}

std::vector<std::string> split_csv(const std::string& line) {
    std::vector<std::string> fields;
    std::string field;
    bool quoted = false;

    for (std::size_t index = 0; index < line.size(); ++index) {
        const char character = line[index];

        if (character == '"' && quoted && index + 1U < line.size()
            && line[index + 1U] == '"') {
            field.push_back('"');
            ++index;
        } else if (character == '"') {
            quoted = !quoted;
        } else if (character == ',' && !quoted) {
            fields.push_back(field);
            field.clear();
        } else {
            field.push_back(character);
        }
    }

    if (quoted) {
        throw std::invalid_argument("unterminated quoted CSV field");
    }

    fields.push_back(field);
    return fields;
}

std::optional<double> parse_double(const std::string& value) {
    std::size_t consumed = 0U;

    try {
        const double parsed = std::stod(value, &consumed);
        if (consumed != value.size() || !finite_value(parsed)) {
            return std::nullopt;
        }
        return parsed;
    } catch (const std::exception&) {
        return std::nullopt;
    }
}

std::vector<ReflectancePoint> parse_reflectance_csv(std::istream& input) {
    std::vector<ReflectancePoint> points;
    std::string line;
    bool saw_header = false;

    while (std::getline(input, line)) {
        if (line.empty() || line.front() == '#') {
            continue;
        }

        const std::vector<std::string> fields = split_csv(line);
        if (!saw_header) {
            if (fields.size() != 2U
                || fields[0] != "wavelength_nm"
                || fields[1] != "reflectance") {
                throw std::invalid_argument(
                    "CSV header must be wavelength_nm,reflectance"
                );
            }
            saw_header = true;
            continue;
        }

        if (fields.size() != 2U) {
            throw std::invalid_argument("reflectance row must have exactly two columns");
        }

        const auto wavelength = parse_double(fields[0]);
        const auto reflectance = parse_double(fields[1]);

        if (!wavelength.has_value() || !reflectance.has_value()
            || *wavelength <= 0.0
            || *reflectance < 0.0
            || *reflectance > 1.0) {
            throw std::invalid_argument(
                "wavelength must be positive and reflectance must be in [0, 1]"
            );
        }

        points.push_back({*wavelength, *reflectance});
    }

    if (!saw_header || points.size() < 4U) {
        throw std::invalid_argument(
            "CSV must contain a valid header and at least four reflectance points"
        );
    }

    std::sort(
        points.begin(),
        points.end(),
        [](const ReflectancePoint& left, const ReflectancePoint& right) {
            return left.wavelength_nm < right.wavelength_nm;
        }
    );

    for (std::size_t index = 1U; index < points.size(); ++index) {
        if (points[index - 1U].wavelength_nm == points[index].wavelength_nm) {
            throw std::invalid_argument("wavelength values must be unique");
        }
    }

    return points;
}

double band_mean(
    const std::vector<ReflectancePoint>& points,
    const double minimum_wavelength_nm,
    const double maximum_wavelength_nm
) {
    double sum = 0.0;
    std::size_t count = 0U;

    for (const ReflectancePoint& point : points) {
        if (point.wavelength_nm >= minimum_wavelength_nm
            && point.wavelength_nm <= maximum_wavelength_nm) {
            sum += point.reflectance;
            ++count;
        }
    }

    if (count == 0U) {
        throw std::invalid_argument("required spectral band has no samples");
    }

    return sum / static_cast<double>(count);
}

double endpoint_slope(
    const std::vector<ReflectancePoint>& points,
    const double minimum_wavelength_nm,
    const double maximum_wavelength_nm
) {
    const ReflectancePoint* first = nullptr;
    const ReflectancePoint* last = nullptr;

    for (const ReflectancePoint& point : points) {
        if (point.wavelength_nm >= minimum_wavelength_nm
            && point.wavelength_nm <= maximum_wavelength_nm) {
            if (first == nullptr) {
                first = &point;
            }
            last = &point;
        }
    }

    if (first == nullptr || last == nullptr || first == last) {
        throw std::invalid_argument("required spectral band needs at least two samples");
    }

    return (last->reflectance - first->reflectance)
        / (last->wavelength_nm - first->wavelength_nm);
}

FeatureVector extract_features(const std::vector<ReflectancePoint>& points) {
    double sum = 0.0;
    double minimum = 1.0;
    double maximum = 0.0;

    for (const ReflectancePoint& point : points) {
        sum += point.reflectance;
        minimum = std::min(minimum, point.reflectance);
        maximum = std::max(maximum, point.reflectance);
    }

    const double mean = sum / static_cast<double>(points.size());

    double squared_sum = 0.0;
    for (const ReflectancePoint& point : points) {
        const double delta = point.reflectance - mean;
        squared_sum += delta * delta;
    }

    const double standard_deviation = std::sqrt(
        squared_sum / static_cast<double>(points.size())
    );

    const double red_mean = band_mean(points, 620.0, 690.0);
    const double near_ir_mean = band_mean(points, 760.0, 900.0);
    const double denominator = near_ir_mean + red_mean;

    if (denominator <= std::numeric_limits<double>::epsilon()) {
        throw std::invalid_argument(
            "normalized difference index denominator must be positive"
        );
    }

    return {
        .mean_reflectance = mean,
        .standard_deviation = standard_deviation,
        .minimum_reflectance = minimum,
        .maximum_reflectance = maximum,
        .visible_slope = endpoint_slope(points, 400.0, 700.0),
        .near_ir_slope = endpoint_slope(points, 760.0, 900.0),
        .normalized_difference_index = (near_ir_mean - red_mean) / denominator,
    };
}

}  // namespace cyboquatic

int main() {
    try {
        const std::vector<cyboquatic::ReflectancePoint> points =
            cyboquatic::parse_reflectance_csv(std::cin);

        const cyboquatic::FeatureVector features =
            cyboquatic::extract_features(points);

        std::cout << std::fixed << std::setprecision(8)
                  << "mean_reflectance=" << features.mean_reflectance << '\n'
                  << "standard_deviation=" << features.standard_deviation << '\n'
                  << "minimum_reflectance=" << features.minimum_reflectance << '\n'
                  << "maximum_reflectance=" << features.maximum_reflectance << '\n'
                  << "visible_slope=" << features.visible_slope << '\n'
                  << "near_ir_slope=" << features.near_ir_slope << '\n'
                  << "normalized_difference_index="
                  << features.normalized_difference_index << '\n';

        return 0;
    } catch (const std::exception& error) {
        std::cerr << "feature extraction rejected: " << error.what() << '\n';
        return 1;
    }
}
