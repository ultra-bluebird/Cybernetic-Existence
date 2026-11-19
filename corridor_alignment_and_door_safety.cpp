#include "corridor_alignment_and_door_safety.hpp"

#include <algorithm>
#include <cmath>
#include <limits>

namespace augmented_hub::safety {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

double euclidean_distance(const Point3& left, const Point3& right) noexcept {
    const double dx = left.x - right.x;
    const double dy = left.y - right.y;
    const double dz = left.z - right.z;

    return std::sqrt(dx * dx + dy * dy + dz * dz);
}

bool detects_occupancy(const DoorInputs& inputs) noexcept {
    return inputs.independent_presence_sensor_active ||
        inputs.safety_edge_active;
}

}  // namespace

std::expected<AlignmentAssessment, SafetyError> assess_corridor_alignment(
    const std::vector<PointCorrespondence>& correspondences,
    const AlignmentPolicy& policy,
    const AlignmentState& previous_state,
    double observed_at_seconds) {

    if (correspondences.empty()) {
        return std::unexpected(SafetyError::empty_correspondences);
    }

    if (!finite_nonnegative(policy.maximum_mean_residual_m) ||
        !finite_nonnegative(policy.maximum_residual_growth_ratio) ||
        policy.minimum_static_inliers == 0U ||
        !finite_unit_interval(policy.minimum_static_landmark_fraction) ||
        !finite_unit_interval(policy.maximum_occlusion_fraction) ||
        !finite_nonnegative(policy.maximum_recalibration_interval_seconds) ||
        !std::isfinite(observed_at_seconds)) {
        return std::unexpected(SafetyError::invalid_numeric_input);
    }

    if (previous_state.initialized &&
        observed_at_seconds <= previous_state.last_update_seconds) {
        return std::unexpected(SafetyError::invalid_time_order);
    }

    double residual_sum = 0.0;
    double squared_residual_sum = 0.0;
    std::size_t static_inlier_count = 0U;

    for (const auto& correspondence : correspondences) {
        if (!finite_unit_interval(correspondence.confidence)) {
            return std::unexpected(SafetyError::invalid_numeric_input);
        }

        const double residual = euclidean_distance(
            correspondence.source,
            correspondence.target);

        residual_sum += residual;
        squared_residual_sum += residual * residual;

        if (correspondence.static_landmark &&
            correspondence.confidence >= 0.80) {
            ++static_inlier_count;
        }
    }

    const double correspondence_count =
        static_cast<double>(correspondences.size());

    const double mean_residual =
        residual_sum / correspondence_count;

    const double root_mean_squared_residual =
        std::sqrt(squared_residual_sum / correspondence_count);

    const double static_landmark_fraction =
        static_cast<double>(static_inlier_count) / correspondence_count;

    const double occlusion_fraction =
        1.0 - static_landmark_fraction;

    const bool residual_exceeds_limit =
        mean_residual > policy.maximum_mean_residual_m;

    const bool residual_growth_exceeds_limit =
        previous_state.initialized &&
        previous_state.last_mean_residual_m > kEpsilon &&
        mean_residual >
            previous_state.last_mean_residual_m *
            policy.maximum_residual_growth_ratio;

    const bool static_evidence_insufficient =
        static_inlier_count < policy.minimum_static_inliers ||
        static_landmark_fraction <
            policy.minimum_static_landmark_fraction;

    const bool occlusion_exceeds_limit =
        occlusion_fraction > policy.maximum_occlusion_fraction;

    const bool recalibration_interval_expired =
        previous_state.initialized &&
        observed_at_seconds - previous_state.last_update_seconds >
            policy.maximum_recalibration_interval_seconds;

    const bool recalibration_triggered =
        residual_exceeds_limit ||
        residual_growth_exceeds_limit ||
        static_evidence_insufficient ||
        occlusion_exceeds_limit ||
        recalibration_interval_expired;

    const AlignmentStatus status =
        recalibration_triggered
            ? AlignmentStatus::recalibration_required
            : AlignmentStatus::aligned;

    return AlignmentAssessment{
        .mean_residual_m = mean_residual,
        .root_mean_squared_residual_m = root_mean_squared_residual,
        .static_inlier_count = static_inlier_count,
        .static_landmark_fraction = static_landmark_fraction,
        .occlusion_fraction = occlusion_fraction,
        .recalibration_triggered = recalibration_triggered,
        .status = status,
        .plain_language_explanation =
            recalibration_triggered
                ? "The corridor alignment requires recalibration because residual error, residual growth, static-landmark coverage, occlusion, or elapsed calibration interval exceeded its configured safety boundary. Existing evidence remains preserved for review."
                : "The corridor alignment satisfies the configured residual and static-landmark evidence limits for the current observation window."
    };
}

