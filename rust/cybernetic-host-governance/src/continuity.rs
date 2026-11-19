#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PreferenceState {
    NotProvided,
    Active,
    RevokedByUser,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ContinuityProtectionRecord {
    pub preference_state: PreferenceState,
    pub public_visibility_allowed: bool,
    pub revocation_available: bool,
    pub revocation_explanation_required: bool,
    pub access_penalty_for_refusal: bool,
    pub platform_reassignment_allowed: bool,
    pub identity_reclassification_without_user_request_allowed: bool,
    pub communication_reclassification_without_user_request_allowed: bool,
    pub accessibility_impact_assessment_required: bool,
    pub material_change_notice_required: bool,
    pub human_review_path_available: bool,
    pub correction_path_available: bool,
    pub appeal_path_available: bool,
    pub external_agent_identity_validity_assessment_allowed: bool,
    pub external_agent_person_worth_score_allowed: bool,
    pub external_action_authorized: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContinuityProtectionError {
    PublicVisibilityEnabled,
    RevocationUnavailable,
    RevocationExplanationRequired,
    DisclosureRefusalPenalized,
    PlatformReassignmentEnabled,
    ReclassificationWithoutUserRequestEnabled,
    ChangeImpactAssessmentMissing,
    MaterialChangeNoticeMissing,
    HumanReviewUnavailable,
    CorrectionUnavailable,
    AppealUnavailable,
    ExternalIdentityAssessmentEnabled,
    ExternalDevaluationEnabled,
    ExternalActionAuthorized,
}

pub fn validate_continuity_protection(
    record: &ContinuityProtectionRecord,
) -> Result<(), ContinuityProtectionError> {
    if record.public_visibility_allowed {
        return Err(ContinuityProtectionError::PublicVisibilityEnabled);
    }

    if !record.revocation_available {
        return Err(ContinuityProtectionError::RevocationUnavailable);
    }

    if record.revocation_explanation_required {
        return Err(ContinuityProtectionError::RevocationExplanationRequired);
    }

    if record.access_penalty_for_refusal {
        return Err(ContinuityProtectionError::DisclosureRefusalPenalized);
    }

    if record.platform_reassignment_allowed {
        return Err(ContinuityProtectionError::PlatformReassignmentEnabled);
    }

    if record.identity_reclassification_without_user_request_allowed
        || record.communication_reclassification_without_user_request_allowed
    {
        return Err(
            ContinuityProtectionError::ReclassificationWithoutUserRequestEnabled,
        );
    }

    if !record.accessibility_impact_assessment_required {
        return Err(ContinuityProtectionError::ChangeImpactAssessmentMissing);
    }

    if !record.material_change_notice_required {
        return Err(ContinuityProtectionError::MaterialChangeNoticeMissing);
    }

    if !record.human_review_path_available {
        return Err(ContinuityProtectionError::HumanReviewUnavailable);
    }

    if !record.correction_path_available {
        return Err(ContinuityProtectionError::CorrectionUnavailable);
    }

    if !record.appeal_path_available {
        return Err(ContinuityProtectionError::AppealUnavailable);
    }

    if record.external_agent_identity_validity_assessment_allowed {
        return Err(ContinuityProtectionError::ExternalIdentityAssessmentEnabled);
    }

    if record.external_agent_person_worth_score_allowed {
        return Err(ContinuityProtectionError::ExternalDevaluationEnabled);
    }

    if record.external_action_authorized {
        return Err(ContinuityProtectionError::ExternalActionAuthorized);
    }

    Ok(())
}
