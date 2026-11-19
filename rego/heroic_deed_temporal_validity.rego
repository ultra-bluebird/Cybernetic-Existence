package augmented_hub.heroic_temporal_validity

default decision := {
  "result": "review_required",
  "automated_final_decision": false,
  "recognition_continuity_preserved": true,
  "time_based_revocation_permitted": false,
  "inactivity_based_revocation_permitted": false,
  "institutional_review_required": true,
  "appeal_eligibility": "preserved"
}

deny contains reason if {
  input.automated_final_decision != false
  reason := "automated_final_decision_must_be_false"
}

deny contains reason if {
  input.recognition_continuity.status_does_not_expire_by_time != true
  reason := "status_must_not_expire_by_time"
}

deny contains reason if {
  input.recognition_continuity.inactivity_not_adverse != true
  reason := "inactivity_must_not_be_adverse"
}

deny contains reason if {
  input.recognition_continuity.rest_retirement_or_withdrawal_protected != true
  reason := "rest_retirement_or_withdrawal_must_be_protected"
}

deny contains reason if {
  input.recognition_continuity.renewal_or_reperformance_not_required != true
  reason := "renewal_or_reperformance_must_not_be_required"
}

deny contains reason if {
  input.evidence_preservation.institutional_neglect_not_adverse != true
  reason := "institutional_neglect_must_not_be_adverse"
}

deny contains reason if {
  input.evidence_preservation.privacy_limited_evidence_permitted != true
  reason := "privacy_limited_evidence_must_be_permitted"
}

deny contains reason if {
  input.reverification.reverification_is_not_automatic_revocation != true
  reason := "reverification_must_not_be_automatic_revocation"
}

deny contains reason if {
  input.reverification.human_review_required != true
  reason := "reverification_requires_human_review"
}

deny contains reason if {
  input.correction_process.append_only_correction_required != true
  reason := "corrections_must_be_append_only"
}

deny contains reason if {
  input.correction_process.prior_record_preserved != true
  reason := "prior_record_must_be_preserved"
}

deny contains reason if {
  input.correction_process.notice_required_for_material_change != true
  reason := "material_change_requires_notice"
}

deny contains reason if {
  input.correction_process.evidence_access_available != true
  reason := "evidence_access_must_be_available"
}

deny contains reason if {
  input.correction_process.neutral_review_available != true
  reason := "neutral_review_must_be_available"
}

deny contains reason if {
  input.correction_process.appeal_available != true
  reason := "appeal_must_be_available"
}

deny contains reason if {
  input.procedural_guarantees.no_time_based_revocation != true
  reason := "time_based_revocation_must_be_prohibited"
}

deny contains reason if {
  input.procedural_guarantees.no_inactivity_based_revocation != true
  reason := "inactivity_based_revocation_must_be_prohibited"
}

deny contains reason if {
  input.procedural_guarantees.no_adverse_inference_from_private_evidence != true
  reason := "private_evidence_must_not_create_adverse_inference"
}

deny contains reason if {
  input.procedural_guarantees.accessible_communication_available != true
  reason := "accessible_communication_must_be_available"
}

deny contains reason if {
  input.procedural_guarantees.human_final_authority != true
  reason := "human_final_authority_must_be_preserved"
}

valid_record if {
  count(deny) == 0
}

review_triggered if {
  some trigger in input.reverification.permitted_triggers
  trigger == "material_new_evidence"
}

review_triggered if {
  some trigger in input.reverification.permitted_triggers
  trigger == "credible_evidence_integrity_concern"
}

review_triggered if {
  some trigger in input.reverification.permitted_triggers
  trigger == "material_attribution_dispute"
}

review_triggered if {
  some trigger in input.reverification.permitted_triggers
  trigger == "substantial_historical_context_update"
}

review_triggered if {
  some trigger in input.reverification.permitted_triggers
  trigger == "holder_requested_correction"
}

review_triggered if {
  some trigger in input.reverification.permitted_triggers
  trigger == "appeal_or_neutral_review_request"
}

decision := {
  "result": "invalid_for_review_until_corrected",
  "automated_final_decision": false,
  "recognition_continuity_preserved": true,
  "time_based_revocation_permitted": false,
  "inactivity_based_revocation_permitted": false,
  "institutional_review_required": true,
  "appeal_eligibility": "preserved",
  "reasons": reasons
} if {
  reasons := [reason | deny contains reason]
  count(reasons) > 0
}

decision := {
  "result": "reverification_requires_institutional_review",
  "automated_final_decision": false,
  "recognition_continuity_preserved": true,
  "time_based_revocation_permitted": false,
  "inactivity_based_revocation_permitted": false,
  "institutional_review_required": true,
  "appeal_eligibility": "preserved",
  "reasons": []
} if {
  valid_record
  review_triggered
}

decision := {
  "result": "temporal_validity_record_preserved",
  "automated_final_decision": false,
  "recognition_continuity_preserved": true,
  "time_based_revocation_permitted": false,
  "inactivity_based_revocation_permitted": false,
  "institutional_review_required": true,
  "appeal_eligibility": "preserved",
  "reasons": []
} if {
  valid_record
  not review_triggered
}
