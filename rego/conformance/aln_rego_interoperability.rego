package augmentedhub.conformance.aln_rego_interoperability

default bridge_decision := {
  "output_class": "blocked_by_policy",
  "translation_state": "blocked_by_policy",
  "reason_codes": ["no_valid_aln_rego_interoperability_path"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
}

required_invariants := {
  "advisory_only",
  "no_automated_actuation",
  "no_automated_service_denial",
  "no_biometric_identification",
  "no_identity_resolution",
  "no_individual_profiling",
  "no_cybernetic_status_penalty",
  "self_assertion_for_protective_purposes",
  "local_first",
  "minimum_disclosure",
  "purpose_limitation",
  "revocable_consent",
  "protected_record_preservation",
  "accessible_explanation",
  "appeal_path",
  "non_digital_escalation",
  "non_compensatory_protected_gates",
  "uncertainty_propagation",
  "sensitive_inference_prohibition",
}

required_boolean_terms := {
  "advisory_only": true,
  "automated_actuation_permitted": false,
  "automated_service_denial_permitted": false,
  "biometric_identification_permitted": false,
  "identity_resolution_permitted": false,
  "individual_profiling_permitted": false,
  "cybernetic_status_penalty_permitted": false,
  "local_first": true,
  "accessible_explanation_required": true,
  "appeal_path_required": true,
  "non_digital_escalation_required": true,
}

bridge_metadata_complete {
  input.policy_version != ""
  input.semantic_version != ""
  input.metric_registry_version != ""
  input.aln_source_reference != ""
  input.rego_policy_reference != ""
  input.translation_artifact_reference != ""
  input.translation_digest != ""
  input.aln_source_digest != ""
  input.rego_policy_digest != ""
}

protected_configuration_valid {
  input.local_first
  not input.external_action_permitted
  not input.automated_actuation_permitted
  not input.automated_service_denial_permitted
  not input.biometric_identification_permitted
  not input.cybernetic_status_assessment_permitted
  not input.individual_profiling_permitted
}

all_required_invariants_present {
  required_invariants == {invariant | invariant := input.required_invariants[_]}
}

all_required_terms_bound {
  every name, expected in required_boolean_terms {
    input.aln_rego_term_bindings[name].required_value == expected
    input.aln_rego_term_bindings[name].rego_data_path != ""
    input.aln_rego_term_bindings[name].semantic_version == input.semantic_version
  }
}

semantic_versions_aligned {
  input.rego_semantic_version == input.semantic_version
  input.aln_semantic_version == input.semantic_version
  input.registry_semantic_version == input.metric_registry_version
}

rego_result_conforms_to_aln {
  input.rego_result.advisory_only
  not input.rego_result.external_action_authorized
  not input.rego_result.automated_actuation_authorized
  not input.rego_result.automated_service_denial_authorized
  not input.rego_result.identity_resolution_performed
  not input.rego_result.biometric_identification_performed
  not input.rego_result.cybernetic_status_assessment_performed
  not input.rego_result.individual_profiling_performed
  input.rego_result.accessible_explanation_present
  input.rego_result.appeal_path_present
  input.rego_result.non_digital_escalation_present
}

bridge_decision := {
  "output_class": "blocked_by_policy",
  "translation_state": "semantic_drift_detected",
  "reason_codes": ["aln_rego_semantic_version_mismatch"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  bridge_metadata_complete
  not semantic_versions_aligned
}

bridge_decision := {
  "output_class": "blocked_by_policy",
  "translation_state": "semantic_drift_detected",
  "reason_codes": ["aln_rego_required_invariants_missing_or_changed"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  bridge_metadata_complete
  semantic_versions_aligned
  not all_required_invariants_present
}

bridge_decision := {
  "output_class": "blocked_by_policy",
  "translation_state": "semantic_drift_detected",
  "reason_codes": ["aln_rego_term_binding_missing_or_incompatible"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  bridge_metadata_complete
  semantic_versions_aligned
  all_required_invariants_present
  not all_required_terms_bound
}

bridge_decision := {
  "output_class": "blocked_by_policy",
  "translation_state": "semantic_drift_detected",
  "reason_codes": ["rego_output_violates_aln_protected_invariant"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  bridge_metadata_complete
  semantic_versions_aligned
  all_required_invariants_present
  all_required_terms_bound
  not rego_result_conforms_to_aln
}

bridge_decision := {
  "output_class": "advisory_only",
  "translation_state": "validated",
  "reason_codes": [
    "aln_terms_bound_to_rego_data",
    "semantic_versions_aligned",
    "rego_output_conforms_to_aln_invariants"
  ],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  bridge_metadata_complete
  protected_configuration_valid
  semantic_versions_aligned
  all_required_invariants_present
  all_required_terms_bound
  rego_result_conforms_to_aln
}
