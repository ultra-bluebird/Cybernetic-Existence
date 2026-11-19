package augmentedhub.module_governance

default allow := false

required_rights := [
    "local_access_preserved",
    "privacy_preserved",
    "accessible_status_preserved",
    "revoke_preserved",
    "export_preserved",
    "correction_preserved",
    "appeal_preserved",
    "human_fallback_preserved"
]

deny[msg] if {
    some right in required_rights
    not input.rights_baseline[right]
    msg := sprintf("module must preserve %s", [right])
}

deny["module must provide a declared, purpose-bound, revocable consent scope"] if {
    not input.consent_scope.state_declared
}

deny["module must provide a declared, purpose-bound, revocable consent scope"] if {
    not input.consent_scope.purpose_bound
}

deny["module must provide a declared, purpose-bound, revocable consent scope"] if {
    not input.consent_scope.revocable
}

deny["ephemeral modules must not store raw payload"] if {
    input.retention.class == "LOCAL_EPHEMERAL"
    input.retention.stores_raw_payload
}

deny["module must define a deletion tombstone plan"] if {
    not input.retention.deletion_tombstone_plan
}

deny["core functions must remain usable without network access"] if {
    not input.offline_behavior.core_functions_available_without_network
}

deny["external failure must preserve local access"] if {
    not input.offline_behavior.external_failure_preserves_local_access
}

deny["telemetry export must be bounded, aggregate-only, purpose-bound, and consented"] if {
    not input.telemetry.bounded_aggregate_export_only
}

deny["telemetry export must be bounded, aggregate-only, purpose-bound, and consented"] if {
    not input.telemetry.purpose_and_consent_required
}

deny["module must remain keyboard operable"] if {
    not input.accessibility.keyboard_operable
}

deny["module must expose accessible status semantics"] if {
    not input.accessibility.status_semantics
}

deny["module must support high contrast"] if {
    not input.accessibility.high_contrast_supported
}

deny["module must support reduced motion"] if {
    not input.accessibility.reduced_motion_supported
}

deny["CyberRank must remain a private governance layer"] if {
    input.cyberrank_public_score
}

allow if {
    count(deny) == 0
    input.explicit_user_approval.plain_language_preview
    input.explicit_user_approval.approved
}
