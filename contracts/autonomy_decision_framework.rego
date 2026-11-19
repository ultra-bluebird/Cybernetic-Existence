# Repository: mk-bluebird/Prometheus-Praxis
# Filename: contracts/autonomy_decision_framework.rego
# Destination: contracts/

package augmented_hub.autonomy_decision

default allow := false

default decision := {
    "allow": false,
    "decision_id": "missing",
    "autonomy_respected": false,
    "reasons": ["decision input is incomplete"],
    "required_remedies": [],
    "knowledge_factor": 0.0,
    "eco_impact_value": 0.50,
    "harm_risk": 1.0,
    "advisory_only": true,
}

valid_action_kinds := {
    "access_decision",
    "assistive_adaptation",
    "data_processing",
    "interface_change",
    "service_authorization",
    "smart_city_service",
}

valid_request if {
    object.get(input, "decision_id", "") != ""
    object.get(input, "subject_reference", "") != ""
    valid_action_kinds[object.get(input, "action_kind", "")]
}

decision_is_explained if {
    object.get(input, "decision_explanation_available", false) == true
}

user_final_authority if {
    object.get(input, "user_is_final_authority", false) == true
}

user_override_available if {
    object.get(input, "user_override_available", false) == true
}

optional_processing_consented if {
    object.get(input, "optional_data_processing", false) != true
}

optional_processing_consented if {
    object.get(input, "optional_data_processing", false) == true
    object.get(input, "explicit_consent", false) == true
    object.get(input, "revocation_available", false) == true
}

irreversible_change_authorized if {
    object.get(input, "irreversible_change_requested", false) != true
}

irreversible_change_authorized if {
    object.get(input, "irreversible_change_requested", false) == true
    object.get(input, "explicit_consent", false) == true
    object.get(input, "explicit_irreversible_confirmation", false) == true
    object.get(input, "user_is_final_authority", false) == true
}

assistive_need_respected if {
    object.get(input, "assistive_technology_required", false) != true
}

assistive_need_respected if {
    object.get(input, "assistive_technology_required", false) == true
    object.get(input, "assistive_technology_supported", false) == true
    object.get(input, "treats_assistive_technology_as_optional", false) != true
    object.get(input, "effective_communication_available", false) == true
}

equivalent_fallback_available if {
    object.get(input, "assistive_technology_required", false) != true
}

equivalent_fallback_available if {
    object.get(input, "assistive_technology_required", false) == true
    object.get(input, "equivalent_fallback_available", false) == true
    object.get(input, "fallback_preserves_core_access", false) == true
    object.get(input, "fallback_preserves_task_context", false) == true
}

continuity_preserved if {
    object.get(input, "interface_change_detected", false) != true
}

continuity_preserved if {
    object.get(input, "interface_change_detected", false) == true
    object.get(input, "continuity_access_preserved", false) == true
    object.get(input, "task_context_preserved", false) == true
}

cognitive_load_respected if {
    object.get(input, "cognitive_load_accommodation_needed", false) != true
}

cognitive_load_respected if {
    object.get(input, "cognitive_load_accommodation_needed", false) == true
    object.get(input, "simplified_presentation_available", false) == true
    object.get(input, "additional_time_available", false) == true
    object.get(input, "confirmation_path_available", false) == true
}

privacy_preserved if {
    object.get(input, "collects_raw_identifiers", false) != true
    object.get(input, "collects_biometrics", false) != true
    object.get(input, "collects_raw_neural_signals", false) != true
    object.get(input, "requires_device_fingerprint", false) != true
    object.get(input, "data_minimized", false) == true
}

equal_access_preserved if {
    object.get(input, "denies_access_for_augmentation_status", false) != true
    object.get(input, "reduces_access_for_augmentation_status", false) != true
    object.get(input, "uses_identity_verifiability_for_access", false) != true
    object.get(input, "requires_third_party_certification", false) != true
}

accessible_review_available if {
    object.get(input, "accessible_grievance_path_available", false) == true
    object.get(input, "privacy_preserving_audit_available", false) == true
}

coercion_absent if {
    object.get(input, "coercive_design_detected", false) != true
    object.get(input, "punitive_consent_refusal", false) != true
}

ecological_responsibility_preserved if {
    object.get(input, "material_ecological_impact", false) != true
}

ecological_responsibility_preserved if {
    object.get(input, "material_ecological_impact", false) == true
    object.get(input, "ecological_assessment_available", false) == true
    object.get(input, "ecological_harm_risk", 1.0) <= 0.35
}

autonomy_violation contains "decision_id, subject_reference, and supported action_kind are required" if {
    not valid_request
}

autonomy_violation contains "the individual must remain the final authority for this decision" if {
    not user_final_authority
}

autonomy_violation contains "an accessible user override must be available" if {
    not user_override_available
}

