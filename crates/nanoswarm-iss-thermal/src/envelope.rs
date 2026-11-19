// filename: mk-bluebird/nanorobotics/crates/nanoswarm-iss-thermal/src/envelope.rs
// edition: 2024
// rust-version: 1.85

#![forbid(unsafe_code)]
#![deny(warnings)]

use serde::{Deserialize, Serialize};

use cybercore_identity::{HOST_DID, BOSTROM_ADDRESS};
use cybercore_roh_kernel::RiskOfHarmScalar;
use cybercore_evidence::EvidenceBundleRef;

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct ThermalCorridor {
    pub min: f32,
    pub warn: f32,
    pub max: f32,
}

impl ThermalCorridor {
    pub fn is_within(&self, value: f32) -> bool {
        value >= self.min && value <= self.max
    }

    pub fn is_warn(&self, value: f32) -> bool {
        value >= self.warn && value <= self.max
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct DutyCorridor {
    pub min: f32,
    pub warn: f32,
    pub max: f32,
}

impl DutyCorridor {
    pub fn is_within(&self, value: f32) -> bool {
        value >= self.min && value <= self.max
    }

    pub fn is_warn(&self, value: f32) -> bool {
        value >= self.warn && value <= self.max
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NanoswarmIssThermalRohEnvelope {
    pub hostdid: String,
    pub bostromaddress: String,
    pub aln_migration_clause: String,

    pub iss_config_id: String,
    pub he_controller_envelope_ref: String,
    pub mt_thermal_profile_ref: String,

    pub tissue_temp: ThermalCorridor,
    pub device_skin_temp: ThermalCorridor,
    pub swarm_duty: DutyCorridor,

    pub roh_weight_thermal_tissue: f32,
    pub roh_weight_thermal_device: f32,
    pub roh_weight_thermal_swarm_duty: f32,
    pub roh_ceiling_local: f32,

    pub pain_risk_weight_thermal: f32,
    pub fear_risk_weight_thermal: f32,

    pub iss_panel_shadow_factor_min: f32,
    pub iss_panel_shadow_factor_max: f32,
    pub iss_sun_exposure_duty_max: f32,
    pub iss_coolant_margin_min: f32,

    pub evidence_bundle_thermal_duty_ref: EvidenceBundleRef,
    pub evidence_bundle_device_profile_ref: EvidenceBundleRef,
    pub lipschitz_calibration_shard_ref: String,

    pub evolution_window_days: u32,
    pub forbid_downgrade: bool,
    pub monotone_tightening_only: bool,
}

impl NanoswarmIssThermalRohEnvelope {
    pub fn is_host_bound(&self) -> bool {
        self.hostdid == HOST_DID
            && self.bostromaddress == BOSTROM_ADDRESS
            && self.aln_migration_clause == ALN_MIGRATION_CYBERCORE_AUTHORITY_V1
    }

    pub fn roh_slice(
        &self,
        tissue_temp_c: f32,
        device_skin_temp_c: f32,
        swarm_duty_norm: f32,
    ) -> RiskOfHarmScalar {
        let r_tissue = self.normalized_risk(tissue_temp_c, &self.tissue_temp);
        let r_device = self.normalized_risk(device_skin_temp_c, &self.device_skin_temp);
        let r_duty = self.normalized_duty_risk(swarm_duty_norm, &self.swarm_duty);

        let roh = self.roh_weight_thermal_tissue * r_tissue
            + self.roh_weight_thermal_device * r_device
            + self.roh_weight_thermal_swarm_duty * r_duty;

        RiskOfHarmScalar::new_clamped(roh, self.roh_ceiling_local)
    }

    fn normalized_risk(&self, value: f32, corridor: &ThermalCorridor) -> f32 {
        if value <= corridor.warn {
            0.0
        } else if value >= corridor.max {
            1.0
        } else {
            (value - corridor.warn) / (corridor.max - corridor.warn)
        }
    }

    fn normalized_duty_risk(&self, value: f32, corridor: &DutyCorridor) -> f32 {
        if value <= corridor.warn {
            0.0
        } else if value >= corridor.max {
            1.0
        } else {
            (value - corridor.warn) / (corridor.max - corridor.warn)
        }
    }

    pub fn is_monotone_tightening(&self, previous: &Self) -> bool {
        if !self.forbid_downgrade || !self.monotone_tightening_only {
            return false;
        }

        self.roh_ceiling_local <= previous.roh_ceiling_local
            && self.tissue_temp.max <= previous.tissue_temp.max
            && self.device_skin_temp.max <= previous.device_skin_temp.max
            && self.swarm_duty.max <= previous.swarm_duty.max
            && self.roh_weight_thermal_tissue >= previous.roh_weight_thermal_tissue
            && self.roh_weight_thermal_device >= previous.roh_weight_thermal_device
            && self.roh_weight_thermal_swarm_duty >= previous.roh_weight_thermal_swarm_duty
    }
}
