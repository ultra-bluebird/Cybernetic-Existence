#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeclarationState {
    NotProvided,
    UserProvided,
    UserRevoked,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AcknowledgmentState {
    NoAcknowledgmentNeeded,
    Acknowledged,
    RevokedByUser,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct IdentityAcknowledgment {
    pub declaration_state: DeclarationState,
    pub acknowledgment_state: AcknowledgmentState,
    pub preferred_address_provided: bool,
    pub communication_preference_provided: bool,
    pub access_preference_provided: bool,
    pub privacy_boundary_provided: bool,
    pub continuity_preference_provided: bool,
    pub public_visibility_allowed: bool,
    pub identity_verification_required: bool,
    pub identity_certification_required: bool,
    pub medical_information_required: bool,
    pub biometric_information_required: bool,
    pub neural_information_required: bool,
    pub institutional_affiliation_required: bool,
    pub behavioral_inference_allowed: bool,
    pub matching_use_allowed: bool,
    pub ranking_use_allowed: bool,
    pub eligibility_use_allowed: bool,
    pub fraud_scoring_use_allowed: bool,
    pub advertising_use_allowed: bool,
    pub external_action_authorized: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AcknowledgmentError {
    ProhibitedPublicVisibility,
    ProhibitedVerificationRequirement,
    ProhibitedCertificationRequirement,
    ProhibitedSensitiveInformationRequirement,
    ProhibitedBehavioralInference,
    ProhibitedDownstreamUse,
    ProhibitedExternalAuthority,
}

pub fn acknowledge_declaration(
    declaration_state: DeclarationState,
    preferred_address_provided: bool,
    communication_preference_provided: bool,
    access_preference_provided: bool,
    privacy_boundary_provided: bool,
    continuity_preference_provided: bool,
) -> IdentityAcknowledgment {
    let acknowledgment_state = match declaration_state {
        DeclarationState::NotProvided => AcknowledgmentState::NoAcknowledgmentNeeded,
        DeclarationState::UserProvided => AcknowledgmentState::Acknowledged,
        DeclarationState::UserRevoked => AcknowledgmentState::RevokedByUser,
    };

    IdentityAcknowledgment {
        declaration_state,
        acknowledgment_state,
        preferred_address_provided,
        communication_preference_provided,
        access_preference_provided,
        privacy_boundary_provided,
        continuity_preference_provided,
        public_visibility_allowed: false,
        identity_verification_required: false,
        identity_certification_required: false,
        medical_information_required: false,
        biometric_information_required: false,
        neural_information_required: false,
        institutional_affiliation_required: false,
        behavioral_inference_allowed: false,
        matching_use_allowed: false,
        ranking_use_allowed: false,
        eligibility_use_allowed: false,
        fraud_scoring_use_allowed: false,
        advertising_use_allowed: false,
        external_action_authorized: false,
    }
}

pub fn validate_acknowledgment(
    acknowledgment: &IdentityAcknowledgment,
) -> Result<(), AcknowledgmentError> {
    if acknowledgment.public_visibility_allowed {
        return Err(AcknowledgmentError::ProhibitedPublicVisibility);
    }

    if acknowledgment.identity_verification_required {
        return Err(AcknowledgmentError::ProhibitedVerificationRequirement);
    }

    if acknowledgment.identity_certification_required {
        return Err(AcknowledgmentError::ProhibitedCertificationRequirement);
    }

    if acknowledgment.medical_information_required
        || acknowledgment.biometric_information_required
        || acknowledgment.neural_information_required
        || acknowledgment.institutional_affiliation_required
    {
        return Err(AcknowledgmentError::ProhibitedSensitiveInformationRequirement);
    }

    if acknowledgment.behavioral_inference_allowed {
        return Err(AcknowledgmentError::ProhibitedBehavioralInference);
    }

    if acknowledgment.matching_use_allowed
        || acknowledgment.ranking_use_allowed
        || acknowledgment.eligibility_use_allowed
        || acknowledgment.fraud_scoring_use_allowed
        || acknowledgment.advertising_use_allowed
    {
        return Err(AcknowledgmentError::ProhibitedDownstreamUse);
    }

    if acknowledgment.external_action_authorized {
        return Err(AcknowledgmentError::ProhibitedExternalAuthority);
    }

    Ok(())
}
