package augmentedhub.conformance.automation_safety_margin

default decision := {
  "automation_state": "fail_safe_mode",
  "reason_codes": ["no_safe_conformance_path"],
  "requires_human_review": true,
  "essential_service_continuity_required": true,
}

valid_unit_interval(value) {
  is_number(value)
  value >= 0
  value <= 1
}

per_condition_evidence_complete {
  every condition in input.conditions {
    condition.observation_present
    condition.safe_boundary_present
    condition.design_distance_present
    condition.distance_function_declared
    valid_unit_interval(condition.uncertainty)
    valid_unit_interval(condition.severity)
  }
}

protected_gates_pass {
  input.gates.accessibility_pass
  input.gates.rights_alignment_pass
  input.gates.human_review_complete
  not input.gates.consent_required
}

protected_gates_pass {
  input.gates.accessibility_pass
  input.gates.rights_alignment_pass
  input.gates.human_review_complete
  input.gates.consent_required
  input.gates.consent_valid
}

human_proximity_unknown {
  input.human_proximity_state == "unknown"
}

human_in_protective_zone {
  input.human_proximity_state == "protective_zone"
}

critical_condition_failed {
  some condition in input.conditions
  condition.margin <= 0
}

insufficient_safety_evidence {
  not per_condition_evidence_complete
}

decision := {
  "automation_state": "fail_safe_mode",
  "reason_codes": ["insufficient_safety_evidence"],
  "requires_human_review": true,
  "essential_service_continuity_required": true,
} if {
  insufficient_safety_evidence
}

decision := {
  "automation_state": "fail_safe_mode",
  "reason_codes": ["human_proximity_unknown_for_hazardous_action"],
  "requires_human_review": true,
  "essential_service_continuity_required": true,
} if {
  not insufficient_safety_evidence
  input.hazardous_action
  human_proximity_unknown
}

decision := {
  "automation_state": "fail_safe_mode",
  "reason_codes": ["critical_condition_at_or_beyond_safety_boundary"],
  "requires_human_review": true,
  "essential_service_continuity_required": true,
} if {
  not insufficient_safety_evidence
  critical_condition_failed
}

decision := {
  "automation_state": "reduce_automation",
  "reason_codes": ["person_in_protective_zone"],
  "requires_human_review": true,
  "essential_service_continuity_required": true,
} if {
  not insufficient_safety_evidence
  not critical_condition_failed
  human_in_protective_zone
}

decision := {
  "automation_state": "reduce_automation",
  "reason_codes": ["protected_margin_below_reduce_automation_threshold"],
  "requires_human_review": true,
  "essential_service_continuity_required": true,
} if {
  not insufficient_safety_evidence
  not critical_condition_failed
  not human_proximity_unknown
  not human_in_protective_zone
  input.asmi_protected >= 0.1
  input.asmi_protected < 0.3
}

decision := {
  "automation_state": "bounded_automation_eligible",
  "reason_codes": ["all_declared_safety_conditions_and_protected_gates_pass"],
  "requires_human_review": true,
  "essential_service_continuity_required": true,
} if {
  not insufficient_safety_evidence
  not critical_condition_failed
  not human_proximity_unknown
  not human_in_protective_zone
  input.asmi_protected >= 0.3
  protected_gates_pass
}
