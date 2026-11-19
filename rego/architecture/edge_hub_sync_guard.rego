package augmented_hub.architecture.edge_hub_sync_guard

default allow_sync := false
default conflict_resolution := "human_review_required"

lww_eligible_record_types := {
    "ui_cache",
    "weather_tile_cache",
    "display_refresh_checkpoint",
    "recomputable_preview"
}

append_only_protected_record_types := {
    "consent_record",
    "consent_withdrawal",
    "deletion_request",
    "export_request",
    "appeal_case",
    "correction_case",
    "grievance_record",
    "accessibility_barrier_report",
    "safety_observation",
    "sensor_anomaly",
    "policy_configuration",
    "privacy_budget_ledger",
    "ker_assessment",
    "maintenance_completion_evidence",
    "ecological_impact_evidence"
}

valid_sync_envelope {
    input.bundle.version != ""
    input.bundle.record_type != ""
    input.bundle.source_replica_label != ""
    input.bundle.vector_clock != null
    input.bundle.policy_version != ""
    input.bundle.sensitivity_classification != ""
    input.bundle.provenance_reference != ""
    input.bundle.integrity_digest != ""
}

privacy_release_allowed {
    input.bundle.contains_sensitive_raw_data == false
    input.bundle.aggregation_approved == true
    input.bundle.privacy_budget_available == true
    input.bundle.epsilon <= 0.5
    input.bundle.delta <= 0.000001
}

rights_preserved {
    input.bundle.requires_continuous_connectivity == false
    input.bundle.requires_optional_telemetry == false
    input.bundle.uses_biometric_identification == false
    input.bundle.uses_cybernetic_status_as_penalty == false
    input.bundle.authorizes_physical_actuation == false
    input.bundle.authorizes_service_denial == false
    input.bundle.accessible_explanation_available == true
    input.bundle.appeal_or_correction_path_available == true
}

allow_sync {
    valid_sync_envelope
    privacy_release_allowed
    rights_preserved
}

conflict_resolution := "lww_cache" {
    lww_eligible_record_types[input.bundle.record_type]
    input.conflict.concurrent == true
    input.bundle.contains_sensitive_raw_data == false
    input.bundle.has_rights_effect == false
    input.bundle.has_safety_effect == false
    input.bundle.has_accessibility_effect == false
    input.bundle.has_privacy_effect == false
}

conflict_resolution := "append_only_protected" {
    append_only_protected_record_types[input.bundle.record_type]
}

conflict_resolution := "mergeable_aggregate" {
    input.bundle.record_type == "aggregate_summary"
    input.bundle.aggregation_approved == true
    input.bundle.contains_sensitive_raw_data == false
    input.bundle.aggregation_version != ""
}

deny_reason["sync bundles require version provenance policy and integrity metadata"] {
    not valid_sync_envelope
}

deny_reason["raw sensitive data cannot be synchronized as a community aggregate release"] {
    input.bundle.contains_sensitive_raw_data == true
}

deny_reason["aggregate release requires available differential-privacy budget"] {
    input.bundle.privacy_budget_available != true
}

deny_reason["aggregate release exceeds the epsilon privacy ceiling"] {
    input.bundle.epsilon > 0.5
}

deny_reason["aggregate release exceeds the delta privacy ceiling"] {
    input.bundle.delta > 0.000001
}

deny_reason["essential access cannot require continuous connectivity or optional telemetry"] {
    input.bundle.requires_continuous_connectivity == true
}

deny_reason["cybernetic integration data cannot be used as a penalty feature"] {
    input.bundle.uses_cybernetic_status_as_penalty == true
}

deny_reason["the edge–hub architecture does not authorize actuation or service denial"] {
    input.bundle.authorizes_physical_actuation == true
}

deny_reason["the edge–hub architecture does not authorize actuation or service denial"] {
    input.bundle.authorizes_service_denial == true
}

deny_reason["synchronization decisions require accessible explanation and correction paths"] {
    input.bundle.accessible_explanation_available != true
}

deny_reason["synchronization decisions require accessible explanation and correction paths"] {
    input.bundle.appeal_or_correction_path_available != true
}
