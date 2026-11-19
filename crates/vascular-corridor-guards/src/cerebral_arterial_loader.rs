// mk-bluebird/nanorobotics/crates/vascular-corridor-guards/src/cerebral_arterial_loader.rs
// edition: 2024, rust-version: 1.85

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

use cybercore_aln_loader::{AlnError, AlnHeaderView, AlnLoader, AlnShardHeader};

use crate::{
    CerebralCapillaryCorridor,
    CapillaryDensityCorridorConfig,
    CapillaryFpParams,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CerebralArterialCorridorCalibrationV1 {
    pub header: AlnShardHeader,

    pub corridor_id: String,
    pub organ_id: String,
    pub vascular_tree_id: String,
    pub segment_type: String,

    pub wss_setpoint_pa: f32,
    pub wss_lower_pa: f32,
    pub wss_upper_pa: f32,
    pub osi_max: f32,

    pub hct_systemic_min: f32,
    pub hct_systemic_max: f32,
    pub hct_tube_min: f32,
    pub hct_tube_max: f32,

    pub phi_tot_maxsafe: f32,
    pub rho_ceiling_per_m3: f32,
    pub densityrisk_max_exceed_fraction: f32,

    pub clog_score_softthreshold: f32,
    pub clog_score_hardthreshold: f32,

    pub fp_dx_m: f32,
    pub fp_dt_s: f32,
    pub fp_diffusion_m2_per_s: f32,
    pub fp_velocity_m_per_s: f32,
    pub fp_max_horizon_s: f32,

    pub roh_weight_density: f32,
    pub roh_weight_clogging: f32,
    pub roh_slice_max: f32,
}

impl AlnHeaderView for CerebralArterialCorridorCalibrationV1 {
    fn header(&self) -> &AlnShardHeader {
        &self.header
    }
}

pub struct CerebralArterialCorridorLoader;

#[async_trait::async_trait]
impl AlnLoader<CerebralArterialCorridorCalibrationV1> for CerebralArterialCorridorLoader {
    fn validate_integrity(data: &CerebralArterialCorridorCalibrationV1) -> bool {
        if !(data.roh_slice_max > 0.0 && data.roh_slice_max <= 0.30) {
            return false;
        }

        if !(data.hct_systemic_min >= 0.0
            && data.hct_systemic_max <= 1.0
            && data.hct_systemic_min < data.hct_systemic_max)
        {
            return false;
        }
        if !(data.hct_tube_min >= 0.0
            && data.hct_tube_max <= 1.0
            && data.hct_tube_min < data.hct_tube_max)
        {
            return false;
        }

        if !(data.phi_tot_maxsafe > 0.0 && data.phi_tot_maxsafe < 1.0) {
            return false;
        }
        if !(data.rho_ceiling_per_m3 > 0.0) {
            return false;
        }
        if !(data.densityrisk_max_exceed_fraction >= 0.0
            && data.densityrisk_max_exceed_fraction <= 1.0)
        {
            return false;
        }

        if !(data.clog_score_softthreshold >= 0.0
            && data.clog_score_hardthreshold > data.clog_score_softthreshold)
        {
            return false;
        }

        if !(data.fp_dx_m > 0.0
            && data.fp_dt_s > 0.0
            && data.fp_diffusion_m2_per_s > 0.0)
        {
            return false;
        }

        let k: f32 = 0.4;
        let max_dt = k * data.fp_dx_m * data.fp_dx_m / data.fp_diffusion_m2_per_s;
        if !(data.fp_dt_s <= max_dt) {
            return false;
        }

        if !(data.fp_velocity_m_per_s >= 0.0 && data.fp_velocity_m_per_s <= 0.1) {
            return false;
        }
        if !(data.fp_max_horizon_s > 0.0 && data.fp_max_horizon_s <= 10.0) {
            return false;
        }

        if data.roh_weight_density < 0.0 || data.roh_weight_clogging < 0.0 {
            return false;
        }
        let worst_case_roh = data.roh_weight_density + data.roh_weight_clogging;
        if worst_case_roh > data.roh_slice_max + f32::EPSILON {
            return false;
        }

        true
    }
}

pub async fn load_cerebral_arterial_corridor_calibration(
    path: &str,
) -> Result<CerebralArterialCorridorCalibrationV1, AlnError> {
    CerebralArterialCorridorLoader::load_calibration(path).await
}

pub fn build_cerebral_capillary_corridor(
    calib: CerebralArterialCorridorCalibrationV1,
) -> CerebralCapillaryCorridor {
    let corridor_cfg = CapillaryDensityCorridorConfig {
        phi_tot_maxsafe: calib.phi_tot_maxsafe,
        rho_ceiling_per_m3: calib.rho_ceiling_per_m3,
        max_exceed_fraction: calib.densityrisk_max_exceed_fraction,
    };

    let fp_params = CapillaryFpParams {
        dx_m: calib.fp_dx_m,
        dt_s: calib.fp_dt_s,
        diffusion_m2_per_s: calib.fp_diffusion_m2_per_s,
        velocity_m_per_s: calib.fp_velocity_m_per_s,
        max_horizon_s: calib.fp_max_horizon_s,
    };

    CerebralCapillaryCorridor::new(
        corridor_cfg,
        fp_params,
        calib.clog_score_softthreshold,
        calib.clog_score_hardthreshold,
        calib.roh_weight_density,
        calib.roh_weight_clogging,
        calib.roh_slice_max,
    )
}
