#ifndef AUGMENTED_HUB_CORRIDOR_ALIGNMENT_AND_DOOR_SAFETY_HPP
#define AUGMENTED_HUB_CORRIDOR_ALIGNMENT_AND_DOOR_SAFETY_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::safety {

enum class SafetyError {
    empty_correspondences,
    invalid_numeric_input,
    insufficient_inliers,
    invalid_time_order,
    invalid_state_transition
};

enum class AlignmentStatus {
    aligned,
    degraded_hold_for_review,
    recalibration_required
};

struct Point3 {
    double x{};
    double y{};
    double z{};
};

struct PointCorrespondence {
    Point3 source;
    Point3 target;
    double confidence{};
    bool static_landmark{};
};

struct AlignmentPolicy {
    double maximum_mean_residual_m{0.05};
    double maximum_residual_growth_ratio{1.50};
    std::size_t minimum_static_inliers{12};
    double minimum_static_landmark_fraction{0.60};
    double maximum_occlusion_fraction{0.40};
    double maximum_recalibration_interval_seconds{900.0};
};

struct AlignmentState {
    double last_mean_residual_m{};
    double last_update_seconds{};
    bool initialized{};
};

struct AlignmentAssessment {
    double mean_residual_m{};
    double root_mean_squared_residual_m{};
    std::size_t static_inlier_count{};
    double static_landmark_fraction{};
    double occlusion_fraction{};
    bool recalibration_triggered{};
    AlignmentStatus status{AlignmentStatus::degraded_hold_for_review};
    std::string plain_language_explanation;
};

enum class DoorState {
    open,
    closing,
    closed,
    opening,
    halted,
    assist_mode
};

enum class DoorEvent {
    request_open,
    request_close,
    person_detected,
    doorway_clear,
    emergency_stop_pressed,
    emergency_stop_released,
    assist_mode_requested,
    timer_elapsed
};

struct DoorInputs {
    bool independent_presence_sensor_active{};
    bool safety_edge_active{};
    bool emergency_stop_pressed{};
    bool assist_mode_requested{};
    bool gesture_classifier_request_open{};
    bool gesture_classifier_request_close{};
};

struct DoorTransition {
    DoorState previous_state{DoorState::closed};
    DoorState next_state{DoorState::closed};
    bool motion_authorized{};
    bool requires_review{};
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<AlignmentAssessment, SafetyError>
assess_corridor_alignment(
    const std::vector<PointCorrespondence>& correspondences,
    const AlignmentPolicy& policy,
    const AlignmentState& previous_state,
    double observed_at_seconds);

[[nodiscard]] std::expected<DoorTransition, SafetyError>
transition_door_state(
    DoorState current_state,
    DoorEvent event,
    const DoorInputs& inputs);

[[nodiscard]] bool door_safety_invariant_holds(
    DoorState state,
    const DoorInputs& inputs) noexcept;

}  // namespace augmented_hub::safety

#endif
