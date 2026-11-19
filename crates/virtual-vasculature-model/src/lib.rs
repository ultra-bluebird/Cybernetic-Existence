// filename: nanorobotics/crates/virtual-vasculature-model/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

use serde::{Deserialize, Serialize};
use bioscale_upgrade_store::evidencebundle10::EvidenceBundle10;

pub const HOST_DID: &str = "did:aln:organic-host";
pub const PRIMARY_BOSTROM_ADDRESS: &str =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
pub const ALN_MIGRATION_CLAUSE: &str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct VirtualBloodVessel {
    pub vessel_id: u64,
    pub host_did: String,
    pub bostrom_address: String,
    pub aln_migration_clause: String,
    pub diameter_m: f32,
    pub length_m: f32,
    pub flow_rate_ml_s: f32,
    pub shear_stress_pa: f32,
    pub pressure_mm_hg: f32,
    pub nanoswarm_density_norm: f32,
    pub evidence: EvidenceBundle10,
}

impl VirtualBloodVessel {
    pub fn new(
        vessel_id: u64,
        diameter_m: f32,
        length_m: f32,
        flow_rate_ml_s: f32,
        shear_stress_pa: f32,
        pressure_mm_hg: f32,
        nanoswarm_density_norm: f32,
        evidence: EvidenceBundle10,
    ) -> Result<Self, &'static str> {
        if diameter_m <= 0.0 || length_m <= 0.0 {
            return Err("Non-positive vessel geometry");
        }
        if flow_rate_ml_s < 0.0 || shear_stress_pa < 0.0 || pressure_mm_hg < 0.0 {
            return Err("Negative hemodynamic quantity");
        }
        if nanoswarm_density_norm < 0.0 {
            return Err("Negative nanoswarm density");
        }
        if !evidence.kinds_ok() {
            return Err("EvidenceBundle10 kinds missing or duplicated");
        }
        Ok(Self {
            vessel_id,
            host_did: HOST_DID.to_string(),
            bostrom_address: PRIMARY_BOSTROM_ADDRESS.to_string(),
            aln_migration_clause: ALN_MIGRATION_CLAUSE.to_string(),
            diameter_m,
            length_m,
            flow_rate_ml_s,
            shear_stress_pa,
            pressure_mm_hg,
            nanoswarm_density_norm,
            evidence,
        })
    }
}
