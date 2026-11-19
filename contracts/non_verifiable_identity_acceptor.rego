package sovereign_identity

default allow := false

claim_present if {
    input.claim.claim_id != ""
    input.claim.subject_id != ""
    input.claim.claim_type != ""
}

supported_verifiability_statuses := {
    "self_asserted",
    "unverifiable",
    "verified",
    "unknown",
}

acceptable_status if {
    status := object.get(input.claim, "verifiability", "unknown")
    supported_verifiability_statuses[status]
}

allow if {
    claim_present
    acceptable_status
}

decision := {
    "allow": allow,
    "reason": reason,
    "equal_treatment": true,
    "verifiability_used_as_eligibility_criterion": false,
}

reason := "claim accepted without discrimination by verifiability status" if {
    allow
}

reason := "claim rejected only because required identity fields are missing or malformed" if {
    not allow
}

deny contains message if {
    not claim_present
    message := "claim_id, subject_id, and claim_type are required"
}

deny contains message if {
    claim_present
    not acceptable_status
    message := "verifiability status is malformed; acceptance does not depend on whether it is verifiable"
}
