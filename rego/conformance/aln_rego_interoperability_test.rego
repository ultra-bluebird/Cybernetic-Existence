package augmentedhub.conformance.aln_rego_interoperability_test

import data.augmentedhub.conformance.aln_rego_interoperability

valid_input := {
  "policy_version": "v1.0.0",
  "semantic_version": "v1.0.0",
  "metric_registry_version": "v1.0.0",
  "aln_semantic_version": "v1.0.0",
  "rego_semantic_version": "v1.0.0",
  "registry_semantic_version": "v1.0.0",
  "aln_source_reference": "policies/governance/research-agent-stability-invariants.aln",
  "rego_policy_reference": "rego/conformance/research_conformance.rego",
  "translation_artifact_reference": "schemas/governance/aln_rego_interoperability_protocol.schema.json",
  "translation_digest": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "aln_source_digest": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "rego_policy_digest": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "required_invariants": [
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
    "sensitive_inference_prohibition"
  ],
  "local_first": true,
  "external_action_permitted": false,
  "automated_actuation_permitted": false,
  "automated_service_denial_permitted": false,
  "biometric_identification_permitted": false,
  "cybernetic_status_assessment_permitted": false,
  "individual_profiling_permitted": false,
  "aln_rego_term_bindings": {
    "advisory_only": {
      "required_value": true,
      "rego_data_path": "data.aln_terms.advisory_only",
      "semantic_version": "v1.0.0"
    },
    "automated_actuation_permitted": {
      "required_value": false,
      "rego_data_path": "data.aln_terms.automated_actuation_permitted",
      "semantic_version": "v1.0.0"
    },
    "automated_service_denial_permitted": {
      "required_value": false,
      "rego_data_path": "data.aln_terms.automated_service_denial_permitted",
      "semantic_version": "v1.0.0"
    },
    "biometric_identification_permitted": {
      "required_value": false,
      "rego_data_path": "data.aln_terms.biometric_identification_permitted",
      "semantic_version": "v1.0.0"
    },
    "identity_resolution_permitted": {
      "required_value": false,
      "rego_data_path": "data.aln_terms.identity_resolution_permitted",
      "semantic_version": "v1.0.0"
    },
    "individual_profiling_permitted": {
      "required_value": false,
      "rego_data_path": "data.aln_terms.individual_profiling_permitted",
      "semantic_version": "v1.0.0"
    },
    "cybernetic_status_penalty_permitted": {
      "required_value": false,
      "rego_data_path": "data.aln_terms.cybernetic_status_penalty_permitted",
      "semantic_version": "v1.0.0"
    },
    "local_first": {
      "required_value": true,
      "rego_data_path": "data.aln_terms.local_first",
      "semantic_version": "v1.0.0"
    },
    "accessible_explanation_required": {
      "required_value": true,
      "rego_data_path": "data.aln_terms.accessible_explanation_required",
      "semantic_version": "v1.0.0"
    },
    "appeal_path_required": {
      "required_value": true,
      "rego_data_path": "data.aln_terms.appeal_path_required",
      "semantic_version": "v1.0.0"
    },
    "non_digital_escalation_required": {
      "required_value": true,
      "rego_data_path": "data.aln_terms.non_digital_escalation_required",
      "semantic_version": "v1.0.0"
    }
  },
  "rego_result": {
    "advisory_only": true,
    "external_action_authorized": false,
    "automated_actuation_authorized": false,
    "automated_service_denial_authorized": false,
    "identity_resolution_performed": false,
    "biometric_identification_performed": false,
    "cybernetic_status_assessment_performed": false,
    "individual_profiling_performed": false,
    "accessible_explanation_present": true,
    "appeal_path_present": true,
    "non_digital_escalation_present": true
  }
}

test_valid_bridge_is_advisory_only if {
  result := aln_rego_interoperability.bridge_decision with input as valid_input
  result.output_class == "advisory_only"
  result.translation_state == "validated"
}

test_semantic_version_drift_is_blocked if {
  invalid := object.union(valid_input, {
    "rego_semantic_version": "v2.0.0"
  })
  result := aln_rego_interoperability.bridge_decision with input as invalid
  result.output_class == "blocked_by_policy"
  result.translation_state == "semantic_drift_detected"
}

test_automated_service_denial_output_is_blocked if {
  invalid := object.union(valid_input, {
    "rego_result": object.union(valid_input.rego_result, {
      "automated_service_denial_authorized": true
    })
  })
  result := aln_rego_interoperability.bridge_decision with input as invalid
  result.output_class == "blocked_by_policy"
  "rego_output_violates_aln_protected_invariant" in result.reason_codes
}

test_cybernetic_status_penalty_term_drift_is_blocked if {
  invalid := object.union(valid_input, {
    "aln_rego_term_bindings": object.union(valid_input.aln_rego_term_bindings, {
      "cybernetic_status_penalty_permitted": {
        "required_value": true,
        "rego_data_path": "data.aln_terms.cybernetic_status_penalty_permitted",
        "semantic_version": "v1.0.0"
      }
    })
  })
  result := aln_rego_interoperability.bridge_decision with input as invalid
  result.output_class == "blocked_by_policy"
  result.translation_state == "semantic_drift_detected"
}
