#![forbid(unsafe_code)]

use nalgebra::SVector;
use serde::{Deserialize, Serialize};
use thiserror::Error;

pub const ROH_CEILING: f32 = 0.30;
pub const ALN_CLAUSE_AUTHORITY: &str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

pub type TsafeVec = SVector<f32, 7>;
pub type TsafeDoseVec = SVector<f32, 8>;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TwinState {
    pub hostdid: String,
    pub bostrom_address: String,
    pub aln_clause: String,
    pub z: Vec<f32>,
}

impl TwinState {
    pub fn is_authoritative(&self) -> bool {
        self.aln_clause == ALN_CLAUSE_AUTHORITY
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GovernanceVector {
    pub roh: f32,
    pub veco: f32,
    pub lyap: f32,
    pub kerk: f32,
    pub kere: f32,
    pub kerr: f32,
}

#[derive(Debug, Error)]
pub enum GuardViolation {
    #[error("RoH ceiling violated: roh={0} > {ROH_CEILING}")]
    RoHExceeded(f32),
    #[error("Tsafe polytope violated")]
    TsafeViolated,
    #[error("Eco invariant violated (Veco)")]
    VecoViolated,
    #[error("Lyapunov not descending")]
    LyapunovViolated,
    #[error("Twin state not bound to Cybercore authority ALN clause")]
    InvalidAlnClause,
}

pub fn project_twin_to_tsafe(state: &TwinState) -> TsafeVec {
    SVector::<f32, 7>::new(
        extract_neuromorphic(state),
        extract_inflammatory(state),
        extract_renal(state),
        extract_microvascular(state),
        extract_cardiac(state),
        extract_thermal(state),
        extract_nano_density(state),
    )
}

pub fn project_tsafe_to_governance(x: &TsafeVec) -> GovernanceVector {
    let r_neu = W_NEU * x[0];
    let r_infl = W_INFL * x[1];
    let r_renal = W_RENAL * x[2];
    let r_micro = W_MICRO * x[3] + W_NANO * x[6];
    let r_card = W_CARD * x[4];
    let r_therm = W_THERM * x[5];

    let roh_twin = r_neu
        .max(r_infl)
        .max(r_renal)
        .max(r_micro)
        .max(r_card)
        .max(r_therm)
        .min(ROH_CEILING)
        .max(0.0);

    let veco = compute_veco(x);
    let lyap = compute_lyap_from_twin(x);
    let (kerk, kere, kerr) = compute_ker_axes(x);

    GovernanceVector {
        roh: roh_twin,
        veco,
        lyap,
        kerk,
        kere,
        kerr,
    }
}

pub fn guard_governance_step(
    twin: &TwinState,
    tsafe: &TsafeVec,
    governance: &GovernanceVector,
    tsafe_inside_polytope: bool,
    prev_lyap: f32,
    next_lyap: f32,
    veco_monotone_ok: bool,
) -> Result<(), GuardViolation> {
    if !twin.is_authoritative() {
        return Err(GuardViolation::InvalidAlnClause);
    }

    if governance.roh > ROH_CEILING + f32::EPSILON {
        return Err(GuardViolation::RoHExceeded(governance.roh));
    }

    if !tsafe_inside_polytope {
        return Err(GuardViolation::TsafeViolated);
    }

    if !veco_monotone_ok {
        return Err(GuardViolation::VecoViolated);
    }

    if next_lyap > prev_lyap + 1.0e-6 {
        return Err(GuardViolation::LyapunovViolated);
    }

    Ok(())
}

fn extract_neuromorphic(_state: &TwinState) -> f32 {
    0.0
}

fn extract_inflammatory(_state: &TwinState) -> f32 {
    0.0
}

fn extract_renal(_state: &TwinState) -> f32 {
    0.0
}

fn extract_microvascular(_state: &TwinState) -> f32 {
    0.0
}

fn extract_cardiac(_state: &TwinState) -> f32 {
    0.0
}

fn extract_thermal(_state: &TwinState) -> f32 {
    0.0
}

fn extract_nano_density(_state: &TwinState) -> f32 {
    0.0
}

const W_NEU: f32 = 1.0;
const W_INFL: f32 = 1.0;
const W_RENAL: f32 = 1.0;
const W_MICRO: f32 = 1.0;
const W_NANO: f32 = 1.0;
const W_CARD: f32 = 1.0;
const W_THERM: f32 = 1.0;

fn compute_veco(_x: &TsafeVec) -> f32 {
    0.0
}

fn compute_lyap_from_twin(_x: &TsafeVec) -> f32 {
    0.0
}

fn compute_ker_axes(_x: &TsafeVec) -> (f32, f32, f32) {
    (0.0, 0.0, 0.0)
}
