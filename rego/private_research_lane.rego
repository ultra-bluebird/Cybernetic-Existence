package augmentedhub.private_research_lane

default advance_lane := false

deny_reason["PURPOSE_MISSING"] if {
    not input.purpose.declared
}

deny_reason["CONSENT_SCOPE_INVALID"] if {
    not input.consent.scope_declared
}

deny_reason["CONSENT_SCOPE_INVALID"] if {
    not input.consent.revocable
}

deny_reason["DATA_MINIMIZATION_MISSING"] if {
    not input.data_classes.enumerated
}

deny_reason["RETENTION_PLAN_MISSING"] if {
    not input.retention.deletion_plan_defined
}

deny_reason["BASELINE_RIGHTS_NOT_PRESERVED"] if {
    not input.baseline.local_access_preserved
}

deny_reason["BASELINE_RIGHTS_NOT_PRESERVED"] if {
    not input.baseline.privacy_preserved
}

deny_reason["BASELINE_RIGHTS_NOT_PRESERVED"] if {
    not input.baseline.accessible_status_preserved
}

deny_reason["BASELINE_RIGHTS_NOT_PRESERVED"] if {
    not input.baseline.revoke_preserved
}

deny_reason["BASELINE_RIGHTS_NOT_PRESERVED"] if {
    not input.baseline.correction_preserved
}

deny_reason["BASELINE_RIGHTS_NOT_PRESERVED"] if {
    not input.baseline.appeal_preserved
}

deny_reason["BASELINE_RIGHTS_NOT_PRESERVED"] if {
    not input.baseline.human_fallback_preserved
}

deny_reason["STOP_CONDITIONS_MISSING"] if {
    not input.safety.stop_conditions_defined
}

deny_reason["RECOVERY_PLAN_MISSING"] if {
    not input.recovery.authority_off
}

deny_reason["RECOVERY_PLAN_MISSING"] if {
    not input.recovery.traffic_blocked
}

deny_reason["RECOVERY_PLAN_MISSING"] if {
    not input.recovery.evidence_seal
}

deny_reason["RECOVERY_PLAN_MISSING"] if {
    not input.recovery.local_access_confirmed
}

deny_reason["EXTERNAL_RELEASE_NOT_REVIEWED"] if {
    input.external_release.requested
    not input.external_release.holder_approved
}

deny_reason["REPLICATION_NOT_SEPARATELY_AUTHORIZED"] if {
    input.operation.name == "replicate"
    not input.operation.separately_authorized
}

deny_reason["CYBERRANK_PUBLIC_CLASSIFICATION_PROHIBITED"] if {
    input.cyberrank.public_score_enabled
}

deny_reason["CYBERRANK_PUBLIC_CLASSIFICATION_PROHIBITED"] if {
    input.cyberrank.used_for_eligibility
}

advance_lane if {
    count(deny_reason) == 0
    input.approval.plain_language_preview
    input.approval.explicit_holder_approval
    input.evidence.acceptance_criteria_passed
    input.review.applicable_review_complete
}
