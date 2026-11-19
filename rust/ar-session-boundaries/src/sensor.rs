use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SensorType {
    Camera,
    Microphone,
    Motion,
    Orientation,
    Depth,
    SpatialTracking,
    PlaneEstimation,
    Location,
    HandTracking,
    EyeTracking,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SensorDuration {
    CurrentFrame,
    ActiveSessionOnly,
    UserRequestedCaptureOnly,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SensorRetention {
    NotRetained,
    MemoryOnlyCurrentSession,
    UserRequestedLocalExport,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SensorAuditEvent {
    Requested,
    Started,
    Stopped,
    Purged,
    LocalExportRequested,
    TransferConsentRequested,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SensorDeclaration {
    pub declaration_ref: String,
    pub session_ref: String,
    pub sensor_type: SensorType,
    pub purpose: String,
    pub duration: SensorDuration,
    pub retention: SensorRetention,
    pub user_visible: bool,
    pub active_indicator: bool,
    pub stop_control_available: bool,
    pub stop_control_immediate: bool,
    pub background_activation_allowed: bool,
    pub secondary_use_allowed: bool,
    pub external_transfer_allowed: bool,
    pub identity_inference_allowed: bool,
    pub face_recognition_allowed: bool,
    pub voice_recognition_allowed: bool,
    pub bystander_profile_creation_allowed: bool,
    pub external_action_authorized: bool,
    pub audit_event: SensorAuditEvent,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SensorDeclarationError {
    InvalidDeclarationReference,
    InvalidSessionReference,
    MissingPurpose,
    UserVisibilityRequired,
    ActiveIndicatorRequired,
    StopControlRequired,
    ImmediateStopRequired,
    BackgroundActivationProhibited,
    SecondaryUseProhibited,
    ExternalTransferProhibited,
    IdentityInferenceProhibited,
    BiometricRecognitionProhibited,
    BystanderProfileCreationProhibited,
    ExternalActionAuthorizationProhibited,
}

pub fn validate_sensor_declaration(
    declaration: &SensorDeclaration,
) -> Result<(), SensorDeclarationError> {
    if !(16..=128).contains(&declaration.declaration_ref.len()) {
        return Err(SensorDeclarationError::InvalidDeclarationReference);
    }

    if !(16..=128).contains(&declaration.session_ref.len()) {
        return Err(SensorDeclarationError::InvalidSessionReference);
    }

    if declaration.purpose.trim().is_empty() {
        return Err(SensorDeclarationError::MissingPurpose);
    }

    if !declaration.user_visible {
        return Err(SensorDeclarationError::UserVisibilityRequired);
    }

    if !declaration.active_indicator {
        return Err(SensorDeclarationError::ActiveIndicatorRequired);
    }

    if !declaration.stop_control_available {
        return Err(SensorDeclarationError::StopControlRequired);
    }

    if !declaration.stop_control_immediate {
        return Err(SensorDeclarationError::ImmediateStopRequired);
    }

    if declaration.background_activation_allowed {
        return Err(SensorDeclarationError::BackgroundActivationProhibited);
    }

    if declaration.secondary_use_allowed {
        return Err(SensorDeclarationError::SecondaryUseProhibited);
    }

    if declaration.external_transfer_allowed {
        return Err(SensorDeclarationError::ExternalTransferProhibited);
    }

    if declaration.identity_inference_allowed {
        return Err(SensorDeclarationError::IdentityInferenceProhibited);
    }

    if declaration.face_recognition_allowed || declaration.voice_recognition_allowed {
        return Err(SensorDeclarationError::BiometricRecognitionProhibited);
    }

    if declaration.bystander_profile_creation_allowed {
        return Err(SensorDeclarationError::BystanderProfileCreationProhibited);
    }

    if declaration.external_action_authorized {
        return Err(SensorDeclarationError::ExternalActionAuthorizationProhibited);
    }

    Ok(())
}
