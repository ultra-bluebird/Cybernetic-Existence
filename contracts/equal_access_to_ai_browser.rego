package augmented_hub.equal_access_to_ai_browser

default allow := false

default augmentation_neutral := false
default assistive_compatible := false
default privacy_respecting := false
default continuity_preserving := false
default fallback_available := false

valid_request if {
    object.get(input, "request_id", "") != ""
    object.get(input, "user_reference", "") != ""
    object.get(input, "requested_feature", "") != ""
}

augmentation_neutral if {
    object.get(input, "feature_assumes_non_augmented_user", false) != true
    object.get(input, "denies_augmented_users", false) != true
    object.get(input, "reduces_access_for_augmentation_status", false) != true
}

assistive_compatible if {
    object.get(input, "assistive_technology_required", false) != true
}

assistive_compatible if {
    object.get(input, "assistive_technology_required", false) == true
    object.get(input, "assistive_technology_supported", false) == true
}

continuity_preserving if {
    object.get(input, "interface_change_detected", false) != true
}

continuity_preserving if {
    object.get(input, "interface_change_detected", false) == true
    object.get(input, "continuity_access_preserved", false) == true
}

privacy_respecting if {
    object.get(input, "requires_raw_identifier", false) != true
    object.get(input, "requires_biometric_disclosure", false) != true
    object.get(input, "requires_device_fingerprint", false) != true
}

fallback_available if {
    object.get(input, "assistive_technology_required", false) != true
}

fallback_available if {
    object.get(input, "assistive_technology_required", false) == true
    object.get(input, "equivalent_fallback_available", false) == true
}

allow if {
    valid_request
    augmentation_neutral
    assistive_compatible
    privacy_respecting
    continuity_preserving
    fallback_available
}

decision := {
    "request_id": object.get(input, "request_id", "missing"),
    "allow": allow,
    "augmentation_neutral": augmentation_neutral,
    "assistive_compatible": assistive_compatible,
    "privacy_respecting": privacy_respecting,
    "continuity_preserving": continuity_preserving,
    "equivalent_fallback_available": fallback_available,
    "knowledge_factor": knowledge_factor,
    "eco_impact_value": eco_impact_value,
    "harm_risk": harm_risk,
    "reasons": reasons,
}

reasons contains "request_id, user_reference, and requested_feature are required" if {
    not valid_request
}

reasons contains "features must not assume a non-augmented user by default" if {
    object.get(input, "feature_assumes_non_augmented_user", false) == true
}

reasons contains "augmentation status must not be used to deny or reduce access" if {
    object.get(input, "denies_augmented_users", false) == true
}

reasons contains "declared assistive technology is not supported" if {
    object.get(input, "assistive_technology_required", false) == true
    object.get(input, "assistive_technology_supported", false) != true
}

reasons contains "an equivalent fallback path is required when assistive technology is needed" if {
    object.get(input, "assistive_technology_required", false) == true
    object.get(input, "equivalent_fallback_available", false) != true
}

reasons contains "continuity of access must be preserved after an interface change" if {
    object.get(input, "interface_change_detected", false) == true
    object.get(input, "continuity_access_preserved", false) != true
}

reasons contains "raw identifiers, biometric disclosure, and device fingerprints are not required for equal browser access" if {
    not privacy_respecting
}

violation_count := count(reasons)

knowledge_factor := 0.90 if {
    object.get(input, "evidence_complete", false) == true
}

knowledge_factor := 0.60 if {
    object.get(input, "evidence_complete", false) != true
}

eco_impact_value := value if {
    value := object.get(input, "eco_impact_value", 0.50)
    value >= 0
    value <= 1
}

eco_impact_value := 0.50 if {
    value := object.get(input, "eco_impact_value", 0.50)
    not value >= 0
}

eco_impact_value := 0.50 if {
    value := object.get(input, "eco_impact_value", 0.50)
    not value <= 1
}

harm_risk := 0.05 if {
    allow
}

harm_risk := value if {
    not allow
    value := min(1.0, 0.15 + (0.14 * violation_count))
}
