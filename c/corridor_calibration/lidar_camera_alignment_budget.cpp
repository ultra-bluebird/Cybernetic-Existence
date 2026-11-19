#include <algorithm>
#include <cmath>
#include <cstdint>
#include <stdexcept>
#include <string>

namespace augmented_hub::corridor_calibration {

constexpr double kRadiansPerDegree = 0.01745329251994329576923690768489;
constexpr double kDegreesPerRadian = 57.295779513082320876798154814105;
constexpr double kMillimetersPerMeter = 1000.0;

struct AlignmentSpecification {
    double focal_length_pixels{};
    double representative_depth_meters{};
    double maximum_reprojection_error_pixels{};
    double baseline_detection_error_pixels{};
    double maximum_translation_error_meters{};
    double maximum_continuity_accuracy_error{};
};

struct AlignmentAssessment {
    double remaining_reprojection_budget_pixels{};
    double maximum_rotation_error_radians{};
    double maximum_rotation_error_degrees{};
    double maximum_translation_error_meters{};
    double projected_translation_error_pixels{};
    double estimated_total_reprojection_error_pixels{};
    double continuity_accuracy_error_bound{};
    bool meets_continuity_accuracy{};
};

void require_positive(const char* name, double value) {
    if (!std::isfinite(value) || value <= 0.0) {
        throw std::invalid_argument(std::string(name) + " must be finite and positive");
    }
}

void require_nonnegative(const char* name, double value) {
    if (!std::isfinite(value) || value < 0.0) {
        throw std::invalid_argument(std::string(name) + " must be finite and non-negative");
    }
}

double clamp_unit_interval(double value) {
    return std::clamp(value, 0.0, 1.0);
}

/*
 * Small-angle projection model:
 *
 * e_rotation_px ≈ f_px × |delta_theta_rad|
 * e_translation_px ≈ f_px × |delta_t_m| / z_m
 *
 * Total independent reprojection uncertainty:
 *
 * e_total_px = sqrt(
 *   e_baseline_px^2 +
 *   e_rotation_px^2 +
 *   e_translation_px^2
 * )
 *
 * The continuity-accuracy error bound is normalized by the configured
 * maximum accepted reprojection error:
 *
 * epsilon_continuity = min(1, e_total_px / e_max_px)
 *
 * This model is appropriate only for a declared representative depth and
 * small angular errors. It is a calibration-budget tool, not a substitute
 * for scene-specific validation.
 */
AlignmentAssessment assess_alignment_budget(
    const AlignmentSpecification& specification
) {
    require_positive("focal_length_pixels", specification.focal_length_pixels);
    require_positive(
        "representative_depth_meters",
        specification.representative_depth_meters
    );
    require_positive(
        "maximum_reprojection_error_pixels",
        specification.maximum_reprojection_error_pixels
    );
    require_nonnegative(
        "baseline_detection_error_pixels",
        specification.baseline_detection_error_pixels
    );
    require_nonnegative(
        "maximum_translation_error_meters",
        specification.maximum_translation_error_meters
    );
    require_positive(
        "maximum_continuity_accuracy_error",
        specification.maximum_continuity_accuracy_error
    );

    if (specification.baseline_detection_error_pixels
        >= specification.maximum_reprojection_error_pixels) {
        throw std::invalid_argument(
            "baseline detection error consumes the entire reprojection budget"
        );
    }

    const double projected_translation_error_pixels =
        specification.focal_length_pixels
        * specification.maximum_translation_error_meters
        / specification.representative_depth_meters;

    const double remaining_squared_budget =
        specification.maximum_reprojection_error_pixels
        * specification.maximum_reprojection_error_pixels
        - specification.baseline_detection_error_pixels
            * specification.baseline_detection_error_pixels
        - projected_translation_error_pixels
            * projected_translation_error_pixels;

    if (remaining_squared_budget < 0.0) {
        throw std::invalid_argument(
            "translation and baseline error consume the entire reprojection budget"
        );
    }

    const double remaining_reprojection_budget_pixels =
        std::sqrt(remaining_squared_budget);

    const double maximum_rotation_error_radians =
        remaining_reprojection_budget_pixels
        / specification.focal_length_pixels;

    const double maximum_rotation_error_degrees =
        maximum_rotation_error_radians * kDegreesPerRadian;

    const double estimated_total_reprojection_error_pixels =
        std::sqrt(
            specification.baseline_detection_error_pixels
                * specification.baseline_detection_error_pixels
            + projected_translation_error_pixels
                * projected_translation_error_pixels
            + remaining_reprojection_budget_pixels
                * remaining_reprojection_budget_pixels
        );

    const double continuity_accuracy_error_bound =
        clamp_unit_interval(
            estimated_total_reprojection_error_pixels
            / specification.maximum_reprojection_error_pixels
        );

    const bool meets_continuity_accuracy =
        continuity_accuracy_error_bound
        <= specification.maximum_continuity_accuracy_error;

    return AlignmentAssessment{
        .remaining_reprojection_budget_pixels =
            remaining_reprojection_budget_pixels,
        .maximum_rotation_error_radians = maximum_rotation_error_radians,
        .maximum_rotation_error_degrees = maximum_rotation_error_degrees,
        .maximum_translation_error_meters =
            specification.maximum_translation_error_meters,
        .projected_translation_error_pixels =
            projected_translation_error_pixels,
        .estimated_total_reprojection_error_pixels =
            estimated_total_reprojection_error_pixels,
        .continuity_accuracy_error_bound =
            continuity_accuracy_error_bound,
        .meets_continuity_accuracy = meets_continuity_accuracy,
    };
}

double maximum_translation_error_meters(
    double focal_length_pixels,
    double representative_depth_meters,
    double maximum_reprojection_error_pixels,
    double baseline_detection_error_pixels,
    double rotation_error_degrees
) {
    require_positive("focal_length_pixels", focal_length_pixels);
    require_positive("representative_depth_meters", representative_depth_meters);
    require_positive(
        "maximum_reprojection_error_pixels",
        maximum_reprojection_error_pixels
    );
    require_nonnegative(
        "baseline_detection_error_pixels",
        baseline_detection_error_pixels
    );
    require_nonnegative("rotation_error_degrees", rotation_error_degrees);

    const double rotation_error_radians =
        rotation_error_degrees * kRadiansPerDegree;

    const double projected_rotation_error_pixels =
        focal_length_pixels * rotation_error_radians;

    const double remaining_squared_budget =
        maximum_reprojection_error_pixels
        * maximum_reprojection_error_pixels
        - baseline_detection_error_pixels
            * baseline_detection_error_pixels
        - projected_rotation_error_pixels
            * projected_rotation_error_pixels;

    if (remaining_squared_budget < 0.0) {
        return 0.0;
    }

    return (
        representative_depth_meters
        * std::sqrt(remaining_squared_budget)
    ) / focal_length_pixels;
}

}  // namespace augmented_hub::corridor_calibration
