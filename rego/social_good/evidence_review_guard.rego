package augmented_hub.social_good.evidence_review

default allow_advisory_use := false

required_top_level := {
    "concept_id",
    "domain",
    "evidence",
    "derived_metrics",
    "uncertainty",
    "ker_assessment",
    "review",
    "accessible_explanation",
}

missing_required_field[field] {
    field := required_top_level[_]
    not input[field]
}

allow_advisory_use {
    count(missing_required_field) == 0
    input.review.human_review_required == true
    input.review.appeal_available == true
    input.accessible_explanation.plain_language_summary != ""
    input.accessible_explanation.limitations != ""
    input.accessible_explanation.recommended_next_step != ""
    input.ker_assessment.knowledge_factor >= 0.60
    input.ker_assessment.eco_impact_value >= 0.50
    input.ker_assessment.harm_risk <= 0.45
    input.ker_assessment.accessibility_impact >= 0.70
    input.ker_assessment.rights_alignment >= 0.80
    not requires_continuous_connectivity
    not requires_optional_telemetry
    not requires_biometric_data
    not automatically_actuates
    not missing_uncertainty
}

requires_continuous_connectivity {
    input.requires_continuous_connectivity == true
}

requires_optional_telemetry {
    input.requires_optional_telemetry == true
}

requires_biometric_data {
    input.uses_biometric_identification == true
}

automatically_actuates {
    input.automatically_actuates_machinery == true
}

missing_uncertainty {
    count(input.uncertainty) == 0
}

deny_reason["a required shared-foundation field is missing"] {
    count(missing_required_field) > 0
}

deny_reason["human review is required for advisory use"] {
    input.review.human_review_required != true
}

deny_reason["an accessible appeal path is required"] {
    input.review.appeal_available != true
}

deny_reason["the explanation must state limitations"] {
    input.accessible_explanation.limitations == ""
}

deny_reason["knowledge factor is below the foundation threshold"] {
    input.ker_assessment.knowledge_factor < 0.60
}

deny_reason["eco-impact value is below the foundation threshold"] {
    input.ker_assessment.eco_impact_value < 0.50
}

deny_reason["harm risk exceeds the foundation threshold"] {
    input.ker_assessment.harm_risk > 0.45
}

deny_reason["accessibility impact is below the foundation threshold"] {
    input.ker_assessment.accessibility_impact < 0.70
}

deny_reason["rights alignment is below the foundation threshold"] {
    input.ker_assessment.rights_alignment < 0.80
}

deny_reason["continuous connectivity cannot be required for essential access"] {
    requires_continuous_connectivity
}

deny_reason["optional telemetry cannot be required for essential access"] {
    requires_optional_telemetry
}

deny_reason["biometric identification is not permitted by this foundation"] {
    requires_biometric_data
}

deny_reason["the foundation is advisory-only and cannot actuate machinery"] {
    automatically_actuates
}

deny_reason["every advisory recommendation requires a visible uncertainty record"] {
    missing_uncertainty
}
