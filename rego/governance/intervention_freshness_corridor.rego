package augmented_hub.governance.intervention_freshness_corridor

default allow_advisory_intervention := false
default require_human_review := false

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

valid_nonnegative(value) {
    is_number(value)
    value >= 0
}

valid_positive(value) {
    is_number(value)
    value > 0
}

residual_weights_valid {
    count(input.residual.weights) > 0

    every weight in input.residual.weights {
        valid_unit_interval(weight)
    }

    abs(sum(input.residual.weights) - 1.0) <= 0.000001
}

residual_values_valid {
    valid_unit_interval(input.residual.current_value)
    valid_unit_interval(input.residual.predicted_next_value)
    valid_nonnegative(input.residual.prediction_uncertainty)
    valid_nonnegative(input.residual.conservatism_multiplier)
    valid_nonnegative(input.residual.epsilon)
}

conservative_predicted_residual := input.residual.predicted_next_value +
    input.residual.conservatism_multiplier *
    input.residual.prediction_uncertainty

intervention_within_corridor {
    residual_weights_valid
    residual_values_valid
    conservative_predicted_residual <=
        input.residual.current_value + input.residual.epsilon
}

non_compensatory_rights_gate {
    valid_unit_interval(input.ker.knowledge_factor)
    valid_unit_interval(input.ker.eco_impact_value)
    valid_unit_interval(input.ker.harm_risk)
    valid_unit_interval(input.ker.accessibility_impact)
    valid_unit_interval(input.ker.rights_alignment)
    input.ker.knowledge_factor >= 0.60
    input.ker.eco_impact_value >= 0.50
    input.ker.harm_risk <= 0.45
    input.ker.accessibility_impact >= 0.70
    input.ker.rights_alignment >= 0.80
    input.governance.human_review_available == true
    input.governance.accessible_notice_available == true
    input.governance.accessible_explanation_available == true
    input.governance.appeal_path_available == true
    input.governance.advisory_only == true
    input.governance.physical_actuation_enabled == false
    input.governance.optional_telemetry_required == false
    input.governance.continuous_connectivity_required == false
}

freshness_input_valid {
    valid_nonnegative(input.freshness.age)
    valid_positive(input.freshness.tau)
    input.freshness.age_unit in {"minutes", "hours", "days"}
    valid_unit_interval(input.freshness.base_confidence)
    valid_unit_interval(input.freshness.operating_condition_quality)
    valid_unit_interval(input.freshness.effective_confidence)
}

freshness_requires_review {
    input.freshness.effective_confidence <
    input.policy.minimum_effective_confidence_for_current_use
}

require_human_review {
    not intervention_within_corridor
}

require_human_review {
    not non_compensatory_rights_gate
}

require_human_review {
    freshness_requires_review
}

allow_advisory_intervention {
    intervention_within_corridor
    non_compensatory_rights_gate
    freshness_input_valid
    not freshness_requires_review
}

deny_reason["residual weights must be normalized and sum to one"] {
    not residual_weights_valid
}

deny_reason["the predicted intervention residual exceeds the allowed corridor"] {
    not intervention_within_corridor
}

deny_reason["the intervention fails a non-compensatory safety accessibility or rights requirement"] {
    not non_compensatory_rights_gate
}

deny_reason["sensor freshness requires nonnegative age and a positive variable-specific decay interval"] {
    not freshness_input_valid
}

deny_reason["stale or low-quality evidence cannot support a current advisory recommendation without review"] {
    freshness_requires_review
}

deny_reason["the fixed epsilon value must be explicitly configured for each governed intervention"] {
    input.residual.epsilon != 0.02
}

deny_reason["continuous connectivity cannot be required for essential information or review access"] {
    input.governance.continuous_connectivity_required == true
}

deny_reason["this foundation permits advisory analysis and review, not physical actuation"] {
    input.governance.physical_actuation_enabled != false
}
