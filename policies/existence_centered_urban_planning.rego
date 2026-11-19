package augmented_hub.existence_centered_urban_planning

default allow_scenario = false

default denial_reason = "Scenario does not yet provide verified continuity evidence for the required public-space coverage threshold."

required_public_space_continuity_basis_points := 9500

allow_scenario if {
    valid_scenario
    continuity_coverage_meets_hard_constraint
    no_identity_certification_required
    no_personal_telemetry_required
    accessible_review_path_present
}

valid_scenario if {
    input.scenario_name != ""
    is_number(input.public_space_count)
    input.public_space_count > 0
    is_number(input.qualifying_public_space_count)
    input.qualifying_public_space_count >= 0
    input.qualifying_public_space_count <= input.public_space_count
    is_number(input.continuity_evidence_basis_points)
    input.continuity_evidence_basis_points >= 0
    input.continuity_evidence_basis_points <= 10000
}

continuity_coverage_meets_hard_constraint if {
    coverage_basis_points := public_space_coverage_basis_points
    coverage_basis_points >= required_public_space_continuity_basis_points
    input.continuity_evidence_basis_points >= required_public_space_continuity_basis_points
}

no_identity_certification_required if {
    input.requires_external_identity_certification == false
}

no_personal_telemetry_required if {
    input.requires_personal_telemetry == false
}

accessible_review_path_present if {
    input.accessible_review_path_available == true
}

public_space_coverage_basis_points := coverage_basis_points if {
    coverage_basis_points := floor(
        input.qualifying_public_space_count * 10000
        / input.public_space_count
    )
}

governance_assessment := {
    "scenario_name": input.scenario_name,
    "planning_category": "self_asserted_augmented_or_assistive_access_need",
    "public_space_coverage_basis_points": public_space_coverage_basis_points,
    "required_coverage_basis_points": required_public_space_continuity_basis_points,
    "continuity_evidence_basis_points": input.continuity_evidence_basis_points,
    "hard_constraint_satisfied": allow_scenario,
    "external_identity_certification_required": false,
    "personal_telemetry_required": false,
    "accessible_review_path_available": input.accessible_review_path_available,
    "decision": decision,
    "reason": assessment_reason,
}

decision := "allow" if {
    allow_scenario
}

decision := "deny_pending_remediation" if {
    not allow_scenario
}

assessment_reason := "Scenario satisfies the hard public-space continuity requirement without requiring identity certification or personal telemetry." if {
    allow_scenario
}

assessment_reason := denial_reason if {
    not allow_scenario
}