bool door_safety_invariant_holds(
    DoorState state,
    const DoorInputs& inputs) noexcept {

    if (inputs.emergency_stop_pressed &&
        state != DoorState::halted &&
        state != DoorState::open) {
        return false;
    }

    if (detects_occupancy(inputs) &&
        state == DoorState::closing) {
        return false;
    }

    return true;
}

std::expected<DoorTransition, SafetyError> transition_door_state(
    DoorState current_state,
    DoorEvent event,
    const DoorInputs& inputs) {

    if (!door_safety_invariant_holds(current_state, inputs) &&
        event != DoorEvent::emergency_stop_pressed &&
        event != DoorEvent::person_detected) {
        return std::unexpected(SafetyError::invalid_state_transition);
    }

    const bool occupancy_detected = detects_occupancy(inputs);

    if (inputs.emergency_stop_pressed ||
        event == DoorEvent::emergency_stop_pressed) {
        return DoorTransition{
            .previous_state = current_state,
            .next_state = DoorState::halted,
            .motion_authorized = false,
            .requires_review = true,
            .plain_language_explanation =
                "Emergency stop has priority over all classifier, timer, and normal door-control requests. Motion is halted and the controller requires an accountable reset procedure."
        };
    }

    if (event == DoorEvent::person_detected ||
        occupancy_detected) {
        return DoorTransition{
            .previous_state = current_state,
            .next_state = DoorState::open,
            .motion_authorized = current_state != DoorState::open,
            .requires_review = false,
            .plain_language_explanation =
                "Independent presence or safety-edge sensing detected an occupied doorway. Closing is inhibited and the controller opens or maintains an open state."
        };
    }

    if (event == DoorEvent::assist_mode_requested ||
        inputs.assist_mode_requested) {
        return DoorTransition{
            .previous_state = current_state,
            .next_state = DoorState::assist_mode,
            .motion_authorized = true,
            .requires_review = false,
            .plain_language_explanation =
                "Assist mode is active. The door remains governed by independent presence sensing, physical safety edges, emergency stop, and accessible control pathways."
        };
    }

    if (current_state == DoorState::halted) {
        if (event == DoorEvent::emergency_stop_released) {
            return DoorTransition{
                .previous_state = current_state,
                .next_state = DoorState::open,
                .motion_authorized = true,
                .requires_review = true,
                .plain_language_explanation =
                    "Emergency stop release moves the controller to an open safe state. A separate accountable reset and inspection workflow remains required before normal automatic closing resumes."
            };
        }

        return DoorTransition{
            .previous_state = current_state,
            .next_state = DoorState::halted,
            .motion_authorized = false,
            .requires_review = true,
            .plain_language_explanation =
                "The controller remains halted until the emergency-stop release path is completed."
        };
    }

    if (event == DoorEvent::request_open ||
        inputs.gesture_classifier_request_open) {
        return DoorTransition{
            .previous_state = current_state,
            .next_state = DoorState::opening,
            .motion_authorized = true,
            .requires_review = false,
            .plain_language_explanation =
                "An open request was accepted. Gesture recognition may request opening, but it cannot override physical safety controls or emergency stop."
        };
    }

    if ((event == DoorEvent::request_close ||
         inputs.gesture_classifier_request_close ||
         event == DoorEvent::timer_elapsed) &&
        !occupancy_detected) {
        return DoorTransition{
            .previous_state = current_state,
            .next_state = DoorState::closing,
            .motion_authorized = true,
            .requires_review = false,
            .plain_language_explanation =
                "A close request was accepted only because independent occupancy and safety-edge inputs report a clear doorway. Runtime monitoring continues during motion."
        };
    }

    return DoorTransition{
        .previous_state = current_state,
        .next_state = current_state,
        .motion_authorized = false,
        .requires_review = false,
        .plain_language_explanation =
            "No transition is authorized by the current event and independently monitored safety inputs."
    };
}

}  // namespace augmented_hub::safety
