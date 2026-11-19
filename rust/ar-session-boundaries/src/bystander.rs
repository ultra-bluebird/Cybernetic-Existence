#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrivacyGuardCondition {
    Clear,
    PrivacyGuardActive,
    SensorUncertain,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BystanderHandlingAction {
    ContinueLocalProcessing,
    PauseSession,
    ReduceToNonCameraFallback,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BystanderHandlingPolicy {
    pub face_detection_allowed: bool,
    pub face_recognition_allowed: bool,
    pub voice_detection_allowed: bool,
    pub voice_recognition_allowed: bool,
    pub identity_inference_allowed: bool,
    pub demographic_inference_allowed: bool,
    pub health_inference_allowed: bool,
    pub augmentation_inference_allowed: bool,
    pub image_recording_allowed: bool,
    pub audio_recording_allowed: bool,
    pub pose_recording_allowed: bool,
    pub location_recording_allowed: bool,
    pub tracking_identifier_created: bool,
    pub profile_created: bool,
    pub cross_session_correlation_allowed: bool,
    pub privacy_guard_output_retained: bool,
    pub external_action_authorized: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BystanderHandlingError {
    DetectionProhibited,
    RecognitionProhibited,
    InferenceProhibited,
    RecordingProhibited,
    TrackingProhibited,
    ProfileCreationProhibited,
    CrossSessionCorrelationProhibited,
    PrivacyGuardRetentionProhibited,
    ExternalActionAuthorizationProhibited,
}

impl BystanderHandlingPolicy {
    #[must_use]
    pub fn local_only() -> Self {
        Self {
            face_detection_allowed: false,
            face_recognition_allowed: false,
            voice_detection_allowed: false,
            voice_recognition_allowed: false,
            identity_inference_allowed: false,
            demographic_inference_allowed: false,
            health_inference_allowed: false,
            augmentation_inference_allowed: false,
            image_recording_allowed: false,
            audio_recording_allowed: false,
            pose_recording_allowed: false,
            location_recording_allowed: false,
            tracking_identifier_created: false,
            profile_created: false,
            cross_session_correlation_allowed: false,
            privacy_guard_output_retained: false,
            external_action_authorized: false,
        }
    }

    pub fn validate(&self) -> Result<(), BystanderHandlingError> {
        if self.face_detection_allowed || self.voice_detection_allowed {
            return Err(BystanderHandlingError::DetectionProhibited);
        }

        if self.face_recognition_allowed || self.voice_recognition_allowed {
            return Err(BystanderHandlingError::RecognitionProhibited);
        }

        if self.identity_inference_allowed
            || self.demographic_inference_allowed
            || self.health_inference_allowed
            || self.augmentation_inference_allowed
        {
            return Err(BystanderHandlingError::InferenceProhibited);
        }

        if self.image_recording_allowed
            || self.audio_recording_allowed
            || self.pose_recording_allowed
            || self.location_recording_allowed
        {
            return Err(BystanderHandlingError::RecordingProhibited);
        }

        if self.tracking_identifier_created {
            return Err(BystanderHandlingError::TrackingProhibited);
        }

        if self.profile_created {
            return Err(BystanderHandlingError::ProfileCreationProhibited);
        }

        if self.cross_session_correlation_allowed {
            return Err(
                BystanderHandlingError::CrossSessionCorrelationProhibited,
            );
        }

        if self.privacy_guard_output_retained {
            return Err(
                BystanderHandlingError::PrivacyGuardRetentionProhibited,
            );
        }

        if self.external_action_authorized {
            return Err(
                BystanderHandlingError::ExternalActionAuthorizationProhibited,
            );
        }

        Ok(())
    }
}

#[must_use]
pub fn select_bystander_handling_action(
    condition: PrivacyGuardCondition,
) -> BystanderHandlingAction {
    match condition {
        PrivacyGuardCondition::Clear => {
            BystanderHandlingAction::ContinueLocalProcessing
        }
        PrivacyGuardCondition::PrivacyGuardActive => {
            BystanderHandlingAction::PauseSession
        }
        PrivacyGuardCondition::SensorUncertain => {
            BystanderHandlingAction::ReduceToNonCameraFallback
        }
    }
}
