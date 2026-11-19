package augmented_hub.identity.acceptance_continuity_unity

default allow_aggregate_analysis := false
default allow_contribution_record := false

prohibited_graph_sources := {
    "private_message",
    "medical_record",
    "employment_record",
    "school_record",
    "biometric_data",
    "voiceprint",
    "facial_template",
    "location_history",
    "device_telemetry",
    "private_support_community"
}

prohibited_identity_uses := {
    "identity_validity_scoring",
    "identity_authenticity_scoring",
    "social_scoring",
    "service_eligibility",
    "service_denial",
    "employment_screening",
    "housing_screening",
    "insurance_pricing",
    "credit_scoring",
    "fraud_scoring",
    "surveillance_targeting"
}

allow_aggregate_analysis {
    input.analysis.scope == "aggregate_public_discourse"
    input.analysis.identifies_individuals == false
    input.analysis.stores_persistent_speaker_profiles == false
    input.analysis.uses_biometric_identification == false
    input.analysis.uses_private_communications == false
    input.analysis.minimum_group_size >= input.policy.minimum_group_size
    input.analysis.annotation_quality >= 0.70
    input.analysis.source_diversity >= 0.60
    input.analysis.public_methodology_available == true
    input.analysis.uncertainty_reported == true
    input.analysis.human_review_available == true
    input.analysis.appeal_path_available == true
    not prohibited_source_present
}

prohibited_source_present {
    source := input.analysis.source_types[_]
    prohibited_graph_sources[source]
}

identity_protection_required {
    input.identity.self_asserted == true
}

identity_protection_required {
    input.identity.continuity_of_existence == "protected"
}

deny_reason["a sentiment graph may not identify individuals"] {
    input.analysis.identifies_individuals == true
}

deny_reason["a sentiment graph may not maintain speaker profiles"] {
    input.analysis.stores_persistent_speaker_profiles == true
}

deny_reason["private or sensitive data sources are prohibited"] {
    prohibited_source_present
}

deny_reason["biometric identification is prohibited"] {
    input.analysis.uses_biometric_identification == true
}

deny_reason["aggregate analysis requires documented uncertainty"] {
    input.analysis.uncertainty_reported != true
}

deny_reason["aggregate analysis requires a public methodology"] {
    input.analysis.public_methodology_available != true
}

deny_reason["aggregate analysis requires accessible review and appeal"] {
    input.analysis.human_review_available != true
}

deny_reason["the requested use is prohibited for self-asserted identity data"] {
    prohibited_identity_uses[input.request.purpose]
}

deny_reason["cybernetic status must not reduce a service outcome"] {
    input.decision.outcome_with_cybernetic_status < input.decision.outcome_without_cybernetic_status
}

deny_reason["identity-linked status cannot be used as a penalty feature"] {
    input.decision.cybernetic_status_effect == "penalty"
}

allow_contribution_record {
    input.contribution.is_voluntary == true
    input.contribution.requires_identity_disclosure == false
    input.contribution.requires_biometric_identification == false
    input.contribution.cybernetic_status_used_in_eco_formula == false
    input.contribution.rights_not_conditioned_on_eco_score == true
    input.contribution.ecological_method_documented == true
    input.contribution.uncertainty_reported == true
    input.contribution.accessible_explanation_available == true
    input.contribution.human_review_available == true
}

deny_reason["eco-impact cannot be used as a condition of rights or essential access"] {
    input.contribution.rights_not_conditioned_on_eco_score != true
}

deny_reason["cybernetic status cannot affect eco-impact calculation"] {
    input.contribution.cybernetic_status_used_in_eco_formula == true
}

deny_reason["contribution recognition must remain voluntary"] {
    input.contribution.is_voluntary != true
}

deny_reason["ecological contribution records require method and uncertainty disclosure"] {
    input.contribution.ecological_method_documented != true
}

deny_reason["ecological contribution records require uncertainty disclosure"] {
    input.contribution.uncertainty_reported != true
}
