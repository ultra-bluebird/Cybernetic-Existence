// path: crates/session-intent/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(clippy::all, clippy::pedantic))]

use serde::{Deserialize, Serialize};

/// Session intent tags for COPILOT mode; these are injected into the BCI/XR
/// pipeline as part of the session descriptor.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum SessionIntentTag {
    ActuateExplicit,
    ObserveOnly,
    PlanOnly,
    Diagnostics,
}

impl SessionIntentTag {
    pub const ACTUATE_EXPLICIT_STR: &'static str = "ACTUATE_EXPLICIT";

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "ACTUATE_EXPLICIT" => Some(Self::ActuateExplicit),
            "OBSERVE_ONLY" => Some(Self::ObserveOnly),
            "PLAN_ONLY" => Some(Self::PlanOnly),
            "DIAGNOSTICS" => Some(Self::Diagnostics),
            _ => None,
        }
    }
}

/// BCI/XR session descriptor embedded into the neurostack pipeline
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SessionDescriptor {
    pub session_id: String,
    pub intent: SessionIntentTag,
    pub requires_hosted_approval: bool,
    pub requires_biometric_confirmation: bool,
    pub requires_eeg_signature: bool,
}

/// Host-side confirmation bundle required before RequiresHostedApproval proposals
/// can be actuated.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HostConfirmation {
    pub session_id: String,
    pub biometric_gesture_hash: String,
    pub eeg_signature_hash: String,
    pub timestamp_utc: String,
}

impl HostConfirmation {
    pub fn is_satisfied(&self, session: &SessionDescriptor) -> bool {
        session.requires_hosted_approval
            && session.intent == SessionIntentTag::ActuateExplicit
            && !self.biometric_gesture_hash.is_empty()
            && !self.eeg_signature_hash.is_empty()
    }
}
