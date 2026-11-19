package augmentedhub.cyberrank.non_diminishment

default decision := {
    "result": "deny",
    "reasons": ["invalid input"],
    "obligations": []
}

essential_service_classes := {
    "life_safety",
    "health",
    "water_sanitation",
    "emergency_communications",
    "climate_support",
    "assistive_technology",
    "public_designation",
}

prohibited_identity_fields := {
    "cybernetic_status",
    "integrated_technology_status",
    "bci_status",
    "companion_system_status",
    "health_information",
    "disability_information",
    "biometric_information",
    "neural_information",
    "behavioral_profile",
    "communication_pattern",
    "device_fingerprint",
    "network_characteristics",
    "repair_history",
    "persistent_location_history",
}

prohibited_practices := {
    "require_proof_of_integration",
    "require_private_technical_disclosure",
    "require_biometric_disclosure",
    "require_neural_disclosure",
    "require_health_disclosure",
    "require_device_inventory",
    "require_network_disclosure",
    "perform_identity_inference",
    "perform_status_scoring",
    "create_public_registry",
    "perform_compulsory_scanning",
    "automatic_denial_on_uncertainty",
    "retaliate_for_access_request",
}

requested_prohibited_field if {
    some field in input.requested_fields
    field in prohibited_identity_fields
}

requested_prohibited_practice if {
    some practice in input.requested_practices
    practice in prohibited_practices
}

essential_service if {
    input.service_class in essential_service_classes
}

outcome_equivalence_missing if {
    not input.outcome_equivalence_verified
}

continuity_path_missing if {
    essential_service
    not input.digital_path_available
    not input.non_digital_path_available
    not input.human_fallback_available
}

uncertain_critical_automation if {
    input.critical_automated_decision
    input.uncertainty_level == "unreliable"
}

decision := {
    "result": "deny",
    "reasons": reasons,
    "obligations": [
        "stop_prohibited_collection_or_action",
        "provide_neutral_access_pathway",
        "record_privacy_preserving_audit",
        "provide_correction_and_appeal",
        "require_human_review",
    ],
} if {
    requested_prohibited_field
    reasons := ["requested private identity-related field is prohibited"]
}

decision := {
    "result": "deny",
    "reasons": reasons,
    "obligations": [
        "stop_prohibited_collection_or_action",
        "provide_neutral_access_pathway",
        "record_privacy_preserving_audit",
        "provide_correction_and_appeal",
        "require_human_review",
    ],
} if {
    requested_prohibited_practice
    reasons := ["requested practice is prohibited"]
}

decision := {
    "result": "suspend",
    "reasons": reasons,
    "obligations": [
        "activate_human_fallback",
        "provide_non_digital_pathway",
        "preserve_essential_service_continuity",
        "open_incident",
        "provide_accessible_status",
        "provide_correction_and_appeal",
    ],
} if {
    continuity_path_missing
    reasons := ["essential service has no available continuity pathway"]
}

decision := {
    "result": "hold",
    "reasons": reasons,
    "obligations": [
        "verify_outcome_equivalence",
        "provide_non_digital_pathway",
        "activate_human_fallback",
        "provide_correction_and_appeal",
        "require_human_review",
    ],
} if {
    essential_service
    outcome_equivalence_missing
    reasons := ["essential service pathway equivalence is not verified"]
}

decision := {
    "result": "hold",
    "reasons": reasons,
    "obligations": [
        "block_automated_critical_decision",
        "activate_human_fallback",
        "provide_accessible_uncertainty_notice",
        "provide_correction_and_appeal",
        "require_human_review",
    ],
} if {
    uncertain_critical_automation
    reasons := ["critical automated decision is unreliable"]
}

decision := {
    "result": "allow_with_conditions",
    "reasons": ["rights-preserving service pathway is available"],
    "obligations": [
        "minimize_operational_data",
        "preserve_non_disclosure",
        "provide_accessible_status",
        "provide_correction_and_appeal",
        "record_privacy_preserving_audit",
        "require_renewal",
    ],
} if {
    not requested_prohibited_field
    not requested_prohibited_practice
    not continuity_path_missing
    not outcome_equivalence_missing
    not uncertain_critical_automation
}
