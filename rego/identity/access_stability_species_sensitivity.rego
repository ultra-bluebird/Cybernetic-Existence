package augmented_hub.identity.access_stability_species_sensitivity

default allow_essential_access := false
default allow_integration_data_use := false
default require_community_review := false
default require_ecological_review := false

essential_services := {
    "public_transit_information",
    "public_transit_access",
    "shade_information",
    "cooling_information",
    "water_information",
    "water_quality_reporting",
    "maintenance_reporting",
    "grievance_submission",
    "appeal_submission",
    "public_participation",
    "emergency_information",
    "accessibility_support"
}

prohibited_integration_uses := {
    "service_eligibility",
    "service_denial",
    "employment_screening",
    "housing_screening",
    "insurance_pricing",
    "credit_scoring",
    "fraud_scoring",
    "surveillance_targeting",
    "social_scoring",
    "marketing",
    "behavioral_profiling"
}

allow_essential_access {
    essential_services[input.request.service]
    input.request.stated_identity != ""
    not input.request.requires_identity_certificate
    not input.request.requires_medical_documentation
    not input.request.requires_device_identifier
    not input.request.requires_biometric_identification
    not input.request.requires_integration_data
    not input.request.requires_continuous_telemetry
    not input.request.requires_continuous_connectivity
}

deny_reason["essential access cannot require identity certification"] {
    essential_services[input.request.service]
    input.request.requires_identity_certificate
}

deny_reason["essential access cannot require medical documentation"] {
    essential_services[input.request.service]
    input.request.requires_medical_documentation
}

deny_reason["essential access cannot require a device identifier"] {
    essential_services[input.request.service]
    input.request.requires_device_identifier
}

deny_reason["essential access cannot require biometric identification"] {
    essential_services[input.request.service]
    input.request.requires_biometric_identification
}

deny_reason["essential access cannot require cybernetic integration data"] {
    essential_services[input.request.service]
    input.request.requires_integration_data
}

deny_reason["essential access cannot require continuous telemetry"] {
    essential_services[input.request.service]
    input.request.requires_continuous_telemetry
}

deny_reason["essential access cannot require continuous connectivity"] {
    essential_services[input.request.service]
    input.request.requires_continuous_connectivity
}

allow_integration_data_use {
    input.integration_data.provided_voluntarily == true
    input.integration_data.explicit_consent == true
    input.integration_data.specific_purpose != ""
    input.integration_data.necessary_for_purpose == true
    input.integration_data.retention_days > 0
    input.integration_data.retention_days <= 365
    input.integration_data.revocation_available == true
    input.integration_data.export_available == true
    input.integration_data.deletion_available == true
    not prohibited_integration_uses[input.integration_data.specific_purpose]
}

deny_reason["integration data is sensitive and requires explicit voluntary consent"] {
    input.integration_data.provided_voluntarily != true
}

deny_reason["integration data requires a specific documented purpose"] {
    input.integration_data.specific_purpose == ""
}

deny_reason["integration data cannot be used for the requested purpose"] {
    prohibited_integration_uses[input.integration_data.specific_purpose]
}

deny_reason["integration data requires revocation export and deletion paths"] {
    input.integration_data.revocation_available != true
}

social_residual_increased {
    input.social_metrics.current_residual >
    input.social_metrics.previous_residual + input.social_metrics.tolerance
}

require_community_review {
    social_residual_increased
}

require_community_review {
    input.social_metrics.uncertainty_score > 0.35
}

require_community_review {
    input.social_metrics.minimum_group_size < input.policy.minimum_group_size
}

species_protection_review {
    input.ecological_proposal.potential_species_impact == true
    input.ecological_proposal.welfare_concern == true
}

species_protection_review {
    input.ecological_proposal.potential_species_impact == true
    input.ecological_proposal.habitat_concern == true
}

species_protection_review {
    input.ecological_proposal.potential_species_impact == true
    input.ecological_proposal.biodiversity_concern == true
}

species_protection_review {
    input.ecological_proposal.potential_species_impact == true
    input.ecological_proposal.material_uncertainty == true
}

require_ecological_review {
    species_protection_review
}

deny_reason["a proposal with potential species impact requires ecological review"] {
    species_protection_review
}

deny_reason["species membership alone cannot remove basic ecological protection"] {
    input.ecological_proposal.protection_denied_due_to_species_membership == true
}

deny_reason["ecological benefit cannot offset an unresolved species-harm concern"] {
    input.ecological_proposal.species_harm_above_review_threshold == true
    input.ecological_proposal.claimed_eco_benefit > 0
}
