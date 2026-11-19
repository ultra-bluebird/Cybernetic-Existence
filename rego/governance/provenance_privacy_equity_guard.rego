package augmented_hub.governance.provenance_privacy_equity_guard

default allow_public_aggregate_release := false
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

provenance_complete {
    input.provenance.required_field_count > 0
    input.provenance.complete_field_count >= 0
    input.provenance.complete_field_count <= input.provenance.required_field_count
}

provenance_freshness_valid {
    valid_nonnegative(input.provenance.age)
    valid_nonnegative(input.provenance.age_decay_lambda)
    input.provenance.age_unit in {"hour", "day"}
    input.provenance.data_type in {
        "sensor_measurement",
        "laboratory_result",
        "public_dataset",
        "inspection_record",
        "community_observation",
        "model_output"
    }
}

provenance_confidence_valid {
    provenance_complete
    provenance_freshness_valid
    valid_unit_interval(input.provenance.confidence_score)
}

privacy_parameters_valid {
    valid_positive(input.privacy.epsilon)
    valid_nonnegative(input.privacy.delta)
    input.privacy.epsilon <= 0.5
    input.privacy.delta <= 0.000001
}

privacy_budget_available {
    input.privacy.epsilon_spent + input.privacy.epsilon <= input.privacy.epsilon_budget
    input.privacy.delta_spent + input.privacy.delta <= input.privacy.delta_budget
}

privacy_release_controls_valid {
    input.privacy.aggregate_only == true
    input.privacy.minimum_group_size_met == true
    input.privacy.noise_mechanism_documented == true
    input.privacy.utility_review_completed == true
    input.privacy.public_methodology_available == true
    input.privacy.accessible_explanation_available == true
    input.privacy.identifiable_data_included == false
    input.privacy.individual_profiling_performed == false
}

equity_inputs_valid {
    count(input.equity.zones) > 0

    every zone in input.equity.zones {
        valid_nonnegative(zone.service_gap)
        valid_positive(zone.service_target)
        valid_unit_interval(zone.weight)
    }

    abs(sum([zone.weight | zone := input.equity.zones[_]]) - 1.0) <= 0.000001
}

equity_service_floor_met {
    every zone in input.equity.zones {
        zone.normalized_gap <= input.policy.maximum_zone_equity_gap
    }
}

equity_residual_increased {
    input.equity.current_residual >
    input.equity.previous_residual + input.equity.tolerance
}

allow_public_aggregate_release {
    input.release.purpose_approved == true
    provenance_confidence_valid
    privacy_parameters_valid
    privacy_budget_available
    privacy_release_controls_valid
    equity_inputs_valid
    input.release.advisory_only == true
}

require_human_review {
    input.provenance.confidence_score < input.policy.minimum_provenance_confidence
}

require_human_review {
    equity_residual_increased
}

require_human_review {
    not equity_service_floor_met
}

require_human_review {
    input.privacy.minimum_group_size_met != true
}

deny_reason["provenance confidence requires complete-field and freshness validation"] {
    not provenance_confidence_valid
}

deny_reason["public sensitive-data release exceeds the epsilon privacy ceiling"] {
    input.privacy.epsilon > 0.5
}

deny_reason["public sensitive-data release exceeds the delta privacy ceiling"] {
    input.privacy.delta > 0.000001
}

deny_reason["the cumulative differential-privacy budget is exhausted"] {
    not privacy_budget_available
}

deny_reason["public aggregate release requires aggregation documented noise utility review and accessible methodology"] {
    not privacy_release_controls_valid
}

deny_reason["identifiable data and individual profiling are prohibited in aggregate release"] {
    input.privacy.identifiable_data_included == true
}

deny_reason["equity-zone gaps and weights must be valid and normalized"] {
    not equity_inputs_valid
}

deny_reason["a high service deficit in any zone requires review even when the overall residual improves"] {
    not equity_service_floor_met
}

deny_reason["public release is advisory-only and cannot authorize adverse decisions"] {
    input.release.advisory_only != true
}
