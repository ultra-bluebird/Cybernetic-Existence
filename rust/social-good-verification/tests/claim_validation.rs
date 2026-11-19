use social_good_verification::{
    validate_claim,
    AttributionScope,
    ClaimStatus,
    ClaimValidationError,
    SocialGoodClaim,
};

fn valid_claim() -> SocialGoodClaim {
    SocialGoodClaim {
        claim_ref: "claim_1234567890abcdef".to_owned(),
        status: ClaimStatus::EvidenceSubmitted,
        attribution_scope: AttributionScope::Private,
        outcome_definition_present: true,
        intervention_definition_present: true,
        time_period_present: true,
        scope_present: true,
        method_description_present: true,
        baseline_or_counterfactual_present: true,
        uncertainty_statement_present: true,
        provenance_reference_present: true,
        conflict_of_interest_declared: true,
        independent_reviewer_assigned: true,
        challenge_path_available: true,
        correction_path_available: true,
        withdrawal_path_available: true,
        displacement_review_completed: true,
        negative_effects_disclosed: true,
        public_disclosure_requires_user_action: true,
        revocation_available: true,
        revocation_explanation_required: false,
        person_score_created: false,
        person_rank_created: false,
        identity_verification_required: false,
        identity_inference_used: false,
        cross_platform_matching_allowed: false,
        automatic_reward_authorized: false,
        automatic_sanction_authorized: false,
        external_action_authorized: false,
    }
}

#[test]
fn accepts_a_complete_claim_level_record() {
    assert_eq!(validate_claim(&valid_claim()), Ok(()));
}

#[test]
fn rejects_person_scoring() {
    let mut claim = valid_claim();
    claim.person_score_created = true;

    assert_eq!(
        validate_claim(&claim),
        Err(ClaimValidationError::PersonScoringProhibited)
    );
}

#[test]
fn rejects_identity_requirements() {
    let mut claim = valid_claim();
    claim.identity_verification_required = true;

    assert_eq!(
        validate_claim(&claim),
        Err(ClaimValidationError::IdentityVerificationProhibited)
    );
}

#[test]
fn rejects_automatic_sanctions() {
    let mut claim = valid_claim();
    claim.automatic_sanction_authorized = true;

    assert_eq!(
        validate_claim(&claim),
        Err(ClaimValidationError::AutomatedRewardOrSanctionProhibited)
    );
}
