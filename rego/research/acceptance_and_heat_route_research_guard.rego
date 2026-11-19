package augmented_hub.research.acceptance_and_heat_route_research_guard

default allow_social_acceptance_research := false
default allow_heat_route_research := false
default require_human_review := false

prohibited_social_inputs := {
    "augmentation_status",
    "cybernetic_status",
    "assistive_device_status",
    "medical_record",
    "biometric_data",
    "facial_template",
    "voiceprint",
    "private_message",
    "employment_record",
    "education_record",
    "housing_record",
    "transit_history",
    "location_history",
    "device_telemetry"
}

prohibited_social_use := {
    "identity_validity_scoring",
    "service_eligibility",
    "service_denial",
    "employment_screening",
    "housing_screening",
    "insurance_pricing",
    "credit_scoring",
    "fraud_scoring",
    "surveillance_targeting",
    "social_scoring"
}

social_input_is_prohibited {
    input.social_research.input_types[_] == prohibited_social_inputs[_]
}

social_use_is_prohibited {
    prohibited_social_use[input.social_research.intended_use]
}

allow_social_acceptance_research {
    input.social_research.aggregate_only == true
    input.social_research.individual_tracking == false
    input.social_research.persistent_person_profiles == false
    input.social_research.public_methodology_available == true
    input.social_research.minimum_group_size_met == true
    input.social_research.accessible_correction_path_available == true
    input.social_research.human_review_available == true
    input.social_research.uses_identity_disclosure == false
    not social_input_is_prohibited
    not social_use_is_prohibited
}

heat_route_sensor_set_valid {
    input.heat_research.air_temperature_source_available == true
    input.heat_research.relative_humidity_source_available == true
    input.heat_research.wind_source_available == true
    input.heat_research.surface_temperature_proxy_available == true
    input.heat_research.shade_data_available == true
    input.heat_research.route_geometry_available == true
    input.heat_research.accessibility_data_available == true
    input.heat_research.cooling_resource_data_available == true
    input.heat_research.surface_temperature_labeled_as_proxy == true
    input.heat_research.uses_private_data == false
    input.heat_research.uses_person_tracking == false
    input.heat_research.uses_accessibility_cameras == false
}

allow_heat_route_research {
    heat_route_sensor_set_valid
    input.heat_research.advisory_only == true
    input.heat_research.public_methodology_available == true
    input.heat_research.accessible_explanation_available == true
    input.heat_research.correction_path_available == true
    input.heat_research.human_review_available == true
}

require_human_review {
    input.heat_research.relative_uncertainty > 0.20
}

require_human_review {
    input.heat_research.air_temperature_validation_available != true
}

deny_reason["social acceptance research may not require augmentation or cybernetic-status disclosure"] {
    input.social_research.uses_identity_disclosure == true
}

deny_reason["social acceptance research may not use private or identity-linked sensitive inputs"] {
    social_input_is_prohibited
}

deny_reason["social acceptance research may not be used for ranking eligibility enforcement or surveillance"] {
    social_use_is_prohibited
}

deny_reason["heat-route research requires public air temperature humidity wind surface proxy shade route accessibility and cooling-resource inputs"] {
    not heat_route_sensor_set_valid
}

deny_reason["satellite surface temperature must remain labeled as a proxy rather than personal exposure data"] {
    input.heat_research.surface_temperature_labeled_as_proxy != true
}

deny_reason["the minimum sensor design does not require accessibility cameras or person tracking"] {
    input.heat_research.uses_accessibility_cameras != false
}

deny_reason["heat-route results with uncertainty above twenty percent require human review before public prioritization"] {
    input.heat_research.relative_uncertainty > 0.20
}
