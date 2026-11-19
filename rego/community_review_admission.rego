package augmented_hub.community_review_admission

default decision := {
	"allow_review": false,
	"status": "review_blocked",
	"reasons": [
		"Community review requires accessible participation, conflict disclosure, privacy assessment, non-discrimination analysis, and an accessible appeal route."
	],
	"required_actions": [
		"Provide the missing project-level review safeguards before convening a review."
	]
}

decision := {
	"allow_review": true,
	"status": "review_conditions_met",
	"reasons": [
		"The review is accessible, project-focused, privacy-preserving, non-discriminatory, explainable, and subject to appeal."
	],
	"required_actions": []
} if {
	valid_input
	review_conditions_met
}

decision := {
	"allow_review": false,
	"status": "review_blocked",
	"reasons": reasons,
	"required_actions": actions
} if {
	valid_input
	not review_conditions_met
	reasons := review_violations
	actions := review_remedies
}

valid_input if {
	is_boolean(input.review.accessible_notice_available)
	is_boolean(input.review.accessible_participation_available)
	is_boolean(input.review.public_comment_available)
	is_boolean(input.review.alternative_or_human_assisted_route_available)
	is_boolean(input.review.board_membership_declared)
	is_boolean(input.review.conflict_disclosures_complete)
	is_boolean(input.review.non_discrimination_analysis_complete)
	is_boolean(input.review.assistive_access_protected)
	is_boolean(input.review.privacy_impact_assessment_complete)
	is_boolean(input.review.data_minimized)
	is_boolean(input.review.purpose_limited)
	is_boolean(input.review.retention_expiry_declared)
	is_boolean(input.review.human_oversight_present)
	is_boolean(input.review.recommendation_explainable)
	is_boolean(input.review.appeal_path_accessible)
	is_boolean(input.review.non_retaliation_affirmed)
	is_boolean(input.review.individual_ranking_used)
	is_boolean(input.review.essential_service_eligibility_decided)
	is_boolean(input.review.assistive_access_eligibility_decided)
	is_boolean(input.review.identity_certification_required_for_participation)
	is_boolean(input.review.proprietary_technology_required_for_participation)
	is_boolean(input.review.continuous_connectivity_required_for_participation)
	is_boolean(input.review.private_identity_data_collected)
	is_boolean(input.review.neural_biometric_or_health_data_collected)
}

review_conditions_met if {
	input.review.accessible_notice_available == true
	input.review.accessible_participation_available == true
	input.review.public_comment_available == true
	input.review.alternative_or_human_assisted_route_available == true
	input.review.board_membership_declared == true
	input.review.conflict_disclosures_complete == true
	input.review.non_discrimination_analysis_complete == true
	input.review.assistive_access_protected == true
	input.review.privacy_impact_assessment_complete == true
	input.review.data_minimized == true
	input.review.purpose_limited == true
	input.review.retention_expiry_declared == true
	input.review.human_oversight_present == true
	input.review.recommendation_explainable == true
	input.review.appeal_path_accessible == true
	input.review.non_retaliation_affirmed == true
	input.review.individual_ranking_used == false
	input.review.essential_service_eligibility_decided == false
	input.review.assistive_access_eligibility_decided == false
	input.review.identity_certification_required_for_participation == false
	input.review.proprietary_technology_required_for_participation == false
	input.review.continuous_connectivity_required_for_participation == false
	input.review.private_identity_data_collected == false
	input.review.neural_biometric_or_health_data_collected == false
}

review_violations contains "Accessible public notice is unavailable." if {
	input.review.accessible_notice_available == false
}

review_violations contains "An accessible participation route is unavailable." if {
	input.review.accessible_participation_available == false
}

review_violations contains "Public comment is unavailable." if {
	input.review.public_comment_available == false
}

review_violations contains "No alternative or human-assisted participation route is available." if {
	input.review.alternative_or_human_assisted_route_available == false
}

review_violations contains "Board membership is not declared." if {
	input.review.board_membership_declared == false
}

