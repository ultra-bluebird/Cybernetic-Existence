package smart_city.non_discriminatory_policy

default allow := false

required_criteria := {
    "self_asserted_identity_inclusion",
    "no_certification_gate",
    "privacy_protection",
    "continuity_protection",
    "meaningful_social_impact",
    "equal_treatment",
}

policy_id_valid if {
    object.get(input.policy, "policy_id", "") != ""
}

criteria_valid if {
    criteria := object.get(input.policy, "criteria", {})
    every criterion in required_criteria {
        criteria[criterion] == true
    }
}

self_asserted_identity_included if {
    input.policy.criteria.self_asserted_identity_inclusion == true
}

no_certification_gate if {
    input.policy.criteria.no_certification_gate == true
}

privacy_protected if {
    input.policy.criteria.privacy_protection == true
}

continuity_protected if {
    input.policy.criteria.continuity_protection == true
}

meaningful_social_impact if {
    input.policy.criteria.meaningful_social_impact == true
}

equal_treatment_provided if {
    input.policy.criteria.equal_treatment == true
}

certification_gate_detected if {
    input.policy.requires_third_party_certification == true
}

identity_status_used_for_access if {
    input.policy.uses_verifiability_for_access == true
}

raw_identity_collection_detected if {
    input.policy.collects_raw_identifiers == true
}

continuity_penalty_detected if {
    input.policy.penalizes_interface_change == true
}

assistive_need_ignored if {
    input.policy.assistive_accommodation_required == true
    input.policy.assistive_accommodation_provided != true
}

allow if {
    policy_id_valid
    criteria_valid
    not certification_gate_detected
    not identity_status_used_for_access
    not raw_identity_collection_detected
    not continuity_penalty_detected
    not assistive_need_ignored
}

decision := {
    "policy_id": object.get(input.policy, "policy_id", "missing"),
    "allow": allow,
    "equal_treatment_required": true,
    "self_asserted_identity_included": self_asserted_identity_included,
    "no_certification_gate": no_certification_gate,
    "privacy_protected": privacy_protected,
    "continuity_protected": continuity_protected,
    "meaningful_social_impact": meaningful_social_impact,
    "equal_treatment_provided": equal_treatment_provided,
    "harm_risk": harm_risk,
    "knowledge_factor": knowledge_factor,
    "eco_impact_value": eco_impact_value,
    "reasons": reasons,
}

reasons contains "policy_id is required" if {
    not policy_id_valid
}

reasons contains "self-asserted identity inclusion is required" if {
    not self_asserted_identity_included
}

reasons contains "third-party certification gate is prohibited" if {
    certification_gate_detected
}

reasons contains "identity verifiability must not determine service access" if {
    identity_status_used_for_access
}

reasons contains "privacy protection is required" if {
    not privacy_protected
}

reasons contains "raw identity collection is prohibited for this policy class" if {
    raw_identity_collection_detected
}

reasons contains "continuity protection is required" if {
    not continuity_protected
}

reasons contains "interface changes must not be penalized" if {
    continuity_penalty_detected
}

reasons contains "meaningful social impact evidence is required" if {
    not meaningful_social_impact
}

reasons contains "equal treatment is required" if {
    not equal_treatment_provided
}

reasons contains "declared assistive accommodation requirement was not met" if {
    assistive_need_ignored
}

violation_count := count(reasons)

harm_risk := 0.05 if {
    allow
}

harm_risk := risk if {
    not allow
    risk := min(1.0, 0.15 + (0.12 * violation_count))
}

knowledge_factor := 0.90 if {
    object.get(input.policy, "evidence_complete", false) == true
}

knowledge_factor := 0.60 if {
    object.get(input.policy, "evidence_complete", false) != true
}

eco_impact_value := impact if {
    impact := object.get(input.policy, "eco_impact_value", 0.50)
    impact >= 0
    impact <= 1
}

eco_impact_value := 0.50 if {
    impact := object.get(input.policy, "eco_impact_value", 0.50)
    not impact >= 0
}

eco_impact_value := 0.50 if {
    impact := object.get(input.policy, "eco_impact_value", 0.50)
    not impact <= 1
}
