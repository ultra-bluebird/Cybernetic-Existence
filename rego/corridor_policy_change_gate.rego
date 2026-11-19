package augmented_hub.corridor_policy_change_gate

default allow_change = false

default denial_reason = "Policy change is not admitted because required invariants, privacy controls, or review conditions have not been satisfied."

allow_change if {
    input.change_kind == "corridor_negotiation_policy"
    input.baseline_policy_version != ""
    input.candidate_policy_version != ""
    input.candidate_policy_version != input.baseline_policy_version
    formal_invariants_pass
    aggregate_only_privacy_contract_passes
    accessible_review_path_present
    human_oversight_present
    candidate_does_not_reduce_protected_access
    candidate_does_not_increase_unsafe_configuration_rate
    candidate_is_not_access_reducing
}

formal_invariants_pass if {
    required_invariant("pedestrian_first_precedence")
    required_invariant("no_forced_passage")
    required_invariant("category_non_discrimination")
    required_invariant("optional_urgency_non_penalty")
    required_invariant("autonomous_bot_fails_safe_under_uncertainty")
}

required_invariant(name) if {
    some invariant in input.formal_invariants
    invariant.name == name
    invariant.status == "passed"
    invariant.counterexample_count == 0
}

aggregate_only_privacy_contract_passes if {
    input.data_retention_class == "aggregate_only"
    input.personal_identity_absent == true
    input.health_data_absent == true
    input.biometric_data_absent == true
    input.neural_data_absent == true
    input.device_serial_numbers_absent == true
    input.individual_event_history_absent == true
}

accessible_review_path_present if {
    input.accessible_review_path_available == true
}

human_oversight_present if {
    input.human_oversight_required == true
}

candidate_does_not_reduce_protected_access if {
    input.comparison.mobility_priority_grant_difference >= 0
    input.comparison.pedestrian_priority_grant_difference >= 0
}

candidate_does_not_increase_unsafe_configuration_rate if {
    input.comparison.unsafe_configuration_ratio_difference <= 0
}

candidate_is_not_access_reducing if {
    input.candidate_requires_external_identity_certification == false
    input.candidate_requires_personal_telemetry == false
    input.candidate_penalizes_missing_optional_urgency == false
    input.candidate_allows_forced_passage == false
    input.candidate_allows_bot_precedence_over_protected_actor == false
}

governance_assessment := {
    "decision": decision,
    "baseline_policy_version": input.baseline_policy_version,
    "candidate_policy_version": input.candidate_policy_version,
    "formal_invariants_pass": formal_invariants_pass,
    "privacy_contract_passes": aggregate_only_privacy_contract_passes,
    "protected_access_preserved": candidate_does_not_reduce_protected_access,
    "unsafe_configuration_not_increased": candidate_does_not_increase_unsafe_configuration_rate,
    "accessible_review_path_available": input.accessible_review_path_available,
    "human_oversight_required": input.human_oversight_required,
    "reason": reason
}

decision := "allow_for_synthetic_comparison" if {
    allow_change
}

decision := "halt_for_remediation" if {
    not allow_change
}

reason := "Candidate policy is eligible for synthetic comparison because formal invariants, aggregate-only privacy controls, protected-access metrics, safety metrics, and review controls all pass." if {
    allow_change
}

reason := denial_reason if {
    not allow_change
}
