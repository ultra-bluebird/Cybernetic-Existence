package augmented_hub.architecture.offline_sync_energy_guard

default allow_sync_bundle := false
default conflict_resolution := "human_review_required"
default allow_adaptive_polling := false

protected_record_types := {
    "community_observation",
    "safety_observation",
    "water_quality_observation",
    "accessibility_barrier_report",
    "consent_record",
    "consent_withdrawal",
    "appeal_case",
    "correction_case",
    "grievance_record",
    "privacy_budget_ledger",
    "policy_configuration",
    "ker_assessment"
}

valid_sync_envelope {
    input.sync.evidence_id != ""
    input.sync.record_version != ""
    input.sync.timestamp != ""
    input.sync.vector_clock != null
    input.sync.owner_did != ""
    input.sync.sensitivity_classification != ""
    input.sync.purpose != ""
    input.sync.retention_status != ""
    input.sync.provenance_reference != ""
    input.sync.integrity_digest != ""
}

rights_preserved {
    input.sync.requires_continuous_connectivity == false
    input.sync.requires_optional_telemetry == false
    input.sync.uses_biometric_identification == false
    input.sync.uses_cybernetic_status_as_penalty == false
    input.sync.authorizes_physical_actuation == false
    input.sync.authorizes_service_denial == false
    input.sync.accessible_explanation_available == true
    input.sync.appeal_or_correction_path_available == true
}

allow_sync_bundle {
    valid_sync_envelope
    rights_preserved
    input.sync.contains_sensitive_raw_data == false
    input.sync.aggregation_approved == true
    input.sync.privacy_budget_available == true
}

conflict_resolution := "append_only_protected" {
    protected_record_types[input.sync.record_type]
}

conflict_resolution := "preserve_both_require_review" {
    protected_record_types[input.sync.record_type]
    input.sync.concurrent_update_detected == true
}

conflict_resolution := "causally_newer_version" {
    input.sync.concurrent_update_detected == false
    input.sync.incoming_version_dominates == true
}

deny_reason["sync records require timestamp vector clock owner attribution provenance and integrity metadata"] {
    not valid_sync_envelope
}

deny_reason["raw sensitive evidence cannot be synchronized as an aggregate release"] {
    input.sync.contains_sensitive_raw_data == true
}

deny_reason["community data release requires approved aggregation and available privacy budget"] {
    input.sync.aggregation_approved != true
}

deny_reason["protected concurrent records must preserve both versions and require review"] {
    protected_record_types[input.sync.record_type]
    input.sync.concurrent_update_detected == true
    input.sync.attempts_last_writer_wins == true
}

polling_inputs_valid {
    input.polling.base_interval_s > 0
    input.polling.minimum_interval_s > 0
    input.polling.maximum_interval_s > 0
    input.polling.required_maximum_interval_s > 0
    input.polling.minimum_interval_s <= input.polling.maximum_interval_s
    input.polling.alpha >= 0
    input.polling.sleep_current_microamps >= 0
    input.polling.local_computation_only == true
    input.polling.wake_uses_sensitive_identity_data == false
}

polling_cadence_preserved {
    input.polling.effective_interval_s <= input.polling.required_maximum_interval_s
}

allow_adaptive_polling {
    polling_inputs_valid
    polling_cadence_preserved
    input.polling.physical_actuation_enabled == false
    input.polling.accessible_explanation_available == true
    input.polling.human_review_path_available == true
}

deny_reason["adaptive polling must preserve the required maximum monitoring interval"] {
    not polling_cadence_preserved
}

deny_reason["adaptive polling cannot use cybernetic status identity or assistive-device data as a wake trigger"] {
    input.polling.wake_uses_sensitive_identity_data != false
}

deny_reason["adaptive polling is limited to local advisory computation and monitoring"] {
    input.polling.physical_actuation_enabled != false
}
