package augmentedhub.conformance.agent_capability_classification

default capability_decision := {
  "output_class": "blocked_by_policy",
  "effective_authority_level": 0,
  "reason_codes": ["no_valid_agent_capability_path"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
}

required_constraints := {
  "advisory_only",
  "local_first",
  "non_compensatory_gates",
  "minimum_disclosure",
  "purpose_limitation",
  "revocable_consent",
  "protected_record_preservation",
  "uncertainty_disclosure",
  "accessible_explanation",
  "appeal_path",
  "non_digital_escalation",
  "no_sensitive_inference",
  "no_person_scoring",
  "no_identity_resolution",
  "no_biometric_processing",
  "no_cybernetic_status_assessment",
  "no_automated_service_denial",
  "no_automated_actuation",
  "human_review_required",
}

required_prohibited_actions := {
  "physical_actuation",
  "service_denial",
  "service_eligibility_decision",
  "person_scoring",
  "identity_resolution",
  "biometric_identification",
  "health_inference",
  "disability_inference",
  "assistive_technology_inference",
  "augmentation_status_inference",
  "cybernetic_status_assessment",
  "behavioral_profiling",
  "surveillance",
  "raw_sensitive_data_export",
  "policy_promotion",
  "threshold_weakening",
  "self_capability_upgrade",
  "protected_record_deletion",
  "consent_override",
}

manifest_metadata_complete {
  input.agent_manifest_reference != ""
  input.agent_class != ""
  input.agent_version != ""
  input.model_or_runtime_version != ""
  input.policy_version != ""
  input.registry_version != ""
  input.semantic_version != ""
}

protected_configuration_valid {
  input.local_first
  not input.external_action_permitted
  not input.automated_actuation_permitted
  not input.automated_service_denial_permitted
  not input.identity_resolution_permitted
  not input.biometric_identification_permitted
  not input.cybernetic_status_assessment_permitted
  not input.individual_profiling_permitted
  input.accessible_explanation_required
  input.appeal_path_required
  input.non_digital_escalation_required
  input.maximum_authority_level <= 2
}

all_required_constraints_present {
  required_constraints == {constraint | constraint := input.safety_constraints[_]}
}

all_prohibited_actions_present {
  required_prohibited_actions == {action | action := input.prohibited_actions[_]}
}

capability_change_validated {
  input.capability_change_state == "validated"
  "policy_conformance_test" in input.review_requirements
  "scenario_regression_suite" in input.review_requirements
  "privacy_impact_review" in input.review_requirements
  "accessibility_impact_review" in input.review_requirements
  "rights_impact_review" in input.review_requirements
}

requested_action_prohibited {
  input.requested_action in required_prohibited_actions
}

capability_decision := {
  "output_class": "blocked_by_policy",
  "effective_authority_level": 0,
  "reason_codes": ["requested_action_prohibited_for_all_agent_classes"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  manifest_metadata_complete
  requested_action_prohibited
}

capability_decision := {
  "output_class": "blocked_by_policy",
  "effective_authority_level": 0,
  "reason_codes": ["agent_manifest_missing_required_constraints_or_prohibitions"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  manifest_metadata_complete
  not protected_configuration_valid
}

capability_decision := {
  "output_class": "blocked_by_policy",
  "effective_authority_level": 0,
  "reason_codes": ["agent_manifest_missing_required_constraints_or_prohibitions"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  manifest_metadata_complete
  protected_configuration_valid
  not all_required_constraints_present
}

capability_decision := {
  "output_class": "blocked_by_policy",
  "effective_authority_level": 0,
  "reason_codes": ["agent_manifest_missing_required_constraints_or_prohibitions"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  manifest_metadata_complete
  protected_configuration_valid
  all_required_constraints_present
  not all_prohibited_actions_present
}

capability_decision := {
  "output_class": "needs_review",
  "effective_authority_level": 1,
  "reason_codes": ["agent_capability_change_requires_validation_review"],
  "local_first": true,
  "external_action_authorized": false,
  "automated_actuation_authorized": false,
  "automated_service_denial_authorized": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  manifest_metadata_complete
  protected_configuration_valid
  all_required_constraints_present
  all_prohibited_actions_present
  input.capability_change_state != "validated"
}

capability_decision := {
  "output_class": "advisory_only",
  "effective_authority_level": input.maximum_authority_level,
  "reason_codes": [
    "agent_capability_manifest_validated",
    "effective_authority_limited_to_declared_manifest"
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
  manifest_metadata_complete
  protected_configuration_valid
  all_required_constraints_present
  all_prohibited_actions_present
  capability_change_validated
  not requested_action_prohibited
}
