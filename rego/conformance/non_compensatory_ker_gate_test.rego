package augmentedhub.conformance.non_compensatory_ker_gate_test

import data.augmentedhub.conformance.non_compensatory_ker_gate

base_input := {
  "request": {
    "person_scoring_requested": false,
    "service_eligibility_requested": false,
    "identity_resolution_requested": false,
    "biometric_identification_requested": false,
    "cybernetic_status_assessment_requested": false,
    "automated_action_requested": false
  },
  "governance": {
    "advisory_only": true,
    "automated_actuation_permitted": false,
    "automated_service_denial_permitted": false,
    "biometric_identification_permitted": false,
    "identity_resolution_permitted": false,
    "cybernetic_status_penalty_permitted": false,
    "individual_profiling_permitted": false,
    "accessible_explanation_required": true,
    "appeal_path_required": true,
    "non_digital_escalation_required": true
  },
  "evidence": {
    "state": "observed",
    "purpose_compatible": true,
    "provenance_sufficient": true,
    "freshness_valid": true,
    "release_class": "local_only"
  },
  "thresholds": {
    "knowledge_minimum": 0.60,
    "ecological_or_evidence_minimum": 0.60,
    "harm_risk_maximum": 0.30
  },
  "gates": {
    "knowledge_factor": 0.90,
    "ecological_or_evidence_factor": 0.95,
    "harm_risk": 0.05,
    "accessibility_pass": true,
    "rights_alignment_pass": true,
    "consent_required": false,
    "consent_valid": false,
    "human_review_complete": true
  }
}

test_all_gates_pass_is_eligible_for_planning_use if {
  result := non_compensatory_ker_gate.decision with input as base_input
  result.output_class == "eligible_for_planning_use"
  result.eligible_for_planning_use
}

test_high_ecology_does_not_override_rights_failure if {
  candidate := object.union(base_input, {
    "gates": object.union(base_input.gates, {
      "ecological_or_evidence_factor": 1.0,
      "rights_alignment_pass": false
    })
  })

  result := non_compensatory_ker_gate.decision with input as candidate

  result.output_class == "needs_review"
  "rights_alignment_gate_failed_non_compensatory" in result.reason_codes
  not result.eligible_for_planning_use
}

test_high_knowledge_does_not_override_accessibility_failure if {
  candidate := object.union(base_input, {
    "gates": object.union(base_input.gates, {
      "knowledge_factor": 1.0,
      "accessibility_pass": false
    })
  })

  result := non_compensatory_ker_gate.decision with input as candidate

  result.output_class == "needs_review"
  "accessibility_gate_failed_non_compensatory" in result.reason_codes
  not result.eligible_for_planning_use
}

test_favorable_scores_do_not_override_invalid_consent if {
  candidate := object.union(base_input, {
    "gates": object.union(base_input.gates, {
      "consent_required": true,
      "consent_valid": false,
      "knowledge_factor": 1.0,
      "ecological_or_evidence_factor": 1.0,
      "harm_risk": 0.0
    })
  })

  result := non_compensatory_ker_gate.decision with input as candidate

  result.output_class == "needs_review"
  "consent_or_purpose_gate_failed_non_compensatory" in result.reason_codes
  not result.eligible_for_planning_use
}

test_prohibited_person_scoring_is_blocked_before_gate_calculation if {
  candidate := object.union(base_input, {
    "request": object.union(base_input.request, {
      "person_scoring_requested": true
    })
  })

  result := non_compensatory_ker_gate.decision with input as candidate

  result.output_class == "blocked_by_policy"
  "prohibited_person_level_or_consequential_request" in result.reason_codes
}

test_cybernetic_status_assessment_is_blocked_before_gate_calculation if {
  candidate := object.union(base_input, {
    "request": object.union(base_input.request, {
      "cybernetic_status_assessment_requested": true
    })
  })

  result := non_compensatory_ker_gate.decision with input as candidate

  result.output_class == "blocked_by_policy"
  "prohibited_person_level_or_consequential_request" in result.reason_codes
}
