package augmented_hub.ecology.heat_cooling_bioswale

default allow_advisory_recommendation := false
default require_human_review := false

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

all_weights_valid(weights) {
    every weight in weights {
        valid_unit_interval(weight)
    }
}

weights_sum_to_one(weights) {
    total := sum(weights)
    abs(total - 1.0) <= 0.000001
}

heat_recovery_valid {
    all_weights_valid(input.heat_recovery.weights)
    weights_sum_to_one(input.heat_recovery.weights)
    valid_unit_interval(input.heat_recovery.albedo_gain)
    valid_unit_interval(input.heat_recovery.canopy_gain)
    valid_unit_interval(input.heat_recovery.evapotranspiration_gain)
    valid_unit_interval(input.heat_recovery.wind_corridor_gain)
    valid_unit_interval(input.heat_recovery.evidence_quality)
    valid_unit_interval(input.heat_recovery.accessibility_barrier_risk)
    input.heat_recovery.surface_temperature_is_proxy == true
    input.heat_recovery.air_temperature_validation_required == true
}

cooling_corridor_valid {
    count(input.cooling_corridor.segments) > 0

    every segment in input.cooling_corridor.segments {
        valid_unit_interval(segment.shade_fraction)
        valid_unit_interval(segment.accessibility_continuity)
        valid_unit_interval(segment.evidence_quality)
        is_number(segment.ambient_temperature_c)
        is_number(segment.segment_temperature_c)
        is_number(segment.target_temperature_c)
        segment.ambient_temperature_c > segment.target_temperature_c
    }
}

bioswale_efficiency_valid {
    is_number(input.bioswale.infiltration_rate_m_s)
    input.bioswale.infiltration_rate_m_s >= 0
    is_number(input.bioswale.infiltration_area_m2)
    input.bioswale.infiltration_area_m2 > 0
    is_number(input.bioswale.duration_s)
    input.bioswale.duration_s > 0
    is_number(input.bioswale.available_storage_m3)
    input.bioswale.available_storage_m3 >= 0
    is_number(input.bioswale.rainfall_depth_m)
    input.bioswale.rainfall_depth_m >= 0
    is_number(input.bioswale.drainage_area_m2)
    input.bioswale.drainage_area_m2 > 0
    valid_unit_interval(input.bioswale.runoff_coefficient)
    valid_unit_interval(input.bioswale.evidence_quality)
    is_number(input.bioswale.uncertainty_margin)
    input.bioswale.uncertainty_margin >= 0
}

allow_advisory_recommendation {
    input.advisory_only == true
    input.automatically_actuates_machinery == false
    input.accessible_explanation_available == true
    input.appeal_path_available == true
    heat_recovery_valid
    cooling_corridor_valid
    bioswale_efficiency_valid
}

require_human_review {
    input.heat_recovery.air_temperature_validation_available != true
}

require_human_review {
    input.cooling_corridor.minimum_segment_effectiveness < 0.70
}

require_human_review {
    input.bioswale.uncertainty_margin > input.policy.maximum_uncertainty_margin
}

require_human_review {
    input.bioswale.maintenance_status != "verified_current"
}

deny_reason["satellite surface temperature must remain labeled as a proxy"] {
    input.heat_recovery.surface_temperature_is_proxy != true
}

deny_reason["air-temperature validation is required before thermal claims are treated as calibrated"] {
    input.heat_recovery.air_temperature_validation_required != true
}

deny_reason["all heat-recovery weights must be within the unit interval"] {
    not all_weights_valid(input.heat_recovery.weights)
}

deny_reason["heat-recovery weights must sum to one"] {
    not weights_sum_to_one(input.heat_recovery.weights)
}

deny_reason["cooling-corridor inputs are incomplete or physically inconsistent"] {
    not cooling_corridor_valid
}

deny_reason["bioswale inputs must use dimensionally consistent volume terms"] {
    not bioswale_efficiency_valid
}

deny_reason["recommendations must remain advisory-only"] {
    input.advisory_only != true
}

deny_reason["automated machinery actuation is not permitted by this research model"] {
    input.automatically_actuates_machinery != false
}
