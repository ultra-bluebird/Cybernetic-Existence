package augmented_hub.rights_core

default decision := {
	"allow": false,
	"status": "insufficient_evidence",
	"reasons": [
		"Complete evidence is required for identity handling, consent, privacy, accessibility, review, and non-discrimination safeguards."
	],
	"required_actions": [
		"Provide only the minimum decision evidence necessary for an accessible human review."
	],
	"protections": {
		"self_asserted_identity_respected": false,
		"assistive_access_protected": false,
		"augmentation_autonomy_protected": false,
		"psych_continuity_respected": false,
		"data_minimized": false,
		"retention_bounded": false,
		"human_review_available": false,
		"appeal_available": false,
		"non_discrimination_protected": false
	}
}

decision := {
	"allow": true,
	"status": "rights_conditions_met",
	"reasons": [
		"The proposed action preserves self-assertion, accessibility, autonomy, privacy, consent, retention limits, human review, appeal, and equal treatment."
	],
	"required_actions": [],
	"protections": protections
} if {
	valid_input
	rights_conditions_met
	protections := protection_summary
}

decision := {
	"allow": false,
	"status": "rights_conditions_not_met",
	"reasons": reasons,
	"required_actions": actions,
	"protections": protections
} if {
	valid_input
	not rights_conditions_met
	reasons := violations
	actions := remediation_actions
	protections := protection_summary
}

valid_input if {
	is_boolean(input.identity.self_asserted_claim_respected)
	is_boolean(input.identity.external_verification_required_for_dignity)
	is_boolean(input.identity.private_narrative_disclosure_required)
	is_boolean(input.continuity.self_assertion_respected)
	is_boolean(input.continuity.raw_neural_or_biometric_data_required)
	is_boolean(input.assistive.access_protected)
	is_boolean(input.assistive.accessible_operation_available)
	is_boolean(input.assistive.repair_or_equivalent_available)
	is_boolean(input.assistive.offline_or_intermittent_access_available)
	is_boolean(input.augmentation.autonomy_preserved)
	is_boolean(input.augmentation.material_change_has_explicit_consent)
	is_boolean(input.augmentation.material_change_has_human_review)
	is_boolean(input.privacy.data_minimized)
	is_boolean(input.privacy.purpose_limited)
	is_boolean(input.privacy.retention_expiry_declared)
	is_boolean(input.privacy.revocable_consent_available)
	is_boolean(input.privacy.unrelated_telemetry_required)
	is_boolean(input.privacy.continuous_connectivity_required)
	is_boolean(input.fairness.discriminatory)
	is_boolean(input.fairness.exclusionary_barrier)
	is_boolean(input.review.accessible_explanation_available)
	is_boolean(input.review.human_review_available)
	is_boolean(input.review.appeal_available)
	is_boolean(input.review.non_retaliation_affirmed)
}

rights_conditions_met if {
	input.identity.self_asserted_claim_respected == true
	input.identity.external_verification_required_for_dignity == false
	input.identity.private_narrative_disclosure_required == false
	input.continuity.self_assertion_respected == true
	input.continuity.raw_neural_or_biometric_data_required == false
	input.assistive.access_protected == true
	input.assistive.accessible_operation_available == true
	input.assistive.repair_or_equivalent_available == true
	input.assistive.offline_or_intermittent_access_available == true
	input.augmentation.autonomy_preserved == true
	input.augmentation.material_change_has_explicit_consent == true
	input.augmentation.material_change_has_human_review == true
	input.privacy.data_minimized == true
	input.privacy.purpose_limited == true
	input.privacy.retention_expiry_declared == true
	input.privacy.revocable_consent_available == true
	input.privacy.unrelated_telemetry_required == false
	input.privacy.continuous_connectivity_required == false
	input.fairness.discriminatory == false
	input.fairness.exclusionary_barrier == false
	input.review.accessible_explanation_available == true
	input.review.human_review_available == true
	input.review.appeal_available == true
	input.review.non_retaliation_affirmed == true
}

protection_summary := {
	"self_asserted_identity_respected": input.identity.self_asserted_claim_respected == true and input.identity.external_verification_required_for_dignity == false and input.identity.private_narrative_disclosure_required == false,
	"assistive_access_protected": input.assistive.access_protected == true and input.assistive.accessible_operation_available == true and input.assistive.repair_or_equivalent_available == true and input.assistive.offline_or_intermittent_access_available == true,
	"augmentation_autonomy_protected": input.augmentation.autonomy_preserved == true and input.augmentation.material_change_has_explicit_consent == true and input.augmentation.material_change_has_human_review == true,
	"psych_continuity_respected": input.continuity.self_assertion_respected == true and input.continuity.raw_neural_or_biometric_data_required == false,
	"data_minimized": input.privacy.data_minimized == true and input.privacy.purpose_limited == true and input.privacy.unrelated_telemetry_required == false,
	"retention_bounded": input.privacy.retention_expiry_declared == true and input.privacy.revocable_consent_available == true,
	"human_review_available": input.review.accessible_explanation_available == true and input.review.human_review_available == true,
	"appeal_available": input.review.appeal_available == true and input.review.non_retaliation_affirmed == true,
	"non_discrimination_protected": input.fairness.discriminatory == false and input.fairness.exclusionary_barrier == false
}

