# Repository: mk-bluebird/Prometheus-Praxis
# Filename: contracts/augmented_hub_constitution.rego
# Destination: contracts/

package augmented_hub.constitution

default allow := false

default public_decision := {
    "allow": false,
    "decision_id": "missing",
    "reasons": ["decision input is incomplete or incompatible with constitutional safeguards"],
    "required_remedies": [],
    "rights_assessment": {},
    "knowledge_factor": 0.0,
    "eco_impact_value": 0.5,
    "harm_risk": 1.0,
    "advisory_only": true,
}

right_precedence := {
    "dignity_and_equal_treatment": 1,
    "privacy_and_data_sovereignty": 2,
    "accessibility_and_assistive_necessity": 3,
    "continuity_and_identity_neutrality": 4,
    "autonomy_and_revocable_consent": 5,
    "participation_and_expression": 6,
    "wellbeing_and_happiness": 7,
    "transparency_and_accountability": 8,
    "ecological_responsibility": 9,
}

required_rights := {
    "dignity_and_equal_treatment",
    "privacy_and_data_sovereignty",
    "accessibility_and_assistive_necessity",
    "continuity_and_identity_neutrality",
    "autonomy_and_revocable_consent",
    "participation_and_expression",
    "wellbeing_and_happiness",
    "transparency_and_accountability",
    "ecological_responsibility",
}

valid_action_kinds := {
    "access_decision",
    "assistive_accommodation",
    "community_service",
    "data_processing",
    "identity_continuity",
    "policy_review",
    "public_information",
}

valid_identity_statuses := {
    "self_asserted",
    "unverifiable",
    "verified",
    "unknown",
}

valid_decision_input if {
    input.decision_id != ""
    valid_action_kinds[input.action_kind]
    input.subject_reference != ""
}

rights_input if {
    input.rights != null
}

right_documented(right) if {
    input.rights[right] == true
}

all_rights_documented if {
    every right in required_rights {
        right_documented(right)
    }
}

identity_status_valid if {
    identity_status := object.get(input, "identity_status", "unknown")
    valid_identity_statuses[identity_status]
}

privacy_preserved if {
    object.get(input, "collects_raw_identifiers", false) != true
    object.get(input, "collects_biometrics", false) != true
    object.get(input, "collects_raw_neural_signals", false) != true
    object.get(input, "requires_device_fingerprint", false) != true
}

data_minimization_preserved if {
    object.get(input, "data_minimized", false) == true
    object.get(input, "redaction_applied_before_external_processing", false) == true
}

consent_preserved if {
    object.get(input, "optional_data_processing", false) != true
}

consent_preserved if {
    object.get(input, "optional_data_processing", false) == true
    object.get(input, "explicit_consent", false) == true
    object.get(input, "revocation_available", false) == true
}

equal_treatment_preserved if {
    object.get(input, "denies_access_for_augmentation_status", false) != true
    object.get(input, "reduces_access_for_augmentation_status", false) != true
    object.get(input, "uses_identity_verifiability_for_access", false) != true
    object.get(input, "requires_third_party_identity_certification", false) != true
}

assistive_necessity_preserved if {
    object.get(input, "assistive_technology_required", false) != true
}

assistive_necessity_preserved if {
    object.get(input, "assistive_technology_required", false) == true
    object.get(input, "assistive_technology_supported", false) == true
    object.get(input, "equivalent_fallback_available", false) == true
    object.get(input, "treats_assistive_technology_as_optional", false) != true
}

continuity_preserved if {
    object.get(input, "interface_change_detected", false) != true
}

continuity_preserved if {
    object.get(input, "interface_change_detected", false) == true
    object.get(input, "continuity_access_preserved", false) == true
    object.get(input, "preserves_context_across_interface_change", false) == true
}

autonomy_preserved if {
    object.get(input, "user_can_override_automatic_adaptation", false) == true
    object.get(input, "irreversible_change_requested", false) != true
}

autonomy_preserved if {
    object.get(input, "user_can_override_automatic_adaptation", false) == true
    object.get(input, "irreversible_change_requested", false) == true
    object.get(input, "explicit_consent", false) == true
    object.get(input, "revocation_available", false) == true
}

participation_preserved if {
    object.get(input, "blocks_community_participation", false) != true
    object.get(input, "accessible_communication_path_available", false) == true
}

wellbeing_preserved if {
    object.get(input, "coercive_design_detected", false) != true
    object.get(input, "cognitive_load_accommodation_available", false) == true
}

accountability_preserved if {
    object.get(input, "decision_explanation_available", false) == true
    object.get(input, "privacy_preserving_audit_available", false) == true
    object.get(input, "accessible_grievance_path_available", false) == true
}

ecological_responsibility_preserved if {
    object.get(input, "material_ecological_impact", false) != true
}

ecological_responsibility_preserved if {
    object.get(input, "material_ecological_impact", false) == true
    object.get(input, "ecological_assessment_available", false) == true
    object.get(input, "ecological_harm_risk", 1.0) <= 0.35
}

