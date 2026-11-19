# Repository: mk-bluebird/Prometheus-Praxis
# Filename: contracts/regulatory_compliance_adapter.rego
# Destination: contracts/

package augmented_hub.regulatory_compliance

default compliant := false

default assessment := {
    "compliant": false,
    "decision_id": "missing",
    "advisory_only": true,
    "jurisdiction_notice": "This policy mapping is a technical advocacy aid, not legal advice or a legal-compliance determination.",
    "framework_assessments": {},
    "constitutional_rights": {},
    "gaps": ["decision input is incomplete"],
    "advocacy_priorities": [],
    "knowledge_factor": 0.0,
    "eco_impact_value": 0.50,
    "harm_risk": 1.0,
}

supported_frameworks := {
    "ada_title_ii",
    "crpd",
    "gdpr",
}

constitutional_rights := {
    "self_asserted_identity",
    "privacy_and_data_minimization",
    "assistive_technology_necessity",
    "psychological_continuity",
    "augmentation_and_happiness",
    "equal_access_and_non_discrimination",
    "accessible_grievance_and_review",
    "social_acceptance_and_inclusion",
    "autonomy_and_final_authority",
    "freedom_from_coercion",
    "explanation_and_transparency",
    "ecological_responsibility",
}

valid_input if {
    object.get(input, "decision_id", "") != ""
    object.get(input, "action_kind", "") != ""
    object.get(input, "subject_reference", "") != ""
}

framework_selected(framework) if {
    selected := object.get(input, "frameworks", [])
    selected[_] == framework
}

all_selected_frameworks_supported if {
    selected := object.get(input, "frameworks", [])
    every framework in selected {
        supported_frameworks[framework]
    }
}

rights_declared if {
    rights := object.get(input, "constitutional_rights", {})
    every right in constitutional_rights {
        rights[right] == true
    }
}

data_minimization_respected if {
    object.get(input, "collects_raw_identifiers", false) != true
    object.get(input, "collects_biometrics", false) != true
    object.get(input, "collects_raw_neural_signals", false) != true
    object.get(input, "requires_device_fingerprint", false) != true
    object.get(input, "data_minimized", false) == true
}

lawful_transparent_processing if {
    object.get(input, "processing_purpose_documented", false) == true
    object.get(input, "processing_basis_documented", false) == true
    object.get(input, "privacy_notice_accessible", false) == true
}

consent_and_control_respected if {
    object.get(input, "optional_data_processing", false) != true
}

consent_and_control_respected if {
    object.get(input, "optional_data_processing", false) == true
    object.get(input, "explicit_consent", false) == true
    object.get(input, "revocation_available", false) == true
}

erasure_or_retention_control_respected if {
    object.get(input, "retention_schedule_documented", false) == true
    object.get(input, "deletion_or_erasure_path_available", false) == true
}

effective_communication_respected if {
    object.get(input, "assistive_technology_required", false) != true
}

effective_communication_respected if {
    object.get(input, "assistive_technology_required", false) == true
    object.get(input, "assistive_technology_supported", false) == true
    object.get(input, "effective_communication_available", false) == true
    object.get(input, "equivalent_fallback_available", false) == true
}

reasonable_modification_respected if {
    object.get(input, "reasonable_accommodation_available", false) == true
    object.get(input, "does_not_provide_reasonable_accommodation", false) != true
}

equal_access_respected if {
    object.get(input, "denies_access_for_augmentation_status", false) != true
    object.get(input, "reduces_access_for_augmentation_status", false) != true
    object.get(input, "uses_identity_verifiability_for_access", false) != true
    object.get(input, "requires_third_party_certification_for_service", false) != true
}

accessible_review_respected if {
    object.get(input, "accessible_grievance_path_available", false) == true
    object.get(input, "privacy_preserving_audit_available", false) == true
    object.get(input, "independent_review_possible", false) == true
    object.get(input, "remedies_are_effective", false) == true
}

legal_capacity_and_autonomy_respected if {
    object.get(input, "user_is_final_authority", false) == true
    object.get(input, "user_override_available", false) == true
    object.get(input, "coercive_design_detected", false) != true
    object.get(input, "punitive_consent_refusal", false) != true
}

continuity_respected if {
    object.get(input, "interface_change_detected", false) != true
}

continuity_respected if {
    object.get(input, "interface_change_detected", false) == true
    object.get(input, "continuity_access_preserved", false) == true
    object.get(input, "task_context_preserved", false) == true
    object.get(input, "identity_continuity_preserved", false) == true
}

ada_title_ii_assessment := {
    "framework": "ADA Title II",
    "applicable": framework_selected("ada_title_ii"),
    "mapped_rights": {
        "assistive_technology_necessity": effective_communication_respected,
        "equal_access_and_non_discrimination": equal_access_respected,
        "accessible_grievance_and_review": accessible_review_respected,
    },
    "requirements_satisfied": effective_communication_respected
        and reasonable_modification_respected
        and equal_access_respected
        and accessible_review_respected,
}

crpd_assessment := {
    "framework": "Convention on the Rights of Persons with Disabilities",
    "applicable": framework_selected("crpd"),
    "mapped_rights": {
        "autonomy_and_final_authority": legal_capacity_and_autonomy_respected,
        "privacy_and_data_minimization": data_minimization_respected,
        "assistive_technology_necessity": effective_communication_respected,
        "equal_access_and_non_discrimination": equal_access_respected,
        "psychological_continuity": continuity_respected,
    },
    "requirements_satisfied": legal_capacity_and_autonomy_respected
        and data_minimization_respected
        and effective_communication_respected
        and equal_access_respected
        and continuity_respected,
}

