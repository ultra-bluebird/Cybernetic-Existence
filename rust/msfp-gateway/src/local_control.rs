#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ConnectionState {
    Offline,
    RequestPending,
    Connected,
    Revoked,
    Expired,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ConnectionRequest {
    pub purpose: String,
    pub audience: String,
    pub requested_generation: u64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum LocalControlError {
    UserInitiationRequired,
    ConsentRequired,
    InvalidTransition,
    FreshAdmissionRequired,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct LocalControlState {
    pub connection_state: ConnectionState,
    pub local_controls_available: bool,
    pub local_preferences_available: bool,
    pub recovery_guidance_available: bool,
    pub active_generation: Option<u64>,
    pub external_authority_active: bool,
}

impl Default for LocalControlState {
    fn default() -> Self {
        Self {
            connection_state: ConnectionState::Offline,
            local_controls_available: true,
            local_preferences_available: true,
            recovery_guidance_available: true,
            active_generation: None,
            external_authority_active: false,
        }
    }
}

impl LocalControlState {
    pub fn request_connection(
        &mut self,
        request: &ConnectionRequest,
        user_initiated: bool,
        consent_active: bool,
    ) -> Result<(), LocalControlError> {
        if !user_initiated {
            return Err(LocalControlError::UserInitiationRequired);
        }

        if !consent_active {
            return Err(LocalControlError::ConsentRequired);
        }

        if self.connection_state != ConnectionState::Offline {
            return Err(LocalControlError::InvalidTransition);
        }

        if request.purpose.is_empty()
            || request.audience.is_empty()
            || request.requested_generation == 0
        {
            return Err(LocalControlError::FreshAdmissionRequired);
        }

        self.connection_state = ConnectionState::RequestPending;
        Ok(())
    }

    pub fn activate_connection(
        &mut self,
        generation: u64,
        admission_passed: bool,
    ) -> Result<(), LocalControlError> {
        if self.connection_state != ConnectionState::RequestPending {
            return Err(LocalControlError::InvalidTransition);
        }

        if !admission_passed || generation == 0 {
            self.connection_state = ConnectionState::Offline;
            return Err(LocalControlError::FreshAdmissionRequired);
        }

        self.connection_state = ConnectionState::Connected;
        self.active_generation = Some(generation);
        self.external_authority_active = true;
        Ok(())
    }

    pub fn end_external_session(
        &mut self,
        expired: bool,
    ) {
        self.connection_state = if expired {
            ConnectionState::Expired
        } else {
            ConnectionState::Revoked
        };

        self.external_authority_active = false;
        self.active_generation = None;
        self.local_controls_available = true;
        self.local_preferences_available = true;
        self.recovery_guidance_available = true;
    }

    pub fn return_offline(
        &mut self,
    ) -> Result<(), LocalControlError> {
        if !matches!(
            self.connection_state,
            ConnectionState::Revoked | ConnectionState::Expired
        ) {
            return Err(LocalControlError::InvalidTransition);
        }

        self.connection_state = ConnectionState::Offline;
        self.external_authority_active = false;
        self.active_generation = None;
        Ok(())
    }

    pub fn local_mode_available(
        &self,
    ) -> bool {
        self.local_controls_available
            && self.local_preferences_available
            && self.recovery_guidance_available
    }
}
