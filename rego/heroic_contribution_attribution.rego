package augmented_hub.heroic_attribution

default decision := {
  "result": "review_required",
  "automated_final_decision": false,
  "named_publication_allowed": false,
  "institutional_review_required": true,
  "appeal_eligibility": "preserved"
}

deny contains reason if {
  input.automated_final_decision != false
  reason := "automated_final_decision_must_be_false"
}

deny contains reason if {
  some contributor in input.contributors
  contributor.publication_mode == "public"
  contributor.naming_consent.named_attribution_permitted == true
  contributor.naming_consent.consent_status != "granted"
  reason := "public_naming_requires_explicit_granted_consent"
}

deny contains reason if {
  some contributor in input.contributors
  contributor.publication_mode == "public"
  contributor.naming_consent.named_attribution_permitted == false
  reason := "public_mode_cannot_publish_a_person_without_naming_consent"
}

deny contains reason if {
  input.attribution_method.weights_are_descriptive_only != true
  reason := "attribution_weights_must_be_descriptive_only"
}

deny contains reason if {
  input.attribution_method.human_review_required != true
  reason := "human_review_must_remain_required"
}

deny contains reason if {
  input.dispute_status.notice_and_response_available != true
  reason := "notice_and_response_must_be_available"
}

deny contains reason if {
  input.dispute_status.neutral_review_available != true
  reason := "neutral_review_must_be_available"
}

deny contains reason if {
  input.dispute_status.appeal_available != true
  reason := "appeal_must_be_available"
}

named_publication_allowed if {
  count(deny) == 0
  some contributor in input.contributors
  contributor.publication_mode == "public"
  contributor.naming_consent.named_attribution_permitted == true
  contributor.naming_consent.consent_status == "granted"
}

decision := {
  "result": result,
  "automated_final_decision": false,
  "named_publication_allowed": named_publication_allowed,
  "institutional_review_required": true,
  "appeal_eligibility": "preserved",
  "denial_reasons": reasons
} if {
  reasons := [reason | deny contains reason]
  count(reasons) > 0
  result := "invalid_for_review_until_corrected"
}

decision := {
  "result": result,
  "automated_final_decision": false,
  "named_publication_allowed": named_publication_allowed,
  "institutional_review_required": true,
  "appeal_eligibility": "preserved",
  "denial_reasons": []
} if {
  count(deny) == 0
  input.dispute_status.state == "none_known"
  result := "ready_for_institutional_review"
}

decision := {
  "result": result,
  "automated_final_decision": false,
  "named_publication_allowed": named_publication_allowed,
  "institutional_review_required": true,
  "appeal_eligibility": "preserved",
  "denial_reasons": []
} if {
  count(deny) == 0
  input.dispute_status.state != "none_known"
  result := "review_paused_for_due_process"
}
