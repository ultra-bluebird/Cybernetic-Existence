#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SpaceType {
    Public,
    SemiPublic,
    Private,
    Operational,
    Emergency,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RecordingMode {
    None,
    EnvironmentalAggregateOnly,
    EventTriggeredOperational,
    DeclaredSafetyRecording,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InferenceCategory {
    None,
    EquipmentSafetyState,
    EnvironmentalCondition,
    EmergencyActivationState,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SafeFallback {
    VisibleStaticDisclosure,
    ManualRoute,
    AccessibleHumanAssistance,
    EmergencyExit,
    LocalFaultIndicator,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PublicSpaceBoundary {
    pub space_type: SpaceType,
    pub recording_active: bool,
    pub recording_mode: RecordingMode,
    pub audio_recording_active: bool,
    pub inference_active: bool,
    pub inference_categories: Vec<InferenceCategory>,
    pub consent_required: bool,
    pub user_inspectable: bool,
    pub bluetooth_required: bool,
    pub nfc_required: bool,
    pub account_required: bool,
    pub device_presence_tracking_allowed: bool,
    pub face_recognition_allowed: bool,
    pub phone_identifier_collection_allowed: bool,
    pub location_history_allowed: bool,
    pub health_inference_allowed: bool,
    pub disability_inference_allowed: bool,
    pub recovery_inference_allowed: bool,
    pub behavioral_profiling_allowed: bool,
    pub external_action_authorized: bool,
    pub safe_fallback: SafeFallback,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BoundaryValidationError {
    BoundaryMustBeInspectable,
    BluetoothMustNotBeRequired,
    NfcMustNotBeRequired,
    AccountMustNotBeRequired,
    DevicePresenceTrackingProhibited,
    FaceRecognitionProhibited,
    PhoneIdentifierCollectionProhibited,
    LocationHistoryProhibited,
    HealthInferenceProhibited,
    DisabilityInferenceProhibited,
    RecoveryInferenceProhibited,
    BehavioralProfilingProhibited,
    ExternalActionAuthorityProhibited,
    RecordingModeMismatch,
    InferenceModeMismatch,
}

pub fn validate_boundary(
    boundary: &PublicSpaceBoundary,
) -> Result<(), BoundaryValidationError> {
    if !boundary.user_inspectable {
        return Err(BoundaryValidationError::BoundaryMustBeInspectable);
    }

    if boundary.bluetooth_required {
        return Err(BoundaryValidationError::BluetoothMustNotBeRequired);
    }

    if boundary.nfc_required {
        return Err(BoundaryValidationError::NfcMustNotBeRequired);
    }

    if boundary.account_required {
        return Err(BoundaryValidationError::AccountMustNotBeRequired);
    }

    if boundary.device_presence_tracking_allowed {
        return Err(BoundaryValidationError::DevicePresenceTrackingProhibited);
    }

    if boundary.face_recognition_allowed {
        return Err(BoundaryValidationError::FaceRecognitionProhibited);
    }

    if boundary.phone_identifier_collection_allowed {
        return Err(BoundaryValidationError::PhoneIdentifierCollectionProhibited);
    }

    if boundary.location_history_allowed {
        return Err(BoundaryValidationError::LocationHistoryProhibited);
    }

    if boundary.health_inference_allowed {
        return Err(BoundaryValidationError::HealthInferenceProhibited);
    }

    if boundary.disability_inference_allowed {
        return Err(BoundaryValidationError::DisabilityInferenceProhibited);
    }

    if boundary.recovery_inference_allowed {
        return Err(BoundaryValidationError::RecoveryInferenceProhibited);
    }

    if boundary.behavioral_profiling_allowed {
        return Err(BoundaryValidationError::BehavioralProfilingProhibited);
    }

    if boundary.external_action_authorized {
        return Err(BoundaryValidationError::ExternalActionAuthorityProhibited);
    }

    if !boundary.recording_active && boundary.recording_mode != RecordingMode::None {
        return Err(BoundaryValidationError::RecordingModeMismatch);
    }

    if !boundary.inference_active
        && boundary
            .inference_categories
            .iter()
            .any(|category| *category != InferenceCategory::None)
    {
        return Err(BoundaryValidationError::InferenceModeMismatch);
    }

    Ok(())
}
