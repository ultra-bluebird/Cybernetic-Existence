// mk-bluebird/nanorobotics/crates/nanoswarm-shared-control/src/types.rs
use nalgebra::{Vector3, VectorN, U8};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostDid(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BostromAddress(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostBinding {
    pub host_did: HostDid,
    pub bostrom_address: BostromAddress,
    pub aln_clause: String,
}

impl HostBinding {
    pub fn cybercore_authoritative() -> Self {
        Self {
            host_did: HostDid("did:vital:bostrom".to_owned()),
            bostrom_address: BostromAddress(
                "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_owned(),
            ),
            aln_clause: "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1".to_owned(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct UnifiedSafetyAxes7Plus1 {
    /// Canonical 7D clinical axes + lifeforce leakage scalar.
    /// Normalized to [0,1] per axis, with V(x) <= 1 enforced by Lyapunov guard.
    pub axes: [f32; 8],
}

impl UnifiedSafetyAxes7Plus1 {
    pub fn as_vector(&self) -> VectorN<f32, U8> {
        VectorN::<f32, U8>::from_row_slice(&self.axes)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct BiomarkerSnapshot {
    pub lifeforce_scalar: f32,
    pub roh_scalar: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum SwarmFormationMode {
    Stream,
    Sheet,
    Plug,
    SparseSentinel,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct SwarmCommand {
    pub velocity: Vector3<f32>,
    pub formation: SwarmFormationMode,
    pub actuation_intensity: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct SwarmState {
    pub position: Vector3<f32>,
    pub velocity: Vector3<f32>,
    pub local_density: f32,
    pub local_temperature: f32,
    pub distance_to_no_fly: f32,
    pub unified_axes_7p1: UnifiedSafetyAxes7Plus1,
    pub biomarkers: BiomarkerSnapshot,
}
