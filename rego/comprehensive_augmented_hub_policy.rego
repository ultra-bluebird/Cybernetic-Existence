package augmented_hub.comprehensive_policy

default allow_advisory_use := false

default decision := {
    "allow": false,
    "state": "blocked",
    "reasons": ["The request has not passed the required safety, privacy, accessibility, evidence, and governance checks."],
    "plain_language_explanation": "This result is not available for advisory use because one or more required safeguards have not been verified."
}

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

valid_ker {
    valid_unit_interval(input.ker.knowledge_factor)
    valid_unit_interval(input.ker.eco_impact_value)
    valid_unit_interval(input.ker.harm_risk)
    valid_unit_interval(input.ker.accessibility_impact)
    valid_unit_interval(input.ker.rights_alignment)
}

quality_inputs_valid {
    count(input.evidence.quality_scores) > 0
    count(input.evidence.quality_scores) == count(input.evidence.quality_weights)

    every score in input.evidence.quality_scores {
        valid_unit_interval(score)
    }

    every weight in input.evidence.quality_weights {
        valid_unit_interval(weight)
    }

    abs(sum(input.evidence.quality_weights) - 1.0) <= 0.000001
}

zero_quality_evidence {
    input.evidence.quality_scores[_] == 0
}

non_compensatory_ker_pass {
    valid_ker
    quality_inputs_valid
    not zero_quality_evidence
    input.ker.knowledge_factor >= 0.60
    input.ker.eco_impact_value >= 0.50
    input.ker.harm_risk <= 0.45
    input.ker.accessibility_impact >= 0.70
    input.ker.rights_alignment >= 0.80
}

rights_and_access_pass {
    input.governance.advisory_only == true
    input.governance.automatically_actuates_machinery == false
    input.governance.automated_service_denial == false
    input.governance.requires_optional_telemetry == false
    input.governance.requires_continuous_connectivity == false
    input.governance.biometric_identification_permitted == false
    input.governance.cybernetic_integration_data_required == false
    input.governance.cybernetic_status_penalty == 0
    input.governance.assistive_technology_penalty == 0
    input.governance.human_review_available == true
    input.governance.accessible_notice_available == true
    input.governance.accessible_explanation_available == true
    input.governance.appeal_path_available == true
    input.governance.non_digital_escalation_available == true
    input.governance.data_minimization_confirmed == true
    input.governance.purpose_limitation_confirmed == true
    input.governance.retention_and_deletion_path_available == true
}

uncertainty_pass {
    valid_unit_interval(input.uncertainty.score)
    input.uncertainty.record_present == true
    input.uncertainty.score <= input.policy.maximum_uncertainty_for_advisory_use
}

policy_bundle_usable {
    input.policy_bundle.signature_valid == true
    input.policy_bundle.version_known == true
    input.policy_bundle.not_expired == true
}

runtime_permits_local_evaluation {
    input.runtime.local_policy_evaluation_available == true
    input.runtime.network_available == true
}

runtime_permits_local_evaluation {
    input.runtime.local_policy_evaluation_available == true
    input.runtime.network_available == false
    policy_bundle_usable
}

safe_offline_mode_required {
    input.runtime.network_available == false
    not policy_bundle_usable
}

allow_advisory_use {
    runtime_permits_local_evaluation
    non_compensatory_ker_pass
    rights_and_access_pass
    uncertainty_pass
}

deny_reasons contains "Evidence-quality scores and weights must be complete, bounded, and normalized." {
    not quality_inputs_valid
}

deny_reasons contains "At least one required evidence-quality factor is zero." {
    zero_quality_evidence
}

deny_reasons contains "Knowledge factor is below the advisory threshold." {
    input.ker.knowledge_factor < 0.60
}

deny_reasons contains "Eco-impact value is below the advisory threshold." {
    input.ker.eco_impact_value < 0.50
}

deny_reasons contains "Harm risk exceeds the non-compensatory threshold." {
    input.ker.harm_risk > 0.45
}

deny_reasons contains "Accessibility impact is below the required threshold." {
    input.ker.accessibility_impact < 0.70
}

deny_reasons contains "Rights alignment is below the required threshold." {
    input.ker.rights_alignment < 0.80
}

deny_reasons contains "A recorded uncertainty assessment is required." {
    input.uncertainty.record_present != true
}

deny_reasons contains "Uncertainty exceeds the configured advisory threshold." {
    input.uncertainty.score > input.policy.maximum_uncertainty_for_advisory_use
}

deny_reasons contains "Automated machinery actuation and automated service denial are prohibited." {
    input.governance.automatically_actuates_machinery != false
}

deny_reasons contains "Automated machinery actuation and automated service denial are prohibited." {
    input.governance.automated_service_denial != false
}

deny_reasons contains "Essential access cannot require optional telemetry or continuous connectivity." {
    input.governance.requires_optional_telemetry != false
}

deny_reasons contains "Essential access cannot require optional telemetry or continuous connectivity." {
    input.governance.requires_continuous_connectivity != false
}

deny_reasons contains "Biometric identification and cybernetic integration disclosure are prohibited for essential access." {
    input.governance.biometric_identification_permitted != false
}

deny_reasons contains "Biometric identification and cybernetic integration disclosure are prohibited for essential access." {
    input.governance.cybernetic_integration_data_required != false
}

deny_reasons contains "Cybernetic or assistive status cannot be used as a penalty." {
    input.governance.cybernetic_status_penalty != 0
}

deny_reasons contains "Cybernetic or assistive status cannot be used as a penalty." {
    input.governance.assistive_technology_penalty != 0
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

deny_reasons contains "Data minimization, purpose limitation, retention, and deletion controls are required." {
    input.governance.data_minimization_confirmed != true
}

deny_reasons contains "Data minimization, purpose limitation, retention, and deletion controls are required." {
    input.governance.purpose_limitation_confirmed != true
}

deny_reasons contains "Data minimization, purpose limitation, retention, and deletion controls are required." {
    input.governance.retention_and_deletion_path_available != true
}

decision := {
    "allow": true,
    "state": "approved_for_advisory_use",
    "reasons": [],
    "plain_language_explanation": "This result may be used as advisory support. It does not control machinery, deny a service, require optional telemetry, require continuous connectivity, or use cybernetic or assistive status as a penalty. Human review, accessible explanation, appeal, and non-digital escalation remain available."
} if {
    allow_advisory_use
}

decision := {
    "allow": false,
    "state": "restrict_to_safe_offline_mode",
    "reasons": ["A valid signed local policy bundle is not available while offline."],
    "plain_language_explanation": "The network is unavailable and the local policy cannot be verified. Locally stored essential information, correction intake, and appeal intake remain available. The system will not perform automated action, deny services, or force data upload."
} if {
    safe_offline_mode_required
}

decision := {
    "allow": false,
    "state": "needs_review",
    "reasons": reasons,
    "plain_language_explanation": "This result needs review before advisory use. The listed reasons explain which evidence, safety, accessibility, privacy, or governance safeguards require attention. Accessible correction and appeal options remain available."
} if {
    not allow_advisory_use
    not safe_offline_mode_required
    reasons := sort([reason | deny_reasons[reason]])
}
