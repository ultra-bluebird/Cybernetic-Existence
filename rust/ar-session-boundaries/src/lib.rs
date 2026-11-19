#![forbid(unsafe_code)]

pub mod bystander;
pub mod non_identification;
pub mod sensor;
pub mod smart_city_boundary;
pub mod spatial_map;
pub mod stop_control;

pub use bystander::{
    select_bystander_handling_action, BystanderHandlingAction,
    BystanderHandlingError, BystanderHandlingPolicy, PrivacyGuardCondition,
};

pub use non_identification::{
    ArProcessingContract, DerivedOutputKind, NonIdentificationError,
};

pub use sensor::{
    validate_sensor_declaration, SensorAuditEvent, SensorDeclaration,
    SensorDeclarationError, SensorDuration, SensorRetention, SensorType,
};

pub use smart_city_boundary::{
    inbound_data_allowed, outbound_data_allowed, validate_inbound_data,
    validate_outbound_data, validate_outbound_report, InfrastructureInboundData,
    InfrastructureOutboundData, OutboundReportDeclaration, SmartCityBoundaryError,
};

pub use spatial_map::{
    SessionSpatialMap, SpatialMapError,
};

pub use stop_control::{
    apply_stop_request, StopControlContract, StopControlError, StopRequest,
};

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ArSessionState {
    Initiated,
    Active,
    Paused,
    Ended,
    Purged,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ArSessionError {
    InvalidTransition,
    UserInitiationRequired,
    VisibleStopControlRequired,
    BackgroundActivationProhibited,
    PersistentSpatialMapProhibited,
    CrossSessionStateProhibited,
    SensorStopRequiredBeforeEnd,
    PurgeRequiredAfterEnd,
    ExternalActionAuthorizationProhibited,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ArSession {
    pub state: ArSessionState,
    pub user_initiated: bool,
    pub visible_stop_control_available: bool,
    pub sensors_active: bool,
    pub volatile_state_present: bool,
    pub persistent_spatial_map_present: bool,
    pub cross_session_state_present: bool,
    pub background_activation_requested: bool,
    pub external_action_authorized: bool,
}

impl ArSession {
    #[must_use]
    pub fn initiate() -> Self {
        Self {
            state: ArSessionState::Initiated,
            user_initiated: true,
            visible_stop_control_available: true,
            sensors_active: false,
            volatile_state_present: false,
            persistent_spatial_map_present: false,
            cross_session_state_present: false,
            background_activation_requested: false,
            external_action_authorized: false,
        }
    }

    pub fn activate(mut self) -> Result<Self, ArSessionError> {
        self.require_state(ArSessionState::Initiated)?;
        self.validate_activation_boundaries()?;

        self.state = ArSessionState::Active;
        self.sensors_active = true;
        self.volatile_state_present = true;

        Ok(self)
    }

    pub fn pause(mut self) -> Result<Self, ArSessionError> {
        self.require_state(ArSessionState::Active)?;
        self.sensors_active = false;
        self.state = ArSessionState::Paused;

        Ok(self)
    }

    pub fn resume(mut self) -> Result<Self, ArSessionError> {
        self.require_state(ArSessionState::Paused)?;
        self.validate_activation_boundaries()?;

        self.state = ArSessionState::Active;
        self.sensors_active = true;

        Ok(self)
    }

    pub fn end(mut self) -> Result<Self, ArSessionError> {
        if !matches!(
            self.state,
            ArSessionState::Active | ArSessionState::Paused
        ) {
            return Err(ArSessionError::InvalidTransition);
        }

        if self.sensors_active {
            return Err(ArSessionError::SensorStopRequiredBeforeEnd);
        }

        self.state = ArSessionState::Ended;

        Ok(self)
    }

    pub fn purge(mut self) -> Result<Self, ArSessionError> {
        self.require_state(ArSessionState::Ended)?;

        if self.sensors_active {
            return Err(ArSessionError::SensorStopRequiredBeforeEnd);
        }

        self.volatile_state_present = false;
        self.persistent_spatial_map_present = false;
        self.cross_session_state_present = false;
        self.state = ArSessionState::Purged;

        self.validate()
            .map_err(|_| ArSessionError::PurgeRequiredAfterEnd)?;

        Ok(self)
    }

    pub fn validate(&self) -> Result<(), ArSessionError> {
        self.validate_static_boundaries()?;

        match self.state {
            ArSessionState::Initiated => {
                if self.sensors_active || self.volatile_state_present {
                    return Err(ArSessionError::InvalidTransition);
                }
            }
            ArSessionState::Active => {
                if !self.sensors_active || !self.volatile_state_present {
                    return Err(ArSessionError::InvalidTransition);
                }
            }
            ArSessionState::Paused => {
                if self.sensors_active || !self.volatile_state_present {
                    return Err(ArSessionError::InvalidTransition);
                }
            }
            ArSessionState::Ended => {
                if self.sensors_active {
                    return Err(ArSessionError::SensorStopRequiredBeforeEnd);
                }
            }
            ArSessionState::Purged => {
                if self.sensors_active
                    || self.volatile_state_present
                    || self.persistent_spatial_map_present
                    || self.cross_session_state_present
                {
                    return Err(ArSessionError::PurgeRequiredAfterEnd);
                }
            }
        }

        Ok(())
    }

    fn require_state(&self, expected: ArSessionState) -> Result<(), ArSessionError> {
        if self.state == expected {
            Ok(())
        } else {
            Err(ArSessionError::InvalidTransition)
        }
    }

    fn validate_activation_boundaries(&self) -> Result<(), ArSessionError> {
        self.validate_static_boundaries()
    }

    fn validate_static_boundaries(&self) -> Result<(), ArSessionError> {
        if !self.user_initiated {
            return Err(ArSessionError::UserInitiationRequired);
        }

        if !self.visible_stop_control_available {
            return Err(ArSessionError::VisibleStopControlRequired);
        }

        if self.background_activation_requested {
            return Err(ArSessionError::BackgroundActivationProhibited);
        }

        if self.persistent_spatial_map_present {
            return Err(ArSessionError::PersistentSpatialMapProhibited);
        }

        if self.cross_session_state_present {
            return Err(ArSessionError::CrossSessionStateProhibited);
        }

        if self.external_action_authorized {
            return Err(ArSessionError::ExternalActionAuthorizationProhibited);
        }

        Ok(())
    }
}
