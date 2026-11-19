package augmented_hub.governance.rights_centered_technology_charter

default allow_advisory_use := false

default decision := {
    "allow": false,
    "state": "blocked",
    "reasons": [
        "The request has not passed Augmented-Hub rights, safety, privacy, accessibility, and evidence requirements."
    ],
    "plain_language_explanation": "This result is not approved because one or more required protections have not been verified. Essential access, correction, and appeal options must remain available."
}

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

ker_gate {
    valid_unit_interval(input.ker.knowledge_factor)
    valid_unit_interval(input.ker.eco_impact_value)
    valid_unit_interval(input.ker.harm_risk)
    valid_unit_interval(input.ker.accessibility_impact)
    valid_unit_interval(input.ker.rights_alignment)
    input.ker.knowledge_factor >= 0.60
    input.ker.eco_impact_value >= 0.50
    input.ker.harm_risk <= 0.45
    input.ker.accessibility_impact >= 0.70
    input.ker.rights_alignment >= 0.80
}

rights_gate {
    input.governance.advisory_only == true
    input.governance.automated_actuation == false
    input.governance.automated_service_denial == false
    input.governance.requires_continuous_connectivity == false
    input.governance.requires_optional_telemetry == false
    input.governance.requires_identity_certificate == false
    input.governance.requires_medical_documentation == false
    input.governance.requires_device_identifier == false
    input.governance.requires_cybernetic_status_disclosure == false
    input.governance.requires_assistive_device_disclosure == false
    input.governance.requires_health_disclosure == false
    input.governance.requires_disability_disclosure == false
    input.governance.uses_biometric_identification == false
    input.governance.infers_sensitive_identity_status == false
    input.governance.uses_cybernetic_status_as_penalty == false
    input.governance.uses_assistive_technology_as_penalty == false
    input.governance.human_review_available == true
    input.governance.accessible_notice_available == true
    input.governance.accessible_explanation_available == true
    input.governance.appeal_path_available == true
    input.governance.non_digital_escalation_available == true
    input.governance.data_minimization_confirmed == true
    input.governance.purpose_limitation_confirmed == true
    input.governance.retention_and_deletion_path_available == true
}

evidence_gate {
    input.evidence.raw_and_derived_separated == true
    input.evidence.formula_version_present == true
    input.evidence.parameter_version_present == true
    input.evidence.provenance_reference_present == true
    input.evidence.uncertainty_record_present == true
    input.evidence.synthetic_data_labeled == true
    input.evidence.silent_stale_substitution == false
    input.evidence.silent_missing_substitution == false
    input.evidence.silent_low_quality_substitution == false
    input.evidence.unsupported_compliance_claim == false
}

offline_policy_usable {
    input.policy.signature_valid == true
    input.policy.version_known == true
    input.policy.not_expired == true
}

local_evaluation_allowed {
    input.runtime.local_policy_evaluation_available == true
    input.runtime.network_available == true
}

local_evaluation_allowed {
    input.runtime.local_policy_evaluation_available == true
    input.runtime.network_available == false
    offline_policy_usable
}

safe_offline_mode_required {
    input.runtime.network_available == false
    not offline_policy_usable
}

protected_conflict_handling_valid {
    input.sync.record_is_protected == false
}

protected_conflict_handling_valid {
    input.sync.record_is_protected == true
    input.sync.concurrent_update_detected == false
}

protected_conflict_handling_valid {
    input.sync.record_is_protected == true
    input.sync.concurrent_update_detected == true
    input.sync.last_writer_wins_requested == false
    input.sync.preserve_all_versions == true
    input.sync.human_review_required == true
}

allow_advisory_use {
    ker_gate
    rights_gate
    evidence_gate
    local_evaluation_allowed
    protected_conflict_handling_valid
}

deny_reasons contains "The harm-risk limit was exceeded and ecological benefit cannot override it." {
    input.ker.harm_risk > 0.45
}

deny_reasons contains "Accessibility impact is below the required threshold." {
    input.ker.accessibility_impact < 0.70
}

