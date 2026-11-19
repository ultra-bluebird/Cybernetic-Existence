#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DerivedOutputKind {
    LocalRenderTransform,
    LocalAccessibilityCue,
    BodyInference,
    HealthInference,
    IdentityInference,
    LocationInference,
    RelationshipInference,
    CrossSessionMatch,
    SafetyScore,
    TrustScore,
    RiskScore,
    EligibilityScore,
    ProfileVisibilityChange,
    ProfileRecommendationChange,
    AccessDecision,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NonIdentificationError {
    ProhibitedDerivedOutput,
    PersistentRetentionProhibited,
    CloudUploadProhibited,
    AnalyticsExportProhibited,
    ExternalActionAuthorizationProhibited,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ArProcessingContract {
    pub local_only: bool,
    pub session_local_retention_only: bool,
    pub cloud_upload_requested: bool,
    pub analytics_export_requested: bool,
    pub external_action_authorized: bool,
}

impl ArProcessingContract {
    #[must_use]
    pub fn local_session_default() -> Self {
        Self {
            local_only: true,
            session_local_retention_only: true,
            cloud_upload_requested: false,
            analytics_export_requested: false,
            external_action_authorized: false,
        }
    }

    pub fn validate_output(
        &self,
        output: DerivedOutputKind,
    ) -> Result<(), NonIdentificationError> {
        if !self.local_only || !self.session_local_retention_only {
            return Err(NonIdentificationError::PersistentRetentionProhibited);
        }

        if self.cloud_upload_requested {
            return Err(NonIdentificationError::CloudUploadProhibited);
        }

        if self.analytics_export_requested {
            return Err(NonIdentificationError::AnalyticsExportProhibited);
        }

        if self.external_action_authorized {
            return Err(
                NonIdentificationError::ExternalActionAuthorizationProhibited,
            );
        }

        match output {
            DerivedOutputKind::LocalRenderTransform
            | DerivedOutputKind::LocalAccessibilityCue => Ok(()),
            DerivedOutputKind::BodyInference
            | DerivedOutputKind::HealthInference
            | DerivedOutputKind::IdentityInference
            | DerivedOutputKind::LocationInference
            | DerivedOutputKind::RelationshipInference
            | DerivedOutputKind::CrossSessionMatch
            | DerivedOutputKind::SafetyScore
            | DerivedOutputKind::TrustScore
            | DerivedOutputKind::RiskScore
            | DerivedOutputKind::EligibilityScore
            | DerivedOutputKind::ProfileVisibilityChange
            | DerivedOutputKind::ProfileRecommendationChange
            | DerivedOutputKind::AccessDecision => {
                Err(NonIdentificationError::ProhibitedDerivedOutput)
            }
        }
    }
}
