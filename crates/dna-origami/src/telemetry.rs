// nanorobotics/dna-origami/src/telemetry.rs
use serde::{Deserialize, Serialize};
use crate::cadnano::CadnanoDesign;
use crate::geometry::NanoLattice;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StructureSnapshot {
    pub host_did: String,
    pub bostrom_address: String,
    pub design: Option<CadnanoDesign>,
    pub lattice: Option<NanoLattice>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StructureEnvelope {
    pub snapshot: StructureSnapshot,
    pub cybermode: String,
    pub nanoswarm_compliance: String,
}
