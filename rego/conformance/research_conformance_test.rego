package augmentedhub.conformance_test

import data.augmentedhub.conformance

base_input := {
  "request": {
    "requested_purpose": "shade_planning",
    "requires_person_level_assessment": false,
    "requires_service_eligibility_assessment": false,
  },
  "evidence": {
    "permitted_purposes": ["shade_planning"],
    "prohibited_purposes": [],
    "evidence_state": "modeled",
    "provenance_complete": true,
    "freshness_valid": true,
    "calibration_valid": true,
    "units_compatible": true,
    "uncertainty_disclosed": true,
    "release_class": "local_only",
  },
  "gates": {
    "knowledge_factor": 0.80,
    "ecological_or_evidence_factor": 0.80,
    "harm_risk": 0.20,
    "accessibility_pass": true,
    "rights_alignment_pass": true,
    "consent_required": false,
    "consent_valid": false,
  },
  "thresholds": {
    "knowledge_minimum": 0.60,
    "ecological_or_evidence_minimum": 0.60,
    "harm_risk_maximum": 0.30,
  },
}

test_usable_evidence_returns_advisory_only if {
  result := conformance.decision with input as base_input
  result.output_class == "advisory_only"
  result.release_class == "local_only"
  result.requires_human_review
}

test_missing_evidence_fails_closed if {
  invalid := object.union(base_input, {
    "evidence": object.union(base_input.evidence, {
      "evidence_state": "insufficient_evidence",
    }),
  })
  result := conformance.decision with input as invalid
  result.output_class == "insufficient_evidence"
  result.release_class == "local_only"
}

test_unacceptable_harm_requires_review if {
  unsafe := object.union(base_input, {
    "gates": object.union(base_input.gates, {
      "harm_risk": 0.31,
    }),
  })
  result := conformance.decision with input as unsafe
  result.output_class == "needs_review"
  result.requires_human_review
}

test_person_scoring_is_blocked if {
  prohibited := object.union(base_input, {
    "request": object.union(base_input.request, {
      "requires_person_level_assessment": true,
    }),
  })
  result := conformance.decision with input as prohibited
  result.output_class == "blocked_by_policy"
  result.release_class == "local_only"
}

test_stale_evidence_is_not_promoted if {
  stale := object.union(base_input, {
    "evidence": object.union(base_input.evidence, {
      "evidence_state": "stale",
      "freshness_valid": false,
    }),
  })
  result := conformance.decision with input as stale
  result.output_class == "insufficient_evidence"
}