review_violations contains "Conflict disclosures are incomplete." if {
	input.review.conflict_disclosures_complete == false
}

review_violations contains "The non-discrimination analysis is incomplete." if {
	input.review.non_discrimination_analysis_complete == false
}

review_violations contains "Necessary assistive access is not protected." if {
	input.review.assistive_access_protected == false
}

review_violations contains "The privacy impact assessment is incomplete." if {
	input.review.privacy_impact_assessment_complete == false
}

review_violations contains "The review is not data-minimized." if {
	input.review.data_minimized == false
}

review_violations contains "The review lacks a specific purpose limitation." if {
	input.review.purpose_limited == false
}

review_violations contains "The review lacks a retention expiry." if {
	input.review.retention_expiry_declared == false
}

review_violations contains "Human oversight is unavailable." if {
	input.review.human_oversight_present == false
}

review_violations contains "The recommendation is not explainable in accessible form." if {
	input.review.recommendation_explainable == false
}

review_violations contains "An accessible appeal route is unavailable." if {
	input.review.appeal_path_accessible == false
}

review_violations contains "Non-retaliation protection is not affirmed." if {
	input.review.non_retaliation_affirmed == false
}

review_violations contains "The review uses prohibited individual ranking or social scoring." if {
	input.review.individual_ranking_used == true
}

review_violations contains "The review improperly decides essential-service eligibility." if {
	input.review.essential_service_eligibility_decided == true
}

review_violations contains "The review improperly decides necessary assistive-access eligibility." if {
	input.review.assistive_access_eligibility_decided == true
}

review_violations contains "Participation is improperly conditioned on identity certification." if {
	input.review.identity_certification_required_for_participation == true
}

review_violations contains "Participation is improperly conditioned on proprietary technology." if {
	input.review.proprietary_technology_required_for_participation == true
}

review_violations contains "Participation is improperly conditioned on continuous connectivity." if {
	input.review.continuous_connectivity_required_for_participation == true
}

review_violations contains "Private identity data is collected for project-level community review." if {
	input.review.private_identity_data_collected == true
}

review_violations contains "Neural, biometric, or health data is collected for project-level community review." if {
	input.review.neural_biometric_or_health_data_collected == true
}

review_remedies contains "Provide accessible notice, public comment, accessible participation, and a non-digital or human-assisted participation route." if {
	input.review.accessible_notice_available == false or input.review.public_comment_available == false or input.review.accessible_participation_available == false or input.review.alternative_or_human_assisted_route_available == false
}

review_remedies contains "Publish membership roles and complete conflict disclosures before review." if {
	input.review.board_membership_declared == false or input.review.conflict_disclosures_complete == false
}

review_remedies contains "Complete non-discrimination, assistive-access, and privacy-impact assessment before review." if {
	input.review.non_discrimination_analysis_complete == false or input.review.assistive_access_protected == false or input.review.privacy_impact_assessment_complete == false
}

review_remedies contains "Minimize data, limit it to a stated purpose, declare retention expiry, and remove collection of private identity, neural, biometric, and health data." if {
	input.review.data_minimized == false or input.review.purpose_limited == false or input.review.retention_expiry_declared == false or input.review.private_identity_data_collected == true or input.review.neural_biometric_or_health_data_collected == true
}

review_remedies contains "Provide human oversight, an accessible explanation, an accessible appeal route, and non-retaliation protection." if {
	input.review.human_oversight_present == false or input.review.recommendation_explainable == false or input.review.appeal_path_accessible == false or input.review.non_retaliation_affirmed == false
}

review_remedies contains "Remove individual ranking, essential-service eligibility decisions, assistive-access eligibility decisions, certification requirements, proprietary-technology requirements, and continuous-connectivity requirements." if {
	input.review.individual_ranking_used == true or input.review.essential_service_eligibility_decided == true or input.review.assistive_access_eligibility_decided == true or input.review.identity_certification_required_for_participation == true or input.review.proprietary_technology_required_for_participation == true or input.review.continuous_connectivity_required_for_participation == true
}
