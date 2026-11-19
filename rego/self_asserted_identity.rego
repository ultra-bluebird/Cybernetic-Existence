package augmentedhub.self_asserted_identity

default result := {
    "decision": "REJECTED_INVALID_INPUT",
    "identity_accepted": false,
    "conduct_boundary_required": false,
    "human_review_required": true,
    "reason": "A valid non-essential service request is required."
}

allowed_identity_type(type) if {
    type == "free_text"
}

allowed_identity_type(type) if {
    type == "chosen_name"
}

allowed_identity_type(type) if {
    type == "pronouns"
}

allowed_identity_type(type) if {
    type == "community_affiliation"
}

allowed_identity_type(type) if {
    type == "accessibility_communication_preference"
}

allowed_identity_type(type) if {
    type == "self_described_cybernetic_host_status"
}

valid_assertion if {
    input.service.essential == false
    is_object(input.identity_assertion)
    allowed_identity_type(input.identity_assertion.type)
    is_string(input.identity_assertion.value)
    count(trim(input.identity_assertion.value, " ")) > 0
    count(input.identity_assertion.value) <= 280
}

harm_evidence_present if {
    is_object(input.conduct_evidence)
    input.conduct_evidence.verified == true
    input.conduct_evidence.policy_relevant == true
    input.conduct_evidence.context_bound == true
    input.conduct_evidence.identity_based == false
    input.conduct_evidence.reviewable == true
}

service_safety_constraint_unsatisfied if {
    input.service.safety_constraint_satisfied == false
}

result := {
    "decision": "ACCEPTED",
    "identity_accepted": true,
    "conduct_boundary_required": false,
    "human_review_required": false,
    "reason": "The self-asserted identity is accepted without certification or scoring."
} if {
    valid_assertion
    not harm_evidence_present
    not service_safety_constraint_unsatisfied
}

result := {
    "decision": "ACCEPTED_WITH_CONDUCT_BOUNDARY",
    "identity_accepted": true,
    "conduct_boundary_required": true,
    "human_review_required": true,
    "reason": "The identity remains accepted. A narrow, reviewable conduct boundary is required for verified context-specific behavior."
} if {
    valid_assertion
    harm_evidence_present
    not service_safety_constraint_unsatisfied
}

result := {
    "decision": "SERVICE_SAFETY_REVIEW",
    "identity_accepted": true,
    "conduct_boundary_required": false,
    "human_review_required": true,
    "reason": "The identity is accepted. A human review is required because a separate service safety constraint is not satisfied."
} if {
    valid_assertion
    service_safety_constraint_unsatisfied
}
