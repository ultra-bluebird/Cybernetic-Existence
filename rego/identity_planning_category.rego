package augmented_hub.identity_planning_category

default allow = false
default reason = "Planning category is not accepted because the self-declaration or stated infrastructure need is absent."

accepted_planning_category := {
    "category": input.self_declaration.category,
    "evidence_status": "self_declared_and_need_observed",
    "personal_data_collected": false,
    "external_certification_required": false,
    "review_path_available": true,
    "reason": reason,
}

allow if {
    self_declaration_present
    infrastructure_need_present
    requested_category_is_planning_relevant
}

reason := "The stated identity category is accepted for planning because it was self-declared and accompanied by an observable infrastructure need. No external certification, identity verification, medical record, biometric record, neural record, or device serial number is required."

self_declaration_present if {
    is_string(input.self_declaration.category)
    trimmed := trim(input.self_declaration.category, " ")
    count(trimmed) > 0
}

infrastructure_need_present if {
    some need in input.infrastructure_needs
    valid_infrastructure_need(need)
}

requested_category_is_planning_relevant if {
    category := lower(trim(input.self_declaration.category, " "))
    category != ""
}

valid_infrastructure_need(need) if {
    need.kind == "charging_requirement"
    is_number(need.minimum_power_watts)
    need.minimum_power_watts > 0
}

valid_infrastructure_need(need) if {
    need.kind == "thermal_comfort_requirement"
    is_number(need.maximum_safe_temperature_celsius)
    need.maximum_safe_temperature_celsius > 0
}

valid_infrastructure_need(need) if {
    need.kind == "mobility_clearance_requirement"
    is_number(need.minimum_clearance_millimeters)
    need.minimum_clearance_millimeters > 0
}

valid_infrastructure_need(need) if {
    need.kind == "low_latency_connectivity_requirement"
    is_number(need.maximum_latency_milliseconds)
    need.maximum_latency_milliseconds > 0
}