violations contains "Self-asserted private identity is not respected." if {
	input.identity.self_asserted_claim_respected == false
}

violations contains "Basic dignity or baseline treatment is improperly conditioned on external verification." if {
	input.identity.external_verification_required_for_dignity == true
}

violations contains "The workflow improperly requires private narrative disclosure." if {
	input.identity.private_narrative_disclosure_required == true
}

violations contains "Self-asserted psychological continuity is not respected." if {
	input.continuity.self_assertion_respected == false
}

violations contains "The workflow improperly requires neural or biometric data." if {
	input.continuity.raw_neural_or_biometric_data_required == true
}

violations contains "Necessary assistive access is not protected." if {
	input.assistive.access_protected == false
}

violations contains "The assistive access route is not accessible." if {
	input.assistive.accessible_operation_available == false
}

violations contains "Assistive repair or an accessible equivalent is unavailable." if {
	input.assistive.repair_or_equivalent_available == false
}

violations contains "Assistive access lacks an offline or intermittent-connectivity route." if {
	input.assistive.offline_or_intermittent_access_available == false
}

violations contains "Augmentation autonomy is not preserved." if {
	input.augmentation.autonomy_preserved == false
}

violations contains "A material augmentation-related change lacks explicit consent." if {
	input.augmentation.material_change_has_explicit_consent == false
}

violations contains "A material augmentation-related change lacks human review." if {
	input.augmentation.material_change_has_human_review == false
}

violations contains "Data processing is not minimized." if {
	input.privacy.data_minimized == false
}

violations contains "The action lacks a defined purpose limitation." if {
	input.privacy.purpose_limited == false
}

violations contains "The action lacks a retention-expiry declaration." if {
	input.privacy.retention_expiry_declared == false
}

violations contains "Revocable consent is unavailable." if {
	input.privacy.revocable_consent_available == false
}

violations contains "The action improperly requires unrelated telemetry." if {
	input.privacy.unrelated_telemetry_required == true
}

violations contains "The action improperly requires continuous connectivity." if {
	input.privacy.continuous_connectivity_required == true
}

violations contains "The action includes discriminatory treatment." if {
	input.fairness.discriminatory == true
}

violations contains "The action creates an exclusionary barrier." if {
	input.fairness.exclusionary_barrier == true
}

violations contains "No accessible explanation is available." if {
	input.review.accessible_explanation_available == false
}

violations contains "No human-review pathway is available." if {
	input.review.human_review_available == false
}

violations contains "No appeal pathway is available." if {
	input.review.appeal_available == false
}

violations contains "Non-retaliation protection is not affirmed." if {
	input.review.non_retaliation_affirmed == false
}

remediation_actions contains "Accept the self-asserted identity claim for baseline dignified treatment without external verification." if {
	input.identity.self_asserted_claim_respected == false or input.identity.external_verification_required_for_dignity == true
}

remediation_actions contains "Remove mandatory private-narrative, neural-data, and biometric-data disclosure." if {
	input.identity.private_narrative_disclosure_required == true or input.continuity.raw_neural_or_biometric_data_required == true
}

remediation_actions contains "Respect self-asserted psychological continuity and preserve a person-controlled revision path." if {
	input.continuity.self_assertion_respected == false
}

remediation_actions contains "Provide necessary assistive technology or an accessible equivalent with repair and offline-capable operation." if {
	input.assistive.access_protected == false or input.assistive.accessible_operation_available == false or input.assistive.repair_or_equivalent_available == false or input.assistive.offline_or_intermittent_access_available == false
}

remediation_actions contains "Restore augmentation autonomy and obtain explicit consent plus human review before material change." if {
	input.augmentation.autonomy_preserved == false or input.augmentation.material_change_has_explicit_consent == false or input.augmentation.material_change_has_human_review == false
}

remediation_actions contains "Minimize data, state a specific purpose, declare retention expiry, provide revocation, and remove telemetry or connectivity conditions." if {
	input.privacy.data_minimized == false or input.privacy.purpose_limited == false or input.privacy.retention_expiry_declared == false or input.privacy.revocable_consent_available == false or input.privacy.unrelated_telemetry_required == true or input.privacy.continuous_connectivity_required == true
}

remediation_actions contains "Remove discriminatory and exclusionary conditions." if {
	input.fairness.discriminatory == true or input.fairness.exclusionary_barrier == true
}

remediation_actions contains "Provide an accessible explanation, human review, appeal route, and non-retaliation protection." if {
	input.review.accessible_explanation_available == false or input.review.human_review_available == false or input.review.appeal_available == false or input.review.non_retaliation_affirmed == false
}
