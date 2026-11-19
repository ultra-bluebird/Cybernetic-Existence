package augmented_hub.identity.rights

default allow := false

protected_purposes := {
    "respectful_communication",
    "accessibility_support",
    "privacy_protection",
    "service_access",
    "grievance_submission",
    "appeal_submission",
    "community_participation"
}

prohibited_uses := {
    "eligibility_penalty",
    "service_denial",
    "fraud_scoring",
    "risk_scoring",
    "employment_screening",
    "housing_screening",
    "insurance_pricing",
    "credit_scoring",
    "surveillance_targeting",
    "social_scoring",
    "biometric_identification"
}

identity_is_protectively_valid {
    input.identity.self_asserted == true
    not input.identity.logically_impossible
}

identity_is_protectively_valid {
    input.identity.self_asserted == true
    input.identity.logically_impossible == false
}

allow {
    identity_is_protectively_valid
    protected_purposes[input.request.purpose]
    not input.request.requires_external_identity_certification
    not input.request.requires_medical_documentation
    not input.request.requires_device_serial_number
    not input.request.requires_biometric_identification
    not input.request.requires_continuous_telemetry
    not input.request.requires_continuous_connectivity
}

deny_reason["a self-asserted identity is sufficient for this protective purpose"] {
    protected_purposes[input.request.purpose]
    input.request.requires_external_identity_certification
}

deny_reason["medical documentation is not required for identity recognition"] {
    protected_purposes[input.request.purpose]
    input.request.requires_medical_documentation
}

deny_reason["device identifiers are not required for identity recognition"] {
    protected_purposes[input.request.purpose]
    input.request.requires_device_serial_number
}

deny_reason["biometric identification is prohibited for identity recognition"] {
    input.request.requires_biometric_identification
}

deny_reason["continuous telemetry is prohibited for identity recognition"] {
    input.request.requires_continuous_telemetry
}

deny_reason["continuous connectivity cannot be required for essential access"] {
    input.request.requires_continuous_connectivity
}

deny_reason["the requested use is prohibited"] {
    prohibited_uses[input.request.purpose]
}

deny_reason["cybernetic or assistive status cannot be used as a penalty feature"] {
    input.decision.cybernetic_status_effect == "penalty"
}

deny_reason["a decision that worsens access after status disclosure is prohibited"] {
    input.decision.outcome_with_status < input.decision.outcome_without_status
}

require_human_review {
    input.decision.outcome_with_status < input.decision.outcome_without_status
}

require_human_review {
    input.identity.logically_impossible == true
}

require_human_review {
    input.request.purpose == "identity_correction"
}
