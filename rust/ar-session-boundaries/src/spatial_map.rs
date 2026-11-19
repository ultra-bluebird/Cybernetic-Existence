use crate::{ArSession, ArSessionError, ArSessionState};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SpatialMapError {
    SessionNotActiveOrPaused,
    PersistentStorageProhibited,
    CloudUploadProhibited,
    AnalyticsExportProhibited,
    CrossSessionReuseProhibited,
    LocationInferenceProhibited,
    Session(ArSessionError),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SessionSpatialMap {
    pub session_ref: String,
    pub present: bool,
    pub persistent_storage_requested: bool,
    pub cloud_upload_requested: bool,
    pub analytics_export_requested: bool,
    pub cross_session_reuse_requested: bool,
    pub location_inference_requested: bool,
}

impl SessionSpatialMap {
    pub fn create_for_session(
        session: &ArSession,
        session_ref: String,
    ) -> Result<Self, SpatialMapError> {
        if !matches!(
            session.state,
            ArSessionState::Active | ArSessionState::Paused
        ) {
            return Err(SpatialMapError::SessionNotActiveOrPaused);
        }

        session.validate().map_err(SpatialMapError::Session)?;

        Ok(Self {
            session_ref,
            present: true,
            persistent_storage_requested: false,
            cloud_upload_requested: false,
            analytics_export_requested: false,
            cross_session_reuse_requested: false,
            location_inference_requested: false,
        })
    }

    pub fn validate(&self) -> Result<(), SpatialMapError> {
        if self.persistent_storage_requested {
            return Err(SpatialMapError::PersistentStorageProhibited);
        }

        if self.cloud_upload_requested {
            return Err(SpatialMapError::CloudUploadProhibited);
        }

        if self.analytics_export_requested {
            return Err(SpatialMapError::AnalyticsExportProhibited);
        }

        if self.cross_session_reuse_requested {
            return Err(SpatialMapError::CrossSessionReuseProhibited);
        }

        if self.location_inference_requested {
            return Err(SpatialMapError::LocationInferenceProhibited);
        }

        Ok(())
    }

    pub fn purge(mut self) -> Result<Self, SpatialMapError> {
        self.validate()?;
        self.present = false;

        Ok(self)
    }
}
