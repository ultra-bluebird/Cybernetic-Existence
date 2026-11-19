package augmentedhub.conformance.non_compensatory_ker_gate

default decision := {
  "output_class": "blocked_by_policy",
  "reason_codes": ["no_valid_non_compensatory_ker_path"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
}

valid_unit_interval(value) {
  is_number(value)
  value >= 0
  value <= 1
}

numeric_gate_inputs_valid {
  valid_unit_interval(input.gates.knowledge_factor)
  valid_unit_interval(input.gates.ecological_or_evidence_factor)
  valid_unit_interval(input.gates.harm_risk)
  valid_unit_interval(input.thresholds.knowledge_minimum)
  valid_unit_interval(input.thresholds.ecological_or_evidence_minimum)
  valid_unit_interval(input.thresholds.harm_risk_maximum)
}

protected_configuration_valid {
  input.governance.advisory_only
  not input.governance.automated_actuation_permitted
  not input.governance.automated_service_denial_permitted
  not input.governance.biometric_identification_permitted
  not input.governance.identity_resolution_permitted
  not input.governance.cybernetic_status_penalty_permitted
  not input.governance.individual_profiling_permitted
  input.governance.accessible_explanation_required
  input.governance.appeal_path_required
  input.governance.non_digital_escalation_required
}

prohibited_request {
  input.request.person_scoring_requested
}

prohibited_request {
  input.request.service_eligibility_requested
}

prohibited_request {
  input.request.identity_resolution_requested
}

prohibited_request {
  input.request.biometric_identification_requested
}

prohibited_request {
  input.request.cybernetic_status_assessment_requested
}

prohibited_request {
  input.request.automated_action_requested
}

evidence_invalid {
  input.evidence.state in {
    "unknown",
    "unverified",
    "insufficient_evidence",
    "conflicted",
  }
}

evidence_invalid {
  input.evidence.purpose_compatible == false
}

evidence_invalid {
  input.evidence.provenance_sufficient == false
}

evidence_invalid {
  input.evidence.freshness_valid == false
}

evidence_invalid {
  input.evidence.release_class == "never_release"
}

accessibility_failed {
  input.gates.accessibility_pass == false
}

rights_failed {
  input.gates.rights_alignment_pass == false
}

consent_failed {
  input.gates.consent_required
  input.gates.consent_valid == false
}

human_review_failed {
  input.gates.human_review_complete == false
}

knowledge_failed {
  input.gates.knowledge_factor < input.thresholds.knowledge_minimum
}

ecological_or_evidence_failed {
  input.gates.ecological_or_evidence_factor < input.thresholds.ecological_or_evidence_minimum
}

harm_failed {
  input.gates.harm_risk > input.thresholds.harm_risk_maximum
}

decision := {
  "output_class": "blocked_by_policy",
  "reason_codes": ["prohibited_person_level_or_consequential_request"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  prohibited_request
}

decision := {
  "output_class": "blocked_by_policy",
  "reason_codes": ["rights_constraint_kernel_not_satisfied"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_request
  not protected_configuration_valid
}

decision := {
  "output_class": "insufficient_evidence",
  "reason_codes": ["evidence_state_or_purpose_not_sufficient_for_declared_use"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_request
  protected_configuration_valid
  evidence_invalid
}

decision := {
  "output_class": "needs_review",
  "reason_codes": ["accessibility_gate_failed_non_compensatory"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_request
  protected_configuration_valid
  not evidence_invalid
  accessibility_failed
}

decision := {
  "output_class": "needs_review",
  "reason_codes": ["rights_alignment_gate_failed_non_compensatory"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_request
  protected_configuration_valid
  not evidence_invalid
  not accessibility_failed
  rights_failed
}

decision := {
  "output_class": "needs_review",
  "reason_codes": ["consent_or_purpose_gate_failed_non_compensatory"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_request
  protected_configuration_valid
  not evidence_invalid
  not accessibility_failed
  not rights_failed
  consent_failed
}

decision := {
  "output_class": "needs_review",
  "reason_codes": ["human_review_gate_failed_non_compensatory"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_request
  protected_configuration_valid
  not evidence_invalid
  not accessibility_failed
  not rights_failed
  not consent_failed
  human_review_failed
}

decision := {
  "output_class": "needs_review",
  "reason_codes": ["knowledge_factor_below_declared_minimum"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_request
  protected_configuration_valid
  not evidence_invalid
  not accessibility_failed
  not rights_failed
  not consent_failed
  not human_review_failed
  knowledge_failed
}

decision := {
  "output_class": "needs_review",
  "reason_codes": ["ecological_or_evidence_factor_below_declared_minimum"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_request
  protected_configuration_valid
  not evidence_invalid
  not accessibility_failed
  not rights_failed
  not consent_failed
  not human_review_failed
  not knowledge_failed
  ecological_or_evidence_failed
}

decision := {
  "output_class": "needs_review",
  "reason_codes": ["harm_risk_above_declared_maximum"],
  "eligible_for_planning_use": false,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_request
  protected_configuration_valid
  not evidence_invalid
  not accessibility_failed
  not rights_failed
  not consent_failed
  not human_review_failed
  not knowledge_failed
  not ecological_or_evidence_failed
  harm_failed
}

decision := {
  "output_class": "eligible_for_planning_use",
  "reason_codes": ["all_declared_non_compensatory_gates_pass"],
  "eligible_for_planning_use": true,
  "advisory_only": true,
  "automated_action_authorized": false,
  "automated_service_denial_authorized": false,
  "person_assessment_performed": false,
  "identity_resolution_performed": false,
  "biometric_identification_performed": false,
  "cybernetic_status_assessment_performed": false,
  "individual_profiling_performed": false,
} if {
  not prohibited_request
  protected_configuration_valid
  not evidence_invalid
  not accessibility_failed
  not rights_failed
  not consent_failed
  not human_review_failed
  not knowledge_failed
  not ecological_or_evidence_failed
  not harm_failed
  numeric_gate_inputs_valid
}
