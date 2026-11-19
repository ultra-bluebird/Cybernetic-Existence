#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InfrastructureInboundData {
    PublicServiceStatus,
    PublicAvailability,
    PublicHazardWarning,
    PublicAccessibleRouteNotice,
    PublicServiceDisruption,
    PublicEnvironmentalCondition,
    PersonalData,
    Identity,
    AccountState,
    LocationHistory,
    DeviceIdentifier,
    BehavioralPattern,
    Biometric,
    HealthData,
    InferredState,
    RelationshipGraph,
    EligibilityOutcome,
    ReputationScore,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InfrastructureOutboundData {
    UserRequestedAnonymousFeedback,
    UserRequestedLocalReport,
    Identity,
    Biometric,
    BodyInference,
    HealthInference,
    LocationHistory,
    BehavioralPattern,
    InferredState,
    RelationshipInference,
    ProfileData,
    SafetyScore,
    TrustScore,
    EligibilityScore,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SmartCityBoundaryError {
    InboundDataProhibited,
    OutboundDataProhibited,
    UserInitiationRequired,
    UserReviewRequired,
    PurposeDeclarationRequired,
    DestinationDeclarationRequired,
    RetentionDeclarationRequired,
    CorrectionOrWithdrawalPathRequired,
    InfrastructureControlProhibited,
    ExternalActionAuthorizationProhibited,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OutboundReportDeclaration {
    pub user_initiated: bool,
    pub user_review_before_submission: bool,
    pub purpose_declared: bool,
    pub destination_declared: bool,
    pub retention_declared: bool,
    pub correction_or_withdrawal_path_available: bool,
    pub external_action_authorized: bool,
}

#[must_use]
pub fn inbound_data_allowed(
    data: InfrastructureInboundData,
) -> bool {
    matches!(
        data,
        InfrastructureInboundData::PublicServiceStatus
            | InfrastructureInboundData::PublicAvailability
            | InfrastructureInboundData::PublicHazardWarning
            | InfrastructureInboundData::PublicAccessibleRouteNotice
            | InfrastructureInboundData::PublicServiceDisruption
            | InfrastructureInboundData::PublicEnvironmentalCondition
    )
}

pub fn validate_inbound_data(
    data: InfrastructureInboundData,
) -> Result<(), SmartCityBoundaryError> {
    if inbound_data_allowed(data) {
        Ok(())
    } else {
        Err(SmartCityBoundaryError::InboundDataProhibited)
    }
}

#[must_use]
pub fn outbound_data_allowed(
    data: InfrastructureOutboundData,
) -> bool {
    matches!(
        data,
        InfrastructureOutboundData::UserRequestedAnonymousFeedback
            | InfrastructureOutboundData::UserRequestedLocalReport
    )
}

pub fn validate_outbound_data(
    data: InfrastructureOutboundData,
) -> Result<(), SmartCityBoundaryError> {
    if outbound_data_allowed(data) {
        Ok(())
    } else {
        Err(SmartCityBoundaryError::OutboundDataProhibited)
    }
}

pub fn validate_outbound_report(
    declaration: OutboundReportDeclaration,
) -> Result<(), SmartCityBoundaryError> {
    if !declaration.user_initiated {
        return Err(SmartCityBoundaryError::UserInitiationRequired);
    }

    if !declaration.user_review_before_submission {
        return Err(SmartCityBoundaryError::UserReviewRequired);
    }

    if !declaration.purpose_declared {
        return Err(SmartCityBoundaryError::PurposeDeclarationRequired);
    }

    if !declaration.destination_declared {
        return Err(SmartCityBoundaryError::DestinationDeclarationRequired);
    }

    if !declaration.retention_declared {
        return Err(SmartCityBoundaryError::RetentionDeclarationRequired);
    }

    if !declaration.correction_or_withdrawal_path_available {
        return Err(
            SmartCityBoundaryError::CorrectionOrWithdrawalPathRequired,
        );
    }

    if declaration.external_action_authorized {
        return Err(
            SmartCityBoundaryError::ExternalActionAuthorizationProhibited,
        );
    }

    Ok(())
}
