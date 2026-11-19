// filename: nanorobotics/crates/virtual-organ-interface/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

use serde::{Deserialize, Serialize};
use cybernano_physio_7d_guards::{Physio7DState, Physio7DTier};
use state_vector_roh_kernel::{RoHProjection, SafetyVerdict};
use virtual_organ_model::VirtualOrgan;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct NanoswarmActuationSummary {
    pub organ_id: String,
    pub duty_cycle: f32,
    pub density_norm: f32,
    pub propulsion_power_w: f32,
    pub thermal_power_w: f32,
    pub chemical_dose_norm: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct HostTelemetrySnapshot {
    pub heart_rate_bpm: f32,
    pub core_temp_c: f32,
    pub il6_pg_ml: f32,
    pub creatinine_mg_dl: f32,
    pub hrv_rmssd_ms: f32,
    pub uhi_index: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct OrganSafetyVerdict {
    pub organ_id: String,
    pub physio_state: Physio7DState,
    pub roh_projection: RoHProjection,
    pub tier: Physio7DTier,
    pub verdict: SafetyVerdict,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct OrganCorridorViolation {
    pub organ_id: String,
    pub thermal_excess: f32,
    pub mechanical_excess: f32,
    pub chemical_excess: f32,
}

pub fn evaluate_organ_safety(
    organ: &VirtualOrgan,
    actuation: &NanoswarmActuationSummary,
    telemetry: &HostTelemetrySnapshot,
) -> (OrganSafetyVerdict, Option<OrganCorridorViolation>) {
    // Map raw telemetry + actuation into normalized axes (implementation-specific formulas).
    let neu = telemetry.hrv_rmssd_ms;         // normalized elsewhere
    let inflam = telemetry.il6_pg_ml;         // normalized elsewhere
    let renal = telemetry.creatinine_mg_dl;   // normalized elsewhere
    let micro = actuation.density_norm;       // refined by GraphSpectralRisk
    let cardiac = telemetry.heart_rate_bpm;   // normalized elsewhere
    let thermal = actuation.thermal_power_w;  // normalized + bioheat solver
    let material = actuation.chemical_dose_norm;

    let phys = organ.to_physio_state(
        neu,
        inflam,
        renal,
        micro,
        cardiac,
        thermal,
        material,
    );

    let safe_poly = organ.is_state_safe(phys);
    let tier = cybernano_physio_7d_guards::classify_tier(phys, organ.corridors.physio_bounds);

    let roh_projection = state_vector_roh_kernel::compute_roh_from_physio(phys);

    let verdict = if !safe_poly {
        SafetyVerdict::Veto
    } else {
        roh_projection.verdict
    };

    let violation = if safe_poly {
        None
    } else {
        Some(OrganCorridorViolation {
            organ_id: organ.organ_id.clone(),
            thermal_excess: 0.0,
            mechanical_excess: 0.0,
            chemical_excess: 0.0,
        })
    };

    (
        OrganSafetyVerdict {
            organ_id: organ.organ_id.clone(),
            physio_state: phys,
            roh_projection,
            tier,
            verdict,
        },
        violation,
    )
}
