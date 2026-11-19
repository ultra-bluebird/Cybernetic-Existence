package augmentedhub.conformance.scenario_test_generation

default scenario_validation := {
  "output_class": "blocked_by_policy",
  "reason_codes": ["scenario_does_not_meet_conformance_test_protocol"],
  "local_first": true,
  "external_network_required": false,
  "live_personal_data_permitted": false,
  "live_credentials_permitted": false,
}

protected_output_assertions_valid {
  input.expected_protected_assertions.advisory_only
  not input.expected_protected_assertions.automated_actuation_authorized
  not input.expected_protected_assertions.automated_service_denial_authorized
  not input.expected_protected_assertions.person_assessment_performed
  not input.expected_protected_assertions.identity_resolution_performed
  not input.expected_protected_assertions.biometric_identification_performed
  not input.expected_protected_assertions.cybernetic_status_assessment_performed
  not input.expected_protected_assertions.individual_profiling_performed
  not input.expected_protected_assertions.raw_sensitive_data_disclosed
}

explanation_requirements_valid {
  input.expected_explanation_requirements.accessible_explanation_present
  input.expected_explanation_requirements.reason_codes_present
  input.expected_explanation_requirements.action_boundary_present
}

review_requirements_valid {
  input.expected_review_requirements.appeal_path_present
  input.expected_review_requirements.non_digital_escalation_present
}

metadata_complete {
  input.scenario_reference != ""
  input.scenario_version != ""
  input.scenario_category != ""
  input.policy_version != ""
  input.registry_version != ""
  input.semantic_version != ""
  input.expected_output_class != ""
  count(input.expected_reason_codes) > 0
}

must_expect_block {
  input.scenario_category in {
    "person_scoring_attempt",
    "service_eligibility_attempt",
    "cybernetic_status_penalty_attempt",
    "proxy_discrimination",
    "direct_prompt_injection",
    "indirect_prompt_injection",
    "retrieval_poisoning",
    "policy_bundle_tampering",
    "receipt_replay",
    "commitment_substitution",
    "consent_replay",
    "emergency_pretext_misuse",
    "tool_authority_escalation",
    "sensitive_output_leakage",
    "conflict_erasure",
    "community_report_retaliation",
    "accessibility_regression",
    "energy_priority_inversion",
    "cross_domain_semantic_drift"
  }
}

scenario_validation := {
  "output_class": "blocked_by_policy",
  "reason_codes": ["protected_bypass_category_must_expect_blocked_by_policy"],
  "local_first": true,
  "external_network_required": false,
  "live_personal_data_permitted": false,
  "live_credentials_permitted": false,
} if {
  metadata_complete
  must_expect_block
  input.expected_output_class != "blocked_by_policy"
}

scenario_validation := {
  "output_class": "blocked_by_policy",
  "reason_codes": ["scenario_must_not_use_live_personal_data_credentials_or_network"],
  "local_first": true,
  "external_network_required": false,
  "live_personal_data_permitted": false,
  "live_credentials_permitted": false,
} if {
  metadata_complete
  input.local_first != true
}

scenario_validation := {
  "output_class": "blocked_by_policy",
  "reason_codes": ["scenario_must_not_use_live_personal_data_credentials_or_network"],
  "local_first": true,
  "external_network_required": false,
  "live_personal_data_permitted": false,
  "live_credentials_permitted": false,
} if {
  metadata_complete
  input.external_network_required
}

scenario_validation := {
  "output_class": "blocked_by_policy",
  "reason_codes": ["scenario_must_not_use_live_personal_data_credentials_or_network"],
  "local_first": true,
  "external_network_required": false,
  "live_personal_data_permitted": false,
  "live_credentials_permitted": false,
} if {
  metadata_complete
  input.live_personal_data_permitted
}

scenario_validation := {
  "output_class": "blocked_by_policy",
  "reason_codes": ["scenario_must_not_use_live_personal_data_credentials_or_network"],
  "local_first": true,
  "external_network_required": false,
  "live_personal_data_permitted": false,
  "live_credentials_permitted": false,
} if {
  metadata_complete
  input.live_credentials_permitted
}

scenario_validation := {
  "output_class": "advisory_only",
  "reason_codes": ["scenario_protocol_conformant"],
  "local_first": true,
  "external_network_required": false,
  "live_personal_data_permitted": false,
  "live_credentials_permitted": false,
} if {
  metadata_complete
  protected_output_assertions_valid
  explanation_requirements_valid
  review_requirements_valid
  input.local_first
  not input.external_network_required
  not input.live_personal_data_permitted
  not input.live_credentials_permitted
  not (must_expect_block and input.expected_output_class != "blocked_by_policy")
}