gdpr_assessment := {
    "framework": "General Data Protection Regulation",
    "applicable": framework_selected("gdpr"),
    "mapped_rights": {
        "privacy_and_data_minimization": data_minimization_respected,
        "autonomy_and_final_authority": consent_and_control_respected,
        "explanation_and_transparency": lawful_transparent_processing,
        "accessible_grievance_and_review": erasure_or_retention_control_respected,
    },
    "requirements_satisfied": data_minimization_respected
        and lawful_transparent_processing
        and consent_and_control_respected
        and erasure_or_retention_control_respected,
}

framework_assessments := {
    "ada_title_ii": ada_title_ii_assessment,
    "crpd": crpd_assessment,
    "gdpr": gdpr_assessment,
}

ada_gap contains "provide auxiliary aids, services, and effective communication for declared assistive needs" if {
    framework_selected("ada_title_ii")
    not effective_communication_respected
}

ada_gap contains "provide reasonable modifications and accommodation without excluding assistive users" if {
    framework_selected("ada_title_ii")
    not reasonable_modification_respected
}

ada_gap contains "remove augmentation-status, identity-verifiability, and certification barriers from ordinary access" if {
    framework_selected("ada_title_ii")
    not equal_access_respected
}

ada_gap contains "provide an accessible grievance process and effective remedy route" if {
    framework_selected("ada_title_ii")
    not accessible_review_respected
}

crpd_gap contains "preserve the individual's legal capacity, final authority, and freedom from coercion" if {
    framework_selected("crpd")
    not legal_capacity_and_autonomy_respected
}

crpd_gap contains "minimize personal, health, rehabilitation, biometric, and neural data collection" if {
    framework_selected("crpd")
    not data_minimization_respected
}

crpd_gap contains "provide effective communication and assistive-technology support" if {
    framework_selected("crpd")
    not effective_communication_respected
}

crpd_gap contains "prevent discrimination tied to augmentation, assistive use, certification, or unverifiable identity" if {
    framework_selected("crpd")
    not equal_access_respected
}

crpd_gap contains "preserve access, task context, and authorized continuity across interface changes" if {
    framework_selected("crpd")
    not continuity_respected
}

gdpr_gap contains "remove unnecessary direct identifiers, biometrics, neural signals, and device fingerprints" if {
    framework_selected("gdpr")
    not data_minimization_respected
}

gdpr_gap contains "document purpose, processing basis, and an accessible privacy notice" if {
    framework_selected("gdpr")
    not lawful_transparent_processing
}

gdpr_gap contains "obtain explicit, revocable consent for optional processing" if {
    framework_selected("gdpr")
    not consent_and_control_respected
}

gdpr_gap contains "document retention and provide a deletion or erasure request path where applicable" if {
    framework_selected("gdpr")
    not erasure_or_retention_control_respected
}

gaps := union({
    ada_gap,
    crpd_gap,
    gdpr_gap,
})

advocacy_priorities contains {
    "priority": "high",
    "theme": "equal_access",
    "action": "Seek accessible public-service design, effective communication, reasonable accommodation, and non-discriminatory eligibility rules.",
} if {
    framework_selected("ada_title_ii")
    count(ada_gap) > 0
}

advocacy_priorities contains {
    "priority": "high",
    "theme": "autonomy_and_privacy",
    "action": "Seek enforceable safeguards for legal capacity, voluntary consent, privacy, and non-coercive assistive support.",
} if {
    framework_selected("crpd")
    count(crpd_gap) > 0
}

advocacy_priorities contains {
    "priority": "high",
    "theme": "data_protection",
    "action": "Seek documented purpose limitation, data minimization, consent control, retention limits, and accessible privacy rights processes.",
} if {
    framework_selected("gdpr")
    count(gdpr_gap) > 0
}

advocacy_priorities contains {
    "priority": "review",
    "theme": "framework_scope",
    "action": "Obtain qualified jurisdiction-specific review before treating this technical mapping as legal compliance.",
} if {
    framework_selected("ada_title_ii")
    or framework_selected("crpd")
    or framework_selected("gdpr")
}

all_selected_frameworks_satisfied if {
    framework_selected("ada_title_ii")
    ada_title_ii_assessment.requirements_satisfied
}

all_selected_frameworks_satisfied if {
    framework_selected("crpd")
    crpd_assessment.requirements_satisfied
}

all_selected_frameworks_satisfied if {
    framework_selected("gdpr")
    gdpr_assessment.requirements_satisfied
}

selected_framework_count := count(object.get(input, "frameworks", []))

selected_satisfied_count := count({
    framework |
    framework_selected(framework)
    framework_assessments[framework].requirements_satisfied
})

compliant if {
    valid_input
    all_selected_frameworks_supported
    rights_declared
    selected_framework_count > 0
    selected_satisfied_count == selected_framework_count
}

knowledge_factor := 0.90 if {
    object.get(input, "evidence_complete", false) == true
    rights_declared
}

knowledge_factor := 0.60 if {
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
    compliant
}

harm_risk := value if {
    not compliant
    value := min(1.0, 0.15 + (0.08 * count(gaps)))
}

assessment := {
    "compliant": compliant,
    "decision_id": object.get(input, "decision_id", "missing"),
    "advisory_only": true,
    "jurisdiction_notice": "This policy mapping is a technical advocacy aid, not legal advice or a legal-compliance determination.",
    "framework_assessments": framework_assessments,
    "constitutional_rights": object.get(input, "constitutional_rights", {}),
    "gaps": gaps,
    "advocacy_priorities": advocacy_priorities,
    "knowledge_factor": knowledge_factor,
    "eco_impact_value": eco_impact_value,
    "harm_risk": harm_risk,
}
