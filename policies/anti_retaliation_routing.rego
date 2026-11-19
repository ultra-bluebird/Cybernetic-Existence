package augmented_hub.anti_retaliation_routing

default allow_assignment := false
default require_independent_reviewer := true
default prohibit_implicated_party_access := true

protected_report_categories := {
    "retaliation",
    "discrimination",
    "harassment",
    "privacy_violation",
    "consent_violation",
    "rights_violation",
    "governance_conflict",
    "safety_concern",
    "operator_misconduct",
    "authority_misconduct",
}

independent_reviewer_roles := {
    "independent_reviewer",
    "ombuds_reviewer",
    "external_governance_reviewer",
    "rights_and_access_reviewer",
}

case_requires_independent_routing if {
    input.case.category in protected_report_categories
}

case_requires_independent_routing if {
    input.case.implicates_project_operator == true
}

case_requires_independent_routing if {
    input.case.implicates_local_authority == true
}

case_requires_independent_routing if {
    count(input.case.implicated_party_ids) > 0
}

reviewer_has_conflict if {
    input.reviewer.person_id == input.case.implicated_party_ids[_]
}

reviewer_has_conflict if {
    input.reviewer.organization_id != ""
    input.reviewer.organization_id == input.case.implicated_organization_ids[_]
}

reviewer_has_conflict if {
    input.reviewer.supervises_implicated_party_ids[_]
}

reviewer_has_conflict if {
    input.reviewer.is_project_operator == true
    input.case.implicates_project_operator == true
}

reviewer_has_conflict if {
    input.reviewer.is_local_authority_representative == true
    input.case.implicates_local_authority == true
}

reviewer_is_eligible if {
    input.reviewer.role in independent_reviewer_roles
    not reviewer_has_conflict
    input.reviewer.completed_anti_retaliation_training == true
    input.reviewer.access_scope == "independent_case_review"
}

allow_assignment if {
    case_requires_independent_routing
    reviewer_is_eligible
    input.assignment.route == "independent_review"
    input.assignment.access_mode == "least_privilege"
    input.assignment.implicated_parties_notified == false
    input.assignment.contact_envelope_access == false
}

allow_assignment if {
    not case_requires_independent_routing
    not reviewer_has_conflict
    input.assignment.route == "standard_review"
    input.assignment.access_mode == "least_privilege"
}

deny_reason contains "Protected case requires independent reviewer routing." if {
    case_requires_independent_routing
    input.assignment.route != "independent_review"
}

deny_reason contains "Implicated parties may not review or receive identifying case access." if {
    reviewer_has_conflict
}

deny_reason contains "Reviewer lacks an independent review role." if {
    case_requires_independent_routing
    not input.reviewer.role in independent_reviewer_roles
}

deny_reason contains "Reviewer must complete anti-retaliation training." if {
    case_requires_independent_routing
    input.reviewer.completed_anti_retaliation_training != true
}

deny_reason contains "Protected case assignment must not notify implicated parties." if {
    case_requires_independent_routing
    input.assignment.implicated_parties_notified == true
}

deny_reason contains "Protected case assignment must not grant contact-envelope access." if {
    case_requires_independent_routing
    input.assignment.contact_envelope_access == true
}

routing_decision := {
    "independent_review_required": case_requires_independent_routing,
    "reviewer_eligible": reviewer_is_eligible,
    "assignment_allowed": allow_assignment,
    "implicated_party_access_prohibited": prohibit_implicated_party_access,
}
