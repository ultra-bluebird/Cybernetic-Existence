use crate::{ArSession, ArSessionError, ArSessionState};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StopRequest {
    Pause,
    End,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StopControlError {
    StopControlUnavailable,
    InvalidSessionState,
    ExternalActionAuthorizationProhibited,
    Session(ArSessionError),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct StopControlContract {
    pub always_visible: bool,
    pub always_reachable: bool,
    pub immediate_effect: bool,
    pub confirmation_required: bool,
    pub penalty_allowed: bool,
    pub reversible: bool,
    pub touch_path_available: bool,
    pub keyboard_or_switch_path_available: bool,
    pub voice_path_available: bool,
    pub gesture_path_available: bool,
    pub camera_tracking_required: bool,
    pub eye_tracking_required: bool,
    pub voice_recognition_required: bool,
    pub network_connection_required: bool,
    pub account_authentication_required: bool,
    pub external_action_authorized: bool,
}

impl StopControlContract {
    #[must_use]
    pub fn accessible_default() -> Self {
        Self {
            always_visible: true,
            always_reachable: true,
            immediate_effect: true,
            confirmation_required: false,
            penalty_allowed: false,
            reversible: true,
            touch_path_available: true,
            keyboard_or_switch_path_available: true,
            voice_path_available: false,
            gesture_path_available: false,
            camera_tracking_required: false,
            eye_tracking_required: false,
            voice_recognition_required: false,
            network_connection_required: false,
            account_authentication_required: false,
            external_action_authorized: false,
        }
    }

    pub fn validate(&self) -> Result<(), StopControlError> {
        let invalid = !self.always_visible
            || !self.always_reachable
            || !self.immediate_effect
            || self.confirmation_required
            || self.penalty_allowed
            || !self.reversible
            || !self.touch_path_available
            || !self.keyboard_or_switch_path_available
            || self.camera_tracking_required
            || self.eye_tracking_required
            || self.voice_recognition_required
            || self.network_connection_required
            || self.account_authentication_required;

        if invalid {
            return Err(StopControlError::StopControlUnavailable);
        }

        if self.external_action_authorized {
            return Err(
                StopControlError::ExternalActionAuthorizationProhibited,
            );
        }

        Ok(())
    }
}

pub fn apply_stop_request(
    session: ArSession,
    contract: StopControlContract,
    request: StopRequest,
) -> Result<ArSession, StopControlError> {
    contract.validate()?;

    match request {
        StopRequest::Pause => {
            if session.state != ArSessionState::Active {
                return Err(StopControlError::InvalidSessionState);
            }

            session.pause().map_err(StopControlError::Session)
        }
        StopRequest::End => {
            let session = match session.state {
                ArSessionState::Active => {
                    session.pause().map_err(StopControlError::Session)?
                }
                ArSessionState::Paused => session,
                _ => return Err(StopControlError::InvalidSessionState),
            };

            session.end().map_err(StopControlError::Session)
        }
    }
}