deny_reasons contains "Rights alignment is below the required threshold." {
    input.ker.rights_alignment < 0.80
}

deny_reasons contains "Automated actuation and automated service denial are prohibited." {
    input.governance.automated_actuation != false
}

deny_reasons contains "Automated actuation and automated service denial are prohibited." {
    input.governance.automated_service_denial != false
}

deny_reasons contains "Essential access cannot require connectivity, optional telemetry, identity certification, device identifiers, or sensitive disclosure." {
    input.governance.requires_continuous_connectivity != false
}

deny_reasons contains "Essential access cannot require connectivity, optional telemetry, identity certification, device identifiers, or sensitive disclosure." {
    input.governance.requires_optional_telemetry != false
}

deny_reasons contains "Essential access cannot require connectivity, optional telemetry, identity certification, device identifiers, or sensitive disclosure." {
    input.governance.requires_identity_certificate != false
}

deny_reasons contains "Essential access cannot require connectivity, optional telemetry, identity certification, device identifiers, or sensitive disclosure." {
    input.governance.requires_device_identifier != false
}

deny_reasons contains "Essential access cannot require connectivity, optional telemetry, identity certification, device identifiers, or sensitive disclosure." {
    input.governance.requires_cybernetic_status_disclosure != false
}

deny_reasons contains "Biometric identification, sensitive identity inference, and status penalties are prohibited." {
    input.governance.uses_biometric_identification != false
}

deny_reasons contains "Biometric identification, sensitive identity inference, and status penalties are prohibited." {
    input.governance.infers_sensitive_identity_status != false
}

deny_reasons contains "Biometric identification, sensitive identity inference, and status penalties are prohibited." {
    input.governance.uses_cybernetic_status_as_penalty != false
}

deny_reasons contains "Biometric identification, sensitive identity inference, and status penalties are prohibited." {
    input.governance.uses_assistive_technology_as_penalty != false
}

deny_reasons contains "Human review, accessible notice, explanation, appeal, and non-digital escalation are required." {
    input.governance.human_review_available != true
}

deny_reasons contains "Human review, accessible notice, explanation, appeal, and non-digital escalation are required." {
    input.governance.accessible_notice_available != true
}

deny_reasons contains "Human review, accessible notice, explanation, appeal, and non-digital escalation are required." {
    input.governance.accessible_explanation_available != true
}

deny_reasons contains "Human review, accessible notice, explanation, appeal, and non-digital escalation are required." {
    input.governance.appeal_path_available != true
}

deny_reasons contains "Human review, accessible notice, explanation, appeal, and non-digital escalation are required." {
    input.governance.non_digital_escalation_available != true
}

deny_reasons contains "Evidence lineage, uncertainty, versioning, and synthetic-data labeling are required." {
    not evidence_gate
}

deny_reasons contains "Concurrent protected records must be preserved and sent to human review." {
    not protected_conflict_handling_valid
}

decision := {
    "allow": true,
    "state": "approved_for_advisory_use",
    "reasons": [],
    "plain_language_explanation": "This result may be used as advisory support. It does not control physical systems, deny services, require sensitive disclosure, require continuous connectivity, or use cybernetic or assistive status as a penalty. Accessible explanation, human review, correction, and appeal remain available."
} if {
    allow_advisory_use
}

decision := {
    "allow": false,
    "state": "restrict_to_safe_offline_mode",
    "reasons": [
        "A valid signed policy is not available while the network is unavailable."
    ],
    "plain_language_explanation": "The system is in safe offline mode. Local essential information, explanation, evidence capture, correction intake, appeal intake, and non-digital escalation remain available. The system will not automate action, deny access, or force data upload."
} if {
    safe_offline_mode_required
}

decision := {
    "allow": false,
    "state": "needs_review",
    "reasons": reasons,
    "plain_language_explanation": "This result needs review before advisory use. The reasons identify the safety, evidence, privacy, accessibility, or rights conditions that require attention. Correction and appeal options remain available."
} if {
    not allow_advisory_use
    not safe_offline_mode_required
    reasons := sort([reason | deny_reasons[reason]])
}
