package augmented_hub.automation.energy_accessibility_guard

default allow_advisory_action := false
default require_human_review := false
default low_power_inspection_mode := false

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

valid_nonnegative(value) {
    is_number(value)
    value >= 0
}

human_review_available {
    input.review.human_review == true
}

accessible_notice_available {
    input.review.accessible_notice == true
}

consent_satisfied {
    input.action.consent_required == false
}

consent_satisfied {
    input.action.consent_required == true
    input.action.explicit_consent_present == true
}

automation_action_safe {
    valid_unit_interval(input.ker.harm_risk)
    valid_unit_interval(input.ker.knowledge_factor)
    valid_unit_interval(input.ker.eco_impact_value)
    valid_unit_interval(input.ker.accessibility_impact)
    valid_unit_interval(input.ker.rights_alignment)
    input.ker.harm_risk <= 0.45
    input.ker.knowledge_factor >= 0.60
    input.ker.eco_impact_value >= 0.50
    input.ker.accessibility_impact >= 0.70
    input.ker.rights_alignment >= 0.80
    human_review_available
    accessible_notice_available
    consent_satisfied
    input.action.physical_actuation_requested == false
}

allow_advisory_action {
    input.action.advisory_only == true
    automation_action_safe
}

low_power_inspection_mode {
    input.energy.total_projected_energy_j > input.energy.renewable_budget_j
}

low_power_inspection_mode {
    input.energy.renewable_provenance_verified != true
}

require_human_review {
    input.ker.harm_risk > 0.45
}

require_human_review {
    input.energy.total_projected_energy_j > input.energy.renewable_budget_j
}

require_human_review {
    input.panel.network_available == false
}

deny_reason["ecological benefit cannot override harm risk above the non-compensatory threshold"] {
    input.ker.harm_risk > 0.45
}

deny_reason["advisory action requires meaningful human review"] {
    not human_review_available
}

deny_reason["advisory action requires an accessible notice"] {
    not accessible_notice_available
}

deny_reason["required consent is absent"] {
    not consent_satisfied
}

deny_reason["the foundation does not authorize physical actuation"] {
    input.action.physical_actuation_requested == true
}

deny_reason["maintenance energy budget must be backed by verified renewable provenance"] {
    input.energy.renewable_provenance_verified != true
}

deny_reason["maintenance task schedule exceeds the renewable energy budget"] {
    input.energy.total_projected_energy_j > input.energy.renewable_budget_j
}

deny_reason["assistance-panel states cannot require continuous connectivity"] {
    input.panel.requires_continuous_connectivity == true
}

deny_reason["assistance-panel access cannot require cybernetic or assistive-device disclosure"] {
    input.panel.requires_integration_disclosure == true
}

deny_reason["assistance-panel access requires accessible input and output modes"] {
    count(input.panel.enabled_input_modes) == 0
    count(input.panel.enabled_output_modes) == 0
}
