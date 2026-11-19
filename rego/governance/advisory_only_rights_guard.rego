package augmented_hub.governance.advisory_only_rights_guard

default allow_recommendation := false
default decision := {
    "allow": false,
    "state": "blocked",
    "reasons": ["Recommendation has not passed the rights and safety policy."],
    "plain_language_explanation": "This recommendation is not available because its safety and rights requirements have not been verified."
}

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

has_nonempty_text(value) {
    is_string(value)
    trim(value) != ""
}

advisory_only {
    input.automatically_actuates_machinery == false
    input.denies_service == false
    input.requires_optional_telemetry == false
    input.requires_continuous_connectivity == false
    input.uses_biometric_identification == false
    input.uses_cybernetic_status_as_decision_input == false
}

rights_and_review_ready {
    input.human_review_available == true
    input.accessible_notice_available == true
    input.accessible_explanation_available == true
    input.appeal_path_available == true
    input.data_minimization_confirmed == true
    input.purpose_limitation_confirmed == true
    input.retention_and_deletion_path_available == true
}

ker_thresholds_met {
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

allow_recommendation {
    advisory_only
    rights_and_review_ready
    ker_thresholds_met
}

deny_reasons contains "Automated machinery actuation is not permitted by this advisory-only policy." {
    input.automatically_actuates_machinery != false
}

deny_reasons contains "Service denial is not permitted by this policy." {
    input.denies_service != false
}

deny_reasons contains "Optional telemetry cannot be required for access to this service." {
    input.requires_optional_telemetry != false
}

deny_reasons contains "Continuous connectivity cannot be required for essential access." {
    input.requires_continuous_connectivity != false
}

deny_reasons contains "Biometric identification is not permitted by this policy." {
    input.uses_biometric_identification != false
}

deny_reasons contains "Cybernetic-host or assistive-technology status cannot be used as a decision input." {
    input.uses_cybernetic_status_as_decision_input != false
}

deny_reasons contains "Human review must be available before this recommendation can be used." {
    input.human_review_available != true
}

deny_reasons contains "An accessible notice must be available before this recommendation can be used." {
    input.accessible_notice_available != true
}

deny_reasons contains "An accessible explanation and appeal path are required." {
    input.accessible_explanation_available != true
}

deny_reasons contains "An accessible explanation and appeal path are required." {
    input.appeal_path_available != true
}

deny_reasons contains "Data minimization and purpose limitation must be confirmed." {
    input.data_minimization_confirmed != true
}

deny_reasons contains "Data minimization and purpose limitation must be confirmed." {
    input.purpose_limitation_confirmed != true
}

deny_reasons contains "A retention and deletion path is required for collected data." {
    input.retention_and_deletion_path_available != true
}

deny_reasons contains "Knowledge factor is below the minimum advisory threshold." {
    input.ker.knowledge_factor < 0.60
}

deny_reasons contains "Ecological impact value is below the minimum advisory threshold." {
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

decision := {
    "allow": true,
    "state": "approved_for_advisory_use",
    "reasons": [],
    "plain_language_explanation": "This recommendation may be used as advisory decision support. It does not control machinery, deny a service, require optional telemetry, or use cybernetic-host status as a decision factor. Human review, an accessible explanation, and an appeal path remain available."
} if {
    allow_recommendation
}

decision := {
    "allow": false,
    "state": "needs_review",
    "reasons": reasons,
    "plain_language_explanation": "This recommendation is not approved for advisory use yet. Review the listed requirements, correct any missing safeguards, and provide a human-review and appeal path."
} if {
    not allow_recommendation
    reasons := sort([reason | deny_reasons[reason]])
}
