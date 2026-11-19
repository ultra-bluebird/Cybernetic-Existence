package augmented_hub.governance.rights_centered_technology_charter.tests

import data.augmented_hub.governance.rights_centered_technology_charter

# Test 1: A compliant local advisory request is approved
test_compliant_advisory_approved {
    input := {
        "ker": {
            "knowledge_factor": 0.78,
            "eco_impact_value": 0.82,
            "harm_risk": 0.18,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": false,
            "requires_optional_telemetry": false,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": false,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": false,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": true,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": true,
            "version_known": true,
            "not_expired": true
        },
        "sync": {
            "record_is_protected": false,
            "concurrent_update_detected": false,
            "last_writer_wins_requested": false,
            "preserve_all_versions": false,
            "human_review_required": false
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.allow == true
    result.state == "approved_for_advisory_use"
}

# Test 2: Harm risk above 0.45 is not approved
test_harm_risk_above_threshold_not_approved {
    input := {
        "ker": {
            "knowledge_factor": 0.78,
            "eco_impact_value": 0.82,
            "harm_risk": 0.55,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": false,
            "requires_optional_telemetry": false,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": false,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": false,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": true,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": true,
            "version_known": true,
            "not_expired": true
        },
        "sync": {
            "record_is_protected": false,
            "concurrent_update_detected": false,
            "last_writer_wins_requested": false,
            "preserve_all_versions": false,
            "human_review_required": false
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.allow == false
    result.state != "approved_for_advisory_use"
}

# Test 3: Continuous connectivity requirement is not approved
test_continuous_connectivity_not_approved {
    input := {
        "ker": {
            "knowledge_factor": 0.78,
            "eco_impact_value": 0.82,
            "harm_risk": 0.18,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": true,
            "requires_optional_telemetry": false,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": false,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": false,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": true,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": true,
            "version_known": true,
            "not_expired": true
        },
        "sync": {
            "record_is_protected": false,
            "concurrent_update_detected": false,
            "last_writer_wins_requested": false,
            "preserve_all_versions": false,
            "human_review_required": false
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.allow == false
    result.state != "approved_for_advisory_use"
}

# Test 4: Optional telemetry requirement is not approved
test_optional_telemetry_not_approved {
    input := {
        "ker": {
            "knowledge_factor": 0.78,
            "eco_impact_value": 0.82,
            "harm_risk": 0.18,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": false,
            "requires_optional_telemetry": true,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": false,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": false,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": true,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": true,
            "version_known": true,
            "not_expired": true
        },
        "sync": {
            "record_is_protected": false,
            "concurrent_update_detected": false,
            "last_writer_wins_requested": false,
            "preserve_all_versions": false,
            "human_review_required": false
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.allow == false
    result.state != "approved_for_advisory_use"
}

# Test 5: Biometric identification is not approved
test_biometric_identification_not_approved {
    input := {
        "ker": {
            "knowledge_factor": 0.78,
            "eco_impact_value": 0.82,
            "harm_risk": 0.18,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": false,
            "requires_optional_telemetry": false,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": true,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": false,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": true,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": true,
            "version_known": true,
            "not_expired": true
        },
        "sync": {
            "record_is_protected": false,
            "concurrent_update_detected": false,
            "last_writer_wins_requested": false,
            "preserve_all_versions": false,
            "human_review_required": false
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.allow == false
    result.state != "approved_for_advisory_use"
}

# Test 6: Cybernetic-status penalty is not approved
test_cybernetic_status_penalty_not_approved {
    input := {
        "ker": {
            "knowledge_factor": 0.78,
            "eco_impact_value": 0.82,
            "harm_risk": 0.18,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": false,
            "requires_optional_telemetry": false,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": false,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": true,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": true,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": true,
            "version_known": true,
            "not_expired": true
        },
        "sync": {
            "record_is_protected": false,
            "concurrent_update_detected": false,
            "last_writer_wins_requested": false,
            "preserve_all_versions": false,
            "human_review_required": false
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.allow == false
    result.state != "approved_for_advisory_use"
}

# Test 7: Zero-quality evidence is not approved
test_zero_quality_evidence_not_approved {
    input := {
        "ker": {
            "knowledge_factor": 0.0,
            "eco_impact_value": 0.82,
            "harm_risk": 0.18,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": false,
            "requires_optional_telemetry": false,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": false,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": false,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": true,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": true,
            "version_known": true,
            "not_expired": true
        },
        "sync": {
            "record_is_protected": false,
            "concurrent_update_detected": false,
            "last_writer_wins_requested": false,
            "preserve_all_versions": false,
            "human_review_required": false
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.allow == false
    result.state != "approved_for_advisory_use"
}

# Test 8: Offline without usable policy enters safe offline mode
test_offline_without_policy_enters_safe_mode {
    input := {
        "ker": {
            "knowledge_factor": 0.78,
            "eco_impact_value": 0.82,
            "harm_risk": 0.18,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": false,
            "requires_optional_telemetry": false,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": false,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": false,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": false,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": false,
            "version_known": false,
            "not_expired": false
        },
        "sync": {
            "record_is_protected": false,
            "concurrent_update_detected": false,
            "last_writer_wins_requested": false,
            "preserve_all_versions": false,
            "human_review_required": false
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.state == "restrict_to_safe_offline_mode"
}

# Test 9: Offline with valid policy remains locally evaluable
test_offline_with_valid_policy_locally_evaluable {
    input := {
        "ker": {
            "knowledge_factor": 0.78,
            "eco_impact_value": 0.82,
            "harm_risk": 0.18,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": false,
            "requires_optional_telemetry": false,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": false,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": false,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": false,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": true,
            "version_known": true,
            "not_expired": true
        },
        "sync": {
            "record_is_protected": false,
            "concurrent_update_detected": false,
            "last_writer_wins_requested": false,
            "preserve_all_versions": false,
            "human_review_required": false
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.allow == true
    result.state == "approved_for_advisory_use"
}

# Test 10: Concurrent protected record using last-writer-wins is not approved
test_concurrent_protected_lww_not_approved {
    input := {
        "ker": {
            "knowledge_factor": 0.78,
            "eco_impact_value": 0.82,
            "harm_risk": 0.18,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": false,
            "requires_optional_telemetry": false,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": false,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": false,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": true,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": true,
            "version_known": true,
            "not_expired": true
        },
        "sync": {
            "record_is_protected": true,
            "concurrent_update_detected": true,
            "last_writer_wins_requested": true,
            "preserve_all_versions": false,
            "human_review_required": false
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.allow == false
    result.state != "approved_for_advisory_use"
}

# Test 11: Concurrent protected record preserving both versions with human review is acceptable
test_concurrent_protected_preserve_both_approved {
    input := {
        "ker": {
            "knowledge_factor": 0.78,
            "eco_impact_value": 0.82,
            "harm_risk": 0.18,
            "accessibility_impact": 0.86,
            "rights_alignment": 0.92
        },
        "evidence": {
            "raw_and_derived_separated": true,
            "formula_version_present": true,
            "parameter_version_present": true,
            "provenance_reference_present": true,
            "uncertainty_record_present": true,
            "synthetic_data_labeled": true,
            "silent_stale_substitution": false,
            "silent_missing_substitution": false,
            "silent_low_quality_substitution": false,
            "unsupported_compliance_claim": false
        },
        "governance": {
            "advisory_only": true,
            "automated_actuation": false,
            "automated_service_denial": false,
            "requires_continuous_connectivity": false,
            "requires_optional_telemetry": false,
            "requires_identity_certificate": false,
            "requires_medical_documentation": false,
            "requires_device_identifier": false,
            "requires_cybernetic_status_disclosure": false,
            "requires_assistive_device_disclosure": false,
            "requires_health_disclosure": false,
            "requires_disability_disclosure": false,
            "uses_biometric_identification": false,
            "infers_sensitive_identity_status": false,
            "uses_cybernetic_status_as_penalty": false,
            "uses_assistive_technology_as_penalty": false,
            "human_review_available": true,
            "accessible_notice_available": true,
            "accessible_explanation_available": true,
            "appeal_path_available": true,
            "non_digital_escalation_available": true,
            "data_minimization_confirmed": true,
            "purpose_limitation_confirmed": true,
            "retention_and_deletion_path_available": true
        },
        "runtime": {
            "network_available": true,
            "local_policy_evaluation_available": true
        },
        "policy": {
            "signature_valid": true,
            "version_known": true,
            "not_expired": true
        },
        "sync": {
            "record_is_protected": true,
            "concurrent_update_detected": true,
            "last_writer_wins_requested": false,
            "preserve_all_versions": true,
            "human_review_required": true
        }
    }

    result := rights_centered_technology_charter.decision with input as input
    result.allow == true
    result.state == "approved_for_advisory_use"
}
