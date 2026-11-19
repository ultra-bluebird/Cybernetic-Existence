package augmented_hub.accessibility.sensor_door_navigation_guard

default allow_advisory_assessment := false
default require_human_review := false
default route_valid := false

valid_nonnegative_number(value) {
    is_number(value)
    value >= 0
}

valid_positive_number(value) {
    is_number(value)
    value > 0
}

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

sensor_residual := abs(input.sensor.primary_reading - input.sensor.reference_reading) / max([
    abs(input.sensor.primary_reading),
    abs(input.sensor.reference_reading),
    input.sensor.epsilon
])

sensor_disagreement {
    abs(input.sensor.primary_reading - input.sensor.reference_reading) >
    input.sensor.absolute_tolerance
}

sensor_disagreement {
    sensor_residual > input.sensor.relative_tolerance
}

three_consecutive_sensor_disagreements {
    input.sensor.current_disagreement == true
    input.sensor.previous_disagreement == true
    input.sensor.two_samples_ago_disagreement == true
}

door_buffer_valid {
    valid_nonnegative_number(input.door.person_distance_m)
    valid_nonnegative_number(input.door.person_speed_m_s)
    valid_nonnegative_number(input.door.reaction_time_s)
    valid_nonnegative_number(input.door.door_acceleration_m_s2)
    valid_nonnegative_number(input.door.open_time_s)
    valid_nonnegative_number(input.door.safety_buffer_m)
    input.door.safety_buffer_m >= 0.3
}

door_required_distance_m := (
    input.door.person_speed_m_s * input.door.reaction_time_s +
    (input.door.door_acceleration_m_s2 * input.door.open_time_s *
        input.door.open_time_s) / 2 +
    input.door.safety_buffer_m
)

door_assessment_requires_review {
    door_buffer_valid
    input.door.person_distance_m < door_required_distance_m
}

door_assessment_requires_review {
    input.door.certified_hardware_configuration_verified != true
}

door_assessment_requires_review {
    input.door.accessible_manual_fallback_available != true
}

door_assessment_requires_review {
    input.door.presence_sensor_coverage_verified != true
}

width_clearance_m := input.navigation.path_width_m - input.navigation.bot_width_m - input.navigation.width_buffer_m

height_clearance_m := input.navigation.clear_height_m - input.navigation.bot_height_m - input.navigation.height_buffer_m

route_valid {
    valid_positive_number(input.navigation.path_width_m)
    valid_positive_number(input.navigation.clear_height_m)
    valid_nonnegative_number(input.navigation.bot_width_m)
    valid_nonnegative_number(input.navigation.bot_height_m)
    valid_nonnegative_number(input.navigation.width_buffer_m)
    valid_nonnegative_number(input.navigation.height_buffer_m)
    valid_nonnegative_number(input.navigation.dynamic_obstacle_uncertainty_m)
    valid_nonnegative_number(input.navigation.maximum_obstacle_uncertainty_m)
    width_clearance_m >= 0
    height_clearance_m >= 0
    input.navigation.dynamic_obstacle_uncertainty_m <=
        input.navigation.maximum_obstacle_uncertainty_m
    input.navigation.human_access_priority == true
    input.navigation.physical_actuation_enabled == false
}

require_human_review {
    three_consecutive_sensor_disagreements
}

require_human_review {
    sensor_disagreement
}

require_human_review {
    door_assessment_requires_review
}

require_human_review {
    not route_valid
}

allow_advisory_assessment {
    input.advisory_only == true
    input.automatically_controls_door == false
    input.navigation.physical_actuation_enabled == false
    input.accessible_explanation_available == true
    input.appeal_or_correction_path_available == true
}

deny_reason["sensor readings must be time-aligned and use the same units before comparison"] {
    input.sensor.time_aligned != true
}

deny_reason["sensor epsilon must be positive"] {
    input.sensor.epsilon <= 0
}

deny_reason["automatic-door guidance remains advisory and cannot control the door"] {
    input.automatically_controls_door != false
}

deny_reason["door support options may not require disability or device disclosure"] {
    input.door.requires_disability_disclosure == true
}

deny_reason["door support options may not require cybernetic or assistive-device disclosure"] {
    input.door.requires_integration_disclosure == true
}

deny_reason["navigation corridors are invalid when width or height clearance is negative"] {
    not route_valid
}

deny_reason["navigation systems must give people priority over bot efficiency"] {
    input.navigation.human_access_priority != true
}

deny_reason["this foundation permits navigation simulation and advisory review only"] {
    input.navigation.physical_actuation_enabled != false
}