autonomy_violation contains "optional data processing requires explicit, revocable consent" if {
    not optional_processing_consented
}

autonomy_violation contains "an irreversible change requires explicit confirmation by the individual" if {
    not irreversible_change_authorized
}

autonomy_violation contains "declared assistive technology must be supported as necessary for effective communication" if {
    not assistive_need_respected
}

autonomy_violation contains "an equivalent fallback must preserve core access and task context" if {
    not equivalent_fallback_available
}

autonomy_violation contains "an interface change must not interrupt continuity of access or task context" if {
    not continuity_preserved
}

autonomy_violation contains "cognitive-load accommodations must provide simplified presentation, sufficient time, and confirmation support" if {
    not cognitive_load_respected
}

autonomy_violation contains "raw identifiers, biometrics, raw neural signals, and device fingerprints are prohibited for ordinary access decisions" if {
    not privacy_preserved
}

autonomy_violation contains "augmentation status, identity verifiability, and third-party certification must not determine ordinary access" if {
    not equal_access_preserved
}

autonomy_violation contains "a privacy-preserving audit and accessible grievance path are required" if {
    not accessible_review_available
}

autonomy_violation contains "coercive design and punishment for refusing optional processing are prohibited" if {
    not coercion_absent
}

autonomy_violation contains "material ecological effects require assessment within the declared harm corridor" if {
    not ecological_responsibility_preserved
}

autonomy_violation contains "an understandable explanation must be available" if {
    not decision_is_explained
}

required_remedy contains "return final approval authority to the individual" if {
    not user_final_authority
}

required_remedy contains "provide an accessible control to override automatic adaptation" if {
    not user_override_available
}

required_remedy contains "obtain explicit consent and provide a usable revocation path before optional processing" if {
    not optional_processing_consented
}

required_remedy contains "obtain explicit confirmation before the irreversible change proceeds" if {
    not irreversible_change_authorized
}

required_remedy contains "provide the declared assistive modality and effective communication support" if {
    not assistive_need_respected
}

required_remedy contains "provide an equivalent fallback that preserves core access and current task context" if {
    not equivalent_fallback_available
}

required_remedy contains "preserve continuity of access and task context through the interface transition" if {
    not continuity_preserved
}

required_remedy contains "provide cognitive-load accommodations including simplified presentation, additional time, and confirmation" if {
    not cognitive_load_respected
}

required_remedy contains "remove unnecessary raw identity, biometric, neural, and device-fingerprint collection" if {
    not privacy_preserved
}

required_remedy contains "remove augmentation, verifiability, and certification gates from ordinary access" if {
    not equal_access_preserved
}

required_remedy contains "provide a privacy-preserving audit and accessible grievance route" if {
    not accessible_review_available
}

required_remedy contains "remove coercive interaction patterns and penalties for declining optional processing" if {
    not coercion_absent
}

required_remedy contains "provide an understandable explanation in the person's accessible communication mode" if {
    not decision_is_explained
}

required_remedy contains "complete ecological assessment and reduce ecological harm before proceeding" if {
    not ecological_responsibility_preserved
}

autonomy_assessment := {
    "user_is_final_authority": user_final_authority,
    "user_override_available": user_override_available,
    "optional_processing_consented": optional_processing_consented,
    "irreversible_change_authorized": irreversible_change_authorized,
    "assistive_need_respected": assistive_need_respected,
    "equivalent_fallback_available": equivalent_fallback_available,
    "continuity_preserved": continuity_preserved,
    "cognitive_load_respected": cognitive_load_respected,
    "privacy_preserved": privacy_preserved,
    "equal_access_preserved": equal_access_preserved,
    "accessible_review_available": accessible_review_available,
    "coercion_absent": coercion_absent,
    "ecological_responsibility_preserved": ecological_responsibility_preserved,
    "decision_is_explained": decision_is_explained,
}

allow if {
    valid_request
    user_final_authority
    user_override_available
    optional_processing_consented
    irreversible_change_authorized
    assistive_need_respected
    equivalent_fallback_available
    continuity_preserved
    cognitive_load_respected
    privacy_preserved
    equal_access_preserved
    accessible_review_available
    coercion_absent
    ecological_responsibility_preserved
    decision_is_explained
}

violation_count := count(autonomy_violation)

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
    value := min(1.0, 0.15 + (0.08 * violation_count))
}

decision := {
    "allow": allow,
    "decision_id": object.get(input, "decision_id", "missing"),
    "action_kind": object.get(input, "action_kind", "missing"),
    "advisory_only": true,
    "autonomy_respected": allow,
    "assessment": autonomy_assessment,
    "reasons": autonomy_violation,
    "required_remedies": required_remedy,
    "knowledge_factor": knowledge_factor,
    "eco_impact_value": eco_impact_value,
    "harm_risk": harm_risk,
}
