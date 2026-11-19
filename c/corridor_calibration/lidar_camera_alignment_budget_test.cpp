#include "lidar_camera_alignment_budget.cpp"

#include <cassert>
#include <cmath>

int main() {
    using namespace augmented_hub::corridor_calibration;

    const AlignmentSpecification specification{
        .focal_length_pixels = 1200.0,
        .representative_depth_meters = 10.0,
        .maximum_reprojection_error_pixels = 2.0,
        .baseline_detection_error_pixels = 0.8,
        .maximum_translation_error_meters = 0.005,
        .maximum_continuity_accuracy_error = 1.0,
    };

    const AlignmentAssessment assessment =
        assess_alignment_budget(specification);

    assert(std::abs(
        assessment.projected_translation_error_pixels - 0.6
    ) < 0.0001);

    assert(std::abs(
        assessment.remaining_reprojection_budget_pixels
        - std::sqrt(2.0 * 2.0 - 0.8 * 0.8 - 0.6 * 0.6)
    ) < 0.0001);

    assert(assessment.maximum_rotation_error_degrees > 0.07);
    assert(assessment.maximum_rotation_error_degrees < 0.09);
    assert(assessment.estimated_total_reprojection_error_pixels <= 2.0001);
    assert(assessment.meets_continuity_accuracy);

    const double translation_limit =
        maximum_translation_error_meters(
            1200.0,
            10.0,
            2.0,
            0.8,
            0.05
        );

    assert(translation_limit > 0.010);
    assert(translation_limit < 0.015);

    return 0;
}