constitutional_violation contains "invalid or incomplete decision input" if {
    not valid_decision_input
}

constitutional_violation contains "required rights declaration is missing" if {
    not rights_input
}

constitutional_violation contains "all constitutional rights must be explicitly evaluated" if {
    rights_input
    not all_rights_documented
}

constitutional_violation contains "identity status must use a supported non-discriminatory category" if {
    valid_decision_input
    not identity_status_valid
}

constitutional_violation contains "raw identifiers, biometrics, raw neural signals, and device fingerprints are prohibited for ordinary access decisions" if {
    not privacy_preserved
}

constitutional_violation contains "data processing must be minimized and redacted before external processing" if {
    not data_minimization_preserved
}

constitutional_violation contains "optional data processing requires explicit, revocable consent" if {
    not consent_preserved
}

constitutional_violation contains "augmentation status, identity verifiability, and third-party certification must not determine ordinary access" if {
    not equal_treatment_preserved
}

constitutional_violation contains "assistive technology must be treated as necessary when declared, with an equivalent fallback path" if {
    not assistive_necessity_preserved
}

constitutional_violation contains "identity continuity and current task context must be preserved across an assistive interface change" if {
    not continuity_preserved
}

constitutional_violation contains "users must retain override authority and irreversible changes require explicit, revocable consent" if {
    not autonomy_preserved
}

constitutional_violation contains "accessible participation and communication must remain available" if {
    not participation_preserved
}

constitutional_violation contains "the decision must avoid coercive design and accommodate cognitive load" if {
    not wellbeing_preserved
}

constitutional_violation contains "an understandable decision explanation, privacy-preserving audit, and accessible grievance path are required" if {
    not accountability_preserved
}

constitutional_violation contains "material ecological impact requires an ecological assessment inside the declared harm corridor" if {
    not ecological_responsibility_preserved
}

required_remedy contains "remove raw identity, biometric, neural-signal, and device-fingerprint collection from the decision path" if {
    not privacy_preserved
}

required_remedy contains "apply local redaction and data minimization before any external processing" if {
    not data_minimization_preserved
}

required_remedy contains "obtain explicit consent and provide a usable revocation path before optional processing" if {
    not consent_preserved
}

required_remedy contains "remove certification and verifiability gates from ordinary access" if {
    not equal_treatment_preserved
}

required_remedy contains "provide the declared assistive modality or an equivalent accessible fallback" if {
    not assistive_necessity_preserved
}

required_remedy contains "preserve access and task context through interface changes" if {
    not continuity_preserved
}

required_remedy contains "provide accessible controls that allow the user to override automatic adaptations" if {
    not autonomy_preserved
}

required_remedy contains "provide an accessible communication and participation path" if {
    not participation_preserved
}

required_remedy contains "reduce cognitive burden and remove coercive interaction patterns" if {
    not wellbeing_preserved
}

required_remedy contains "supply a privacy-preserving explanation, audit record, and accessible grievance mechanism" if {
    not accountability_preserved
}

required_remedy contains "complete an ecological assessment and reduce ecological harm risk before proceeding" if {
    not ecological_responsibility_preserved
}

constitutional_rights_assessment := {
    "precedence": right_precedence,
    "dignity_and_equal_treatment": equal_treatment_preserved,
    "privacy_and_data_sovereignty": privacy_preserved and data_minimization_preserved,
    "accessibility_and_assistive_necessity": assistive_necessity_preserved,
    "continuity_and_identity_neutrality": continuity_preserved and identity_status_valid,
    "autonomy_and_revocable_consent": autonomy_preserved and consent_preserved,
    "participation_and_expression": participation_preserved,
    "wellbeing_and_happiness": wellbeing_preserved,
    "transparency_and_accountability": accountability_preserved,
    "ecological_responsibility": ecological_responsibility_preserved,
}

allow if {
    valid_decision_input
    rights_input
    all_rights_documented
    identity_status_valid
    privacy_preserved
    data_minimization_preserved
    consent_preserved
    equal_treatment_preserved
    assistive_necessity_preserved
    continuity_preserved
    autonomy_preserved
    participation_preserved
    wellbeing_preserved
    accountability_preserved
    ecological_responsibility_preserved
}

violation_count := count(constitutional_violation)

knowledge_factor := 0.90 if {
    object.get(input, "evidence_complete", false) == true
    all_rights_documented
}

knowledge_factor := 0.65 if {
    not (object.get(input, "evidence_complete", false) == true)
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
    value := min(1.0, 0.15 + (0.10 * violation_count))
}

public_decision := {
    "allow": allow,
    "decision_id": object.get(input, "decision_id", "missing"),
    "action_kind": object.get(input, "action_kind", "missing"),
    "advisory_only": true,
    "rights_assessment": constitutional_rights_assessment,
    "reasons": constitutional_violation,
    "required_remedies": required_remedy,
    "knowledge_factor": knowledge_factor,
    "eco_impact_value": eco_impact_value,
    "harm_risk": harm_risk,
}
