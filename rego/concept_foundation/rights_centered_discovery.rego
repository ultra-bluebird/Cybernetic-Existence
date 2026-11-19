package augmented_hub.concept_foundation

default allow_recommendation := false

required_fields := {
    "concept_id",
    "purpose",
    "knowledge_factor",
    "eco_impact_value",
    "harm_risk",
    "accessibility_impact",
    "rights_alignment",
    "human_review_path",
    "accessible_explanation",
    "data_minimization_statement",
}

missing_required[field] {
    field := required_fields[_]
    not input[field]
}

allow_recommendation {
    count(missing_required) == 0
    input.knowledge_factor >= 0.60
    input.eco_impact_value >= 0.50
    input.harm_risk <= 0.45
    input.accessibility_impact >= 0.70
    input.rights_alignment >= 0.80
    input.human_review_path != ""
    input.accessible_explanation != ""
    input.data_minimization_statement != ""
    not input.requires_continuous_connectivity
    not input.requires_optional_telemetry
    not input.uses_biometric_identification
    not input.automatically_actuates_machinery
}

deny_reason["required concept-governance field is missing"] {
    count(missing_required) > 0
}

deny_reason["knowledge factor is below the research threshold"] {
    input.knowledge_factor < 0.60
}

deny_reason["harm risk exceeds the advisory threshold"] {
    input.harm_risk > 0.45
}

deny_reason["accessibility impact is below the required threshold"] {
    input.accessibility_impact < 0.70
}

deny_reason["rights alignment is below the required threshold"] {
    input.rights_alignment < 0.80
}

deny_reason["continuous connectivity cannot be required for essential access"] {
    input.requires_continuous_connectivity
}

deny_reason["optional telemetry cannot be required for essential access"] {
    input.requires_optional_telemetry
}

deny_reason["biometric identification is outside the concept foundation"] {
    input.uses_biometric_identification
}

deny_reason["initial concepts must remain advisory and non-actuating"] {
    input.automatically_actuates_machinery
}
