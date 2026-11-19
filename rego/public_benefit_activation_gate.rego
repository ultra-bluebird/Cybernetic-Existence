package augmented_hub.public_benefit_activation

default decision := {
	"activate": false,
	"status": "activation_blocked",
	"reasons": [
		"Public-benefit activation requires verified authority, source currency, accessible review, and privacy protections."
	],
	"required_actions": [
		"Keep the ledger paused until all authority and rights conditions are verified."
	]
}

decision := {
	"activate": true,
	"status": "activation_authorized_for_review",
	"reasons": [
		"Verified authority records, funding controls, privacy protections, and accessible human-review safeguards are present."
	],
	"required_actions": [
		"Maintain source-currentness monitoring, accessible review, and audit oversight throughout operation."
	]
} if {
	valid_input
	activation_conditions_met
}

decision := {
	"activate": false,
	"status": "activation_blocked",
	"reasons": reasons,
	"required_actions": actions
} if {
	valid_input
	not activation_conditions_met
	reasons := activation_violations
	actions := activation_remedies
}

valid_input if {
	is_boolean(input.authority.verified_appropriation)
	is_boolean(input.authority.verified_program_administrator)
	is_boolean(input.authority.verified_procurement_path)
	is_boolean(input.authority.verified_payment_controls)
	is_boolean(input.authority.verified_audit_requirement)
	is_boolean(input.authority.official_source_current)
	is_boolean(input.authority.authorized_human_review)
	is_boolean(input.ledger.direct_fund_transfer_enabled)
	is_boolean(input.ledger.paused_until_authorized)
	is_boolean(input.privacy.applicant_identity_data_on_chain)
	is_boolean(input.privacy.health_or_disability_data_on_chain)
	is_boolean(input.privacy.neural_or_biometric_data_on_chain)
	is_boolean(input.privacy.assistive_need_details_on_chain)
	is_boolean(input.rights.external_certification_required_for_initial_review)
	is_boolean(input.rights.community_score_used_for_eligibility)
	is_boolean(input.rights.automated_adverse_decision_allowed)
	is_boolean(input.rights.accessible_human_review_available)
	is_boolean(input.rights.appeal_available)
	is_boolean(input.rights.non_retaliation_affirmed)
}

activation_conditions_met if {
	input.authority.verified_appropriation == true
	input.authority.verified_program_administrator == true
	input.authority.verified_procurement_path == true
	input.authority.verified_payment_controls == true
	input.authority.verified_audit_requirement == true
	input.authority.official_source_current == true
	input.authority.authorized_human_review == true
	input.ledger.direct_fund_transfer_enabled == false
	input.ledger.paused_until_authorized == false
	input.privacy.applicant_identity_data_on_chain == false
	input.privacy.health_or_disability_data_on_chain == false
	input.privacy.neural_or_biometric_data_on_chain == false
	input.privacy.assistive_need_details_on_chain == false
	input.rights.external_certification_required_for_initial_review == false
	input.rights.community_score_used_for_eligibility == false
	input.rights.automated_adverse_decision_allowed == false
	input.rights.accessible_human_review_available == true
	input.rights.appeal_available == true
	input.rights.non_retaliation_affirmed == true
}

activation_violations contains "No verified appropriation authority is recorded." if {
	input.authority.verified_appropriation == false
}

activation_violations contains "No verified program administrator is recorded." if {
	input.authority.verified_program_administrator == false
}

activation_violations contains "No verified procurement path is recorded." if {
	input.authority.verified_procurement_path == false
}

activation_violations contains "No verified payment-control path is recorded." if {
	input.authority.verified_payment_controls == false
}

activation_violations contains "No verified audit requirement is recorded." if {
	input.authority.verified_audit_requirement == false
}

activation_violations contains "The legal or administrative source requires reverification or is not current." if {
	input.authority.official_source_current == false
}

activation_violations contains "Authorized human review is unavailable." if {
	input.authority.authorized_human_review == false
}

activation_violations contains "The ledger is configured for prohibited direct fund transfer." if {
	input.ledger.direct_fund_transfer_enabled == true
}

activation_violations contains "The ledger has not completed its authorization-gated activation process." if {
	input.ledger.paused_until_authorized == true
}

activation_violations contains "Applicant identity data is proposed for public or on-chain storage." if {
	input.privacy.applicant_identity_data_on_chain == true
}

activation_violations contains "Health or disability data is proposed for public or on-chain storage." if {
	input.privacy.health_or_disability_data_on_chain == true
}

activation_violations contains "Neural or biometric data is proposed for public or on-chain storage." if {
	input.privacy.neural_or_biometric_data_on_chain == true
}

activation_violations contains "Assistive-need details are proposed for public or on-chain storage." if {
	input.privacy.assistive_need_details_on_chain == true
}

activation_violations contains "Initial program review improperly requires external certification." if {
	input.rights.external_certification_required_for_initial_review == true
}

activation_violations contains "Community scoring is proposed for benefit eligibility." if {
	input.rights.community_score_used_for_eligibility == true
}

activation_violations contains "Automated adverse decisions are permitted." if {
	input.rights.automated_adverse_decision_allowed == true
}

activation_violations contains "Accessible human review is unavailable." if {
	input.rights.accessible_human_review_available == false
}

activation_violations contains "An appeal route is unavailable." if {
	input.rights.appeal_available == false
}

activation_violations contains "Non-retaliation protection is not affirmed." if {
	input.rights.non_retaliation_affirmed == false
}

activation_remedies contains "Record and verify a current official appropriation and authorized program purpose." if {
	input.authority.verified_appropriation == false or input.authority.official_source_current == false
}

activation_remedies contains "Record the authorized program administrator, procurement path, payment controls, and audit requirements." if {
	input.authority.verified_program_administrator == false or input.authority.verified_procurement_path == false or input.authority.verified_payment_controls == false or input.authority.verified_audit_requirement == false
}

activation_remedies contains "Keep the ledger unable to transfer funds directly and retain its paused state until documented authorization is complete." if {
	input.ledger.direct_fund_transfer_enabled == true or input.ledger.paused_until_authorized == true
}

activation_remedies contains "Remove applicant identity, health, disability, neural, biometric, and assistive-need details from public or on-chain storage." if {
	input.privacy.applicant_identity_data_on_chain == true or input.privacy.health_or_disability_data_on_chain == true or input.privacy.neural_or_biometric_data_on_chain == true or input.privacy.assistive_need_details_on_chain == true
}

activation_remedies contains "Remove certification and community-scoring conditions, block automated adverse decisions, and provide accessible human review, appeal, and non-retaliation safeguards." if {
	input.rights.external_certification_required_for_initial_review == true or input.rights.community_score_used_for_eligibility == true or input.rights.automated_adverse_decision_allowed == true or input.rights.accessible_human_review_available == false or input.rights.appeal_available == false or input.rights.non_retaliation_affirmed == false
}
