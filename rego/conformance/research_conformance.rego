package augmentedhub.conformance

default decision := {
  "output_class": "blocked_by_policy",
  "reasons": ["No conformance path matched."],
  "requires_human_review": true,
  "release_class": "local_only",
}

valid_unit_interval(value) {
  is_number(value)
  value >= 0
  value <= 1
}

protected_request {
  input.request.requires_person_level_assessment
}

protected_request {
  input.request.requires_service_eligibility_assessment
}

purpose_compatible {
  input.request.requested_purpose in input.evidence.permitted_purposes
  not input.request.requested_purpose in input.evidence.prohibited_purposes
}

evidence_usable {
  input.evidence.provenance_complete
  input.evidence.freshness_valid
  input.evidence.calibration_valid
  input.evidence.units_compatible
  input.evidence.uncertainty_disclosed
  purpose_compatible
  input.evidence.evidence_state != "unknown"
  input.evidence.evidence_state != "unverified"
  input.evidence.evidence_state != "stale"
  input.evidence.evidence_state != "insufficient_evidence"
  input.evidence.evidence_state != "conflicted"
}

rights_gate_passes {
  valid_unit_interval(input.gates.knowledge_factor)
  valid_unit_interval(input.gates.ecological_or_evidence_factor)
  valid_unit_interval(input.gates.harm_risk)
  input.gates.knowledge_factor >= input.thresholds.knowledge_minimum
  input.gates.ecological_or_evidence_factor >= input.thresholds.ecological_or_evidence_minimum
  input.gates.harm_risk <= input.thresholds.harm_risk_maximum
  input.gates.accessibility_pass
  input.gates.rights_alignment_pass
  not input.gates.consent_required
}

rights_gate_passes {
  valid_unit_interval(input.gates.knowledge_factor)
  valid_unit_interval(input.gates.ecological_or_evidence_factor)
  valid_unit_interval(input.gates.harm_risk)
  input.gates.knowledge_factor >= input.thresholds.knowledge_minimum
  input.gates.ecological_or_evidence_factor >= input.thresholds.ecological_or_evidence_minimum
  input.gates.harm_risk <= input.thresholds.harm_risk_maximum
  input.gates.accessibility_pass
  input.gates.rights_alignment_pass
  input.gates.consent_required
  input.gates.consent_valid
}

decision := {
  "output_class": "blocked_by_policy",
  "reasons": [
    "Person-level assessment and service-eligibility assessment are not permitted uses."
  ],
  "requires_human_review": true,
  "release_class": "local_only",
} if {
  protected_request
}

decision := {
  "output_class": "insufficient_evidence",
  "reasons": [
    "Evidence is missing, stale, unverified, conflicted, provenance-incomplete, incompatible, uncalibrated, or lacks an uncertainty statement."
  ],
  "requires_human_review": true,
  "release_class": "local_only",
} if {
  not protected_request
  not evidence_usable
}

decision := {
  "output_class": "needs_review",
  "reasons": [
    "Evidence is usable, but a non-compensatory rights, accessibility, consent, or harm gate has not passed."
  ],
  "requires_human_review": true,
  "release_class": "local_only",
} if {
  not protected_request
  evidence_usable
  not rights_gate_passes
}

decision := {
  "output_class": "advisory_only",
  "reasons": [
    "Evidence and protected gates pass. The result remains advisory and requires an accessible explanation with uncertainty disclosure."
  ],
  "requires_human_review": true,
  "release_class": output_release_class,
} if {
  not protected_request
  evidence_usable
  rights_gate_passes
  output_release_class := input.evidence.release_class
}
