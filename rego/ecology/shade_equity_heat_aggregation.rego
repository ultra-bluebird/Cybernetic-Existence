package augmented_hub.ecology.shade_equity_heat_aggregation

default allow_planning_index := false
default require_human_review := false

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

weights_sum_to_one(weights) {
    abs(sum(weights) - 1.0) <= 0.000001
}

all_weights_valid(weights) {
    every weight in weights {
        valid_unit_interval(weight)
    }
}

valid_shade_equity_input {
    is_number(input.shade_equity.usable_shade_hours)
    input.shade_equity.usable_shade_hours >= 0
    is_number(input.shade_equity.target_shade_hours)
    input.shade_equity.target_shade_hours > 0
    valid_unit_interval(input.shade_equity.accessibility_continuity)
    valid_unit_interval(input.shade_equity.maintenance_condition)
    valid_unit_interval(input.shade_equity.evidence_quality)
    input.shade_equity.planning_area_id != ""
}

valid_heat_aggregation_input {
    all_weights_valid(input.heat_aggregation.weights)
    weights_sum_to_one(input.heat_aggregation.weights)
    valid_unit_interval(input.heat_aggregation.surface_heat_proxy)
    valid_unit_interval(input.heat_aggregation.shade_deficit)
    valid_unit_interval(input.heat_aggregation.accessibility_barrier)
    valid_unit_interval(input.heat_aggregation.cooling_service_gap)
    valid_unit_interval(input.heat_aggregation.uncertainty_score)
    input.heat_aggregation.surface_temperature_is_proxy == true
    input.heat_aggregation.individual_profiling == false
    input.heat_aggregation.uses_identifiable_health_data == false
    input.heat_aggregation.uses_identifiable_income_data == false
    input.heat_aggregation.uses_identifiable_disability_data == false
    input.heat_aggregation.uses_cybernetic_status == false
    input.heat_aggregation.public_methodology_available == true
    input.heat_aggregation.accessible_explanation_available == true
    input.heat_aggregation.appeal_path_available == true
}

allow_planning_index {
    input.advisory_only == true
    valid_shade_equity_input
    valid_heat_aggregation_input
}

require_human_review {
    input.heat_aggregation.uncertainty_score > input.policy.maximum_uncertainty_for_public_priority
}

require_human_review {
    input.shade_equity.evidence_quality < input.policy.minimum_evidence_quality
}

require_human_review {
    input.shade_equity.accessibility_continuity < input.policy.minimum_accessibility_continuity
}

deny_reason["shade-equity calculations require a positive target shade-hours value"] {
    input.shade_equity.target_shade_hours <= 0
}

deny_reason["surface temperature must be labeled as a planning proxy"] {
    input.heat_aggregation.surface_temperature_is_proxy != true
}

deny_reason["heat-aggregation weights must sum to one"] {
    not weights_sum_to_one(input.heat_aggregation.weights)
}

deny_reason["heat-vulnerability planning cannot profile individuals"] {
    input.heat_aggregation.individual_profiling != false
}

deny_reason["identifiable health data cannot be used by the planning index"] {
    input.heat_aggregation.uses_identifiable_health_data != false
}

deny_reason["identifiable income data cannot be used by the planning index"] {
    input.heat_aggregation.uses_identifiable_income_data != false
}

deny_reason["identifiable disability data cannot be used by the planning index"] {
    input.heat_aggregation.uses_identifiable_disability_data != false
}

deny_reason["cybernetic or assistive status cannot be used by the planning index"] {
    input.heat_aggregation.uses_cybernetic_status != false
}

deny_reason["public planning outputs require an accessible explanation"] {
    input.heat_aggregation.accessible_explanation_available != true
}

deny_reason["public planning outputs require an appeal and correction path"] {
    input.heat_aggregation.appeal_path_available != true
}

deny_reason["the heat and shade system is advisory-only"] {
    input.advisory_only != true
}
