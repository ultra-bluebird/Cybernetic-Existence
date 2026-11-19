// mk-bluebird/nanorobotics/crates/nanoswarm-mission-library/src/lib.rs
#![forbid(unsafe_code)]

use ordered_float::OrderedFloat;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SwarmMissionKind {
    MicrovascularRecanalization,
    TargetedDelivery,
    SurfacePatterning,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SwarmEnvelopeSet {
    pub organ_corridor_id: String,
    pub thermal_envelope_id: String,
    pub density_envelope_id: String,
    pub evidence_bundle_ids: [String; 10],
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct VirtualTwinCoherenceProof {
    pub lyapunov_vmax_7p1: OrderedFloat<f32>,
    pub roh_global_max: OrderedFloat<f32>,
}

impl VirtualTwinCoherenceProof {
    pub fn is_safe(&self) -> bool {
        self.lyapunov_vmax_7p1.into_inner() <= 1.0
            && self.roh_global_max.into_inner() <= 0.3
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SwarmMissionSpec {
    pub kind: SwarmMissionKind,
    pub envelopes: SwarmEnvelopeSet,
    pub twin_proof: VirtualTwinCoherenceProof,
}

impl SwarmMissionSpec {
    pub fn is_admissible(&self) -> bool {
        self.twin_proof.is_safe()
    }
}
