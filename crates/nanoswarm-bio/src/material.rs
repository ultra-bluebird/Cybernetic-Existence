// File: crates/nanoswarm-bio/src/material.rs
// Destination: mk-bluebird/nanorobotics/crates/nanoswarm-bio/src/material.rs

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

/// Nanoswarm material families, matching your biocompatibility and risk design.[file:44]
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum NanoswarmMaterialFamily {
    GoldColloid,
    IronOxide,
    SilicaPorous,
    LipidNanocarrier,
    PolymerPegylated,
    CarbonDot,
}
