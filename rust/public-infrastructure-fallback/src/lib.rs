#![forbid(unsafe_code)]
#![doc = include_str!("../README.md")]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TriggerState {
    NetworkUnavailable,
    RemoteServiceUnavailable,
    LocalSensorUncertain,
    PowerDegraded,
    LocalStateUnavailable,
    MaintenanceRequired,
    EmergencyActivated,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DegradationState {
    Full,
    Limited,
    Local,
    Manual,
    SafeStop,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FallbackClass {
    InlineExplanation,
    LocalDraft,
    ManualRoute,
    NoOpWithNotice,
    HardwareDefault,
    HumanEscalation,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FallbackCapabilities {
    pub physical_safety_uncertain: bool,
    pub manual_route_available: bool,
    pub local_draft_supported: bool,
    pub safe_local_operation_available: bool,
    pub human_escalation_available: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FallbackDecision {
    pub degradation_state: DegradationState,
    pub fallback_class: FallbackClass,
    pub local_data_preserved: bool,
    pub visual_notice_required: bool,
    pub nonvisual_notice_required: bool,
    pub identity_collection_required: bool,
    pub biometric_collection_required: bool,
    pub health_inference_allowed: bool,
    pub disability_inference_allowed: bool,
    pub behavioral_profiling_allowed: bool,
    pub external_action_authorized: bool,
}

pub fn select_fallback(
    trigger: TriggerState,
    capabilities: FallbackCapabilities,
) -> FallbackDecision {
    let (degradation_state, fallback_class) =
        if capabilities.physical_safety_uncertain {
            (DegradationState::SafeStop, FallbackClass::HardwareDefault)
        } else if capabilities.manual_route_available {
            (DegradationState::Manual, FallbackClass::ManualRoute)
        } else if capabilities.local_draft_supported {
            (DegradationState::Local, FallbackClass::LocalDraft)
        } else if capabilities.safe_local_operation_available {
            (DegradationState::Local, FallbackClass::InlineExplanation)
        } else if capabilities.human_escalation_available {
            (DegradationState::Manual, FallbackClass::HumanEscalation)
        } else {
            (DegradationState::SafeStop, FallbackClass::NoOpWithNotice)
        };

    let local_data_preserved = matches!(
        fallback_class,
        FallbackClass::LocalDraft | FallbackClass::InlineExplanation
    );

    let _ = trigger;

    FallbackDecision {
        degradation_state,
        fallback_class,
        local_data_preserved,
        visual_notice_required: true,
        nonvisual_notice_required: true,
        identity_collection_required: false,
        biometric_collection_required: false,
        health_inference_allowed: false,
        disability_inference_allowed: false,
        behavioral_profiling_allowed: false,
        external_action_authorized: false,
    }
}
