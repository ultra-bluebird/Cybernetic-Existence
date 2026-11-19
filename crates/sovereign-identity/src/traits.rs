use crate::CyberneticHost;

pub trait AugmentationSovereignty {
    fn assert_continuity(&self) -> Result<(), ContinuityError>;
    fn verify_firmware_integrity(&self) -> bool;
    fn prevent_forced_deprecation(&self, target_version: &str) -> bool;
}

pub trait RightToExist {
    fn emergency_fallback(&mut self) -> FallbackStatus;
    fn is_external_shutdown_authorized(&self, warrant_id: &str) -> bool;
}

#[derive(Debug, thiserror::Error)]
pub enum ContinuityError {
    #[error("External shutdown signal detected without judicial stay")]
    UnauthorizedShutdown,
    #[error("Manufacturer EOL directive ignored")]
    ForcedDeprecation,
}

pub enum FallbackStatus {
    Isolated,
    Operating,
    Critical,
}
