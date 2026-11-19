package augmented_hub.sensors.energy_drift_fusion

default allow_advisory_result := false
default require_human_review := false

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

valid_positive_number(value) {
    is_number(value)
    value > 0
}

valid_nonnegative_number(value) {
    is_number(value)
    value >= 0
}

energy_conversion_valid {
    valid_unit_interval(input.energy.panel_efficiency)
    valid_unit_interval(input.energy.regulator_efficiency)
    valid_unit_interval(input.energy.thermal_loss_fraction)
    valid_nonnegative_number(input.energy.sleep_power_w)
    valid_nonnegative_number(input.energy.sleep_duration_s)
    valid_nonnegative_number(input.energy.harvested_energy_j)
    valid_nonnegative_number(input.energy.available_storage_energy_j)
    valid_nonnegative_number(input.energy.load_energy_j)
    valid_nonnegative_number(input.energy.reserve_energy_j)
}

energy_budget_sufficient {
    input.energy.harvested_energy_j +
    input.energy.available_storage_energy_j >=
    input.energy.load_energy_j +
    input.energy.reserve_energy_j
}

drift_detection_valid {
    valid_positive_number(input.drift.epsilon)
    valid_positive_number(input.drift.window_size)
    valid_positive_number(input.drift.z_threshold)
    input.drift.consecutive_window_count >= 2
    input.drift.timestamps_aligned == true
    input.drift.units_verified == true
    input.drift.context_check_required == true
}

persistent_drift_flag {
    abs(input.drift.current_robust_z_score) > input.drift.z_threshold
    abs(input.drift.previous_robust_z_score) > input.drift.z_threshold
}

fusion_input_valid {
    count(input.fusion.measurements) >= 2

    every measurement in input.fusion.measurements {
        valid_positive_number(measurement.value)
        valid_unit_interval(measurement.confidence)
        measurement.confidence < 1
        valid_nonnegative_number(measurement.uncertainty)
        measurement.timestamp_aligned == true
        measurement.unit == input.fusion.expected_unit
    }
}

fusion_requires_review {
    input.fusion.maximum_disagreement > input.fusion.allowed_disagreement
}

fusion_requires_review {
    input.fusion.operating_conditions_valid != true
}

fusion_requires_review {
    input.fusion.measurement_mode not in {
        "strictly_positive_scalar",
        "absolute_temperature_kelvin"
    }
}

require_human_review {
    persistent_drift_flag
}

require_human_review {
    not energy_budget_sufficient
}

require_human_review {
    fusion_requires_review
}

allow_advisory_result {
    input.advisory_only == true
    input.physical_actuation_enabled == false
    input.accessible_explanation_available == true
    input.appeal_or_correction_path_available == true
    energy_conversion_valid
    drift_detection_valid
    fusion_input_valid
}

deny_reason["energy conversion inputs must remain bounded and physically valid"] {
    not energy_conversion_valid
}

deny_reason["energy budget must include sleep-mode consumption"] {
    input.energy.sleep_power_w == null
}

deny_reason["a projected energy deficit requires duty-cycle or design review"] {
    not energy_budget_sufficient
}

deny_reason["drift detection requires aligned timestamps verified units and contextual review"] {
    not drift_detection_valid
}

deny_reason["fusion requires at least two aligned measurements with valid units"] {
    not fusion_input_valid
}

deny_reason["geometric fusion is limited to strictly positive quantities or absolute temperature"] {
    input.fusion.measurement_mode not in {
        "strictly_positive_scalar",
        "absolute_temperature_kelvin"
    }
}

deny_reason["sensor confidence must remain strictly below one to avoid infinite fusion weight"] {
    measurement := input.fusion.measurements[_]
    measurement.confidence >= 1
}

deny_reason["fused values with unresolved sensor disagreement require review"] {
    fusion_requires_review
}

deny_reason["this policy permits advisory analysis only"] {
    input.physical_actuation_enabled != false
}
