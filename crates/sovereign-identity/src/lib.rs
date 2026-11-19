pub mod traits;

/// The primary identity marker for an active augmented citizen.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CyberneticHost {
    pub id: String,
    pub active_implants: Vec<String>,
    pub continuity_protocols: Vec<String>,
}
