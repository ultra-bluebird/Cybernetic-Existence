#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ClaimStatus {
    Draft,
    EvidenceSubmitted,
    ReviewRequired,
    VerifiedLimited,
    Contested,
    Withdrawn,
    Retired,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AttributionScope {
    Private,
    UserSelectedDisclosure,
    RevokedByUser,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SocialGoodClaim {
    pub claim_ref: String,
    pub status: ClaimStatus,
    pub attribution_scope: AttributionScope,
    pub outcome_definition_present: bool,
    pub intervention_definition_present: bool,
    pub time_period_present: bool,
    pub scope_present: bool,
    pub method_description_present: bool,
    pub baseline_or_counterfactual_present: bool,
    pub uncertainty_statement_present: bool,
    pub provenance_reference_present: bool,
    pub conflict_of_interest_declared: bool,
    pub independent_reviewer_assigned: bool,
    pub challenge_path_available: bool,
    pub correction_path_available: bool,
    pub withdrawal_path_available: bool,
    pub displacement_review_completed: bool,
    pub negative_effects_disclosed: bool,
    pub public_disclosure_requires_user_action: bool,
    pub revocation_available: bool,
    pub revocation_explanation_required: bool,
    pub person_score_created: bool,
    pub person_rank_created: bool,
    pub identity_verification_required: bool,
    pub identity_inference_used: bool,
    pub cross_platform_matching_allowed: bool,
    pub automatic_reward_authorized: bool,
    pub automatic_sanction_authorized: bool,
    pub external_action_authorized: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ClaimValidationError {
    InvalidClaimReference,
    MissingScopeDefinition,
    MissingMethodOrEvidenceContext,
    MissingReviewSafeguard,
    MissingChallengeOrCorrectionPath,
    MissingImpactLimitation,
    PublicDisclosureNotUserControlled,
    RevocationUnavailable,
    RevocationExplanationRequired,
    PersonScoringProhibited,
    IdentityVerificationProhibited,
    IdentityInferenceProhibited,
    CrossPlatformMatchingProhibited,
    AutomatedRewardOrSanctionProhibited,
    ExternalActionAuthorizationProhibited,
}

pub fn validate_claim(claim: &SocialGoodClaim) -> Result<(), ClaimValidationError> {
    if !(16..=128).contains(&claim.claim_ref.len()) {
        return Err(ClaimValidationError::InvalidClaimReference);
    }

    if !claim.outcome_definition_present
        || !claim.intervention_definition_present
        || !claim.time_period_present
        || !claim.scope_present
    {
        return Err(ClaimValidationError::MissingScopeDefinition);
    }

    if !claim.method_description_present
        || !claim.baseline_or_counterfactual_present
        || !claim.uncertainty_statement_present
        || !claim.provenance_reference_present
    {
        return Err(ClaimValidationError::MissingMethodOrEvidenceContext);
    }

    if !claim.conflict_of_interest_declared || !claim.independent_reviewer_assigned {
        return Err(ClaimValidationError::MissingReviewSafeguard);
    }

    if !claim.challenge_path_available
        || !claim.correction_path_available
        || !claim.withdrawal_path_available
    {
        return Err(ClaimValidationError::MissingChallengeOrCorrectionPath);
    }

    if !claim.displacement_review_completed || !claim.negative_effects_disclosed {
        return Err(ClaimValidationError::MissingImpactLimitation);
    }

    if !claim.public_disclosure_requires_user_action {
        return Err(ClaimValidationError::PublicDisclosureNotUserControlled);
    }

    if !claim.revocation_available {
        return Err(ClaimValidationError::RevocationUnavailable);
    }

    if claim.revocation_explanation_required {
        return Err(ClaimValidationError::RevocationExplanationRequired);
    }

    if claim.person_score_created || claim.person_rank_created {
        return Err(ClaimValidationError::PersonScoringProhibited);
    }

    if claim.identity_verification_required {
        return Err(ClaimValidationError::IdentityVerificationProhibited);
    }

    if claim.identity_inference_used {
        return Err(ClaimValidationError::IdentityInferenceProhibited);
    }

    if claim.cross_platform_matching_allowed {
        return Err(ClaimValidationError::CrossPlatformMatchingProhibited);
    }

    if claim.automatic_reward_authorized || claim.automatic_sanction_authorized {
        return Err(ClaimValidationError::AutomatedRewardOrSanctionProhibited);
    }

    if claim.external_action_authorized {
        return Err(ClaimValidationError::ExternalActionAuthorizationProhibited);
    }

    Ok(())
}
