package augmented_hub.governance.ker_non_compensatory_gate

default allow_advisory_use := false
default require_human_review := false

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

positive_weight_total(weights) {
    total := sum(weights)
    total > 0
}

weights_sum_to_one(weights) {
    abs(sum(weights) - 1.0) <= 0.000001
}

all_weights_valid(weights) {
    every weight in weights {
        valid_unit_interval(weight)
    }
}

knowledge_quality_inputs_valid {
    count(input.knowledge.quality_scores) > 0
    count(input.knowledge.weights) == count(input.knowledge.quality_scores)
    all_weights_valid(input.knowledge.weights)
    weights_sum_to_one(input.knowledge.weights)

    every score in input.knowledge.quality_scores {
        valid_unit_interval(score)
    }
}

knowledge_has_zero_quality_component {
    score := input.knowledge.quality_scores[_]
    score == 0
}

knowledge_factor_admissible {
    knowledge_quality_inputs_valid
    not knowledge_has_zero_quality_component
    input.ker.knowledge_factor >= 0.60
}

ker_values_valid {
    valid_unit_interval(input.ker.knowledge_factor)
    valid_unit_interval(input.ker.eco_impact_value)
    valid_unit_interval(input.ker.harm_risk)
    valid_unit_interval(input.ker.accessibility_impact)
    valid_unit_interval(input.ker.rights_alignment)
}

non_compensatory_gate {
    ker_values_valid
    knowledge_factor_admissible
    input.ker.eco_impact_value >= 0.50
    input.ker.harm_risk <= 0.45
    input.ker.accessibility_impact >= 0.70
    input.ker.rights_alignment >= 0.80
}

rights_and_governance_gates {
    input.governance.advisory_only == true
    input.governance.human_review_available == true
    input.governance.accessible_explanation_available == true
    input.governance.appeal_path_available == true
    input.governance.data_minimization_confirmed == true
    input.governance.purpose_limitation_confirmed == true
    input.governance.retention_and_deletion_path_available == true
    input.governance.optional_telemetry_required == false
    input.governance.continuous_connectivity_required == false
    input.governance.biometric_identification_used == false
    input.governance.automated_service_denial == false
    input.governance.physical_actuation_enabled == false
}

allow_advisory_use {
    non_compensatory_gate
    rights_and_governance_gates
}

require_human_review {
    not non_compensatory_gate
}

require_human_review {
    input.knowledge.uncertainty_score > input.policy.maximum_uncertainty_for_advisory_use
}

deny_reason["all KER values must be finite scores within the unit interval"] {
    not ker_values_valid
}

deny_reason["knowledge-factor inputs must have matching quality-score and weight counts"] {
    count(input.knowledge.weights) != count(input.knowledge.quality_scores)
}

deny_reason["knowledge-factor weights must be within the unit interval and sum to one"] {
    not all_weights_valid(input.knowledge.weights)
}

deny_reason["a zero-quality evidence component produces zero knowledge confidence and requires review"] {
    knowledge_has_zero_quality_component
}

deny_reason["knowledge factor is below the advisory threshold"] {
    input.ker.knowledge_factor < 0.60
}

deny_reason["ecological impact value is below the advisory threshold"] {
    input.ker.eco_impact_value < 0.50
}

deny_reason["harm risk exceeds the non-compensatory threshold"] {
    input.ker.harm_risk > 0.45
}

deny_reason["accessibility impact is below the required threshold"] {
    input.ker.accessibility_impact < 0.70
}

deny_reason["rights alignment is below the required threshold"] {
    input.ker.rights_alignment < 0.80
}

deny_reason["advisory use requires a human review pathway"] {
    input.governance.human_review_available != true
}

deny_reason["advisory use requires an accessible explanation"] {
    input.governance.accessible_explanation_available != true
}

deny_reason["advisory use requires an appeal pathway"] {
    input.governance.appeal_path_available != true
}

deny_reason["data minimization and purpose limitation are mandatory"] {
    input.governance.data_minimization_confirmed != true
}

deny_reason["continuous connectivity and optional telemetry cannot be required"] {
    input.governance.continuous_connectivity_required == true
}

deny_reason["biometric identification is prohibited by this foundation"] {
    input.governance.biometric_identification_used == true
}

deny_reason["the foundation cannot automate service denial or physical actuation"] {
    input.governance.automated_service_denial == true
}

deny_reason["the foundation cannot automate service denial or physical actuation"] {
    input.governance.physical_actuation_enabled == true
}
