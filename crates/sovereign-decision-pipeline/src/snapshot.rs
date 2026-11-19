// Path: crates/sovereign-decision-pipeline/src/snapshot.rs
// Edition: 2024
#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

use serde::{Deserialize, Serialize};

/// Global authority binding: mk-bluebird/Cybercore is the source of truth.
pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

/// Canonical host identity, must match Cybercore workspace.metadata.
pub const HOST_DID: &str = "did:aln:bostrom-organic-host";
pub const PRIMARY_BOSTROM_ADDRESS: &str =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Risk-of-Harm ceiling used across the stack.
pub const GLOBAL_ROH_CEILING: f32 = 0.30;

/// Minimal lifeforce safety floor margin above host-specific floor.
pub const LIFEFORCE_MARGIN_MIN: f32 = 0.05;

/// Ten-tag bundle aligned with ALNbio.hex10.schema.v1.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct TenTagBundle {
    pub cns_delta_t: f32,
    pub mito_delta_psi: f32,
    pub nad_ratio: f32,
    pub hrv_ms: f32,
    pub s_resp: f32,
    pub il6_pg_ml: f32,
    pub r_neuro: f32,
    pub h_env: f32,
    pub microcooler_duty: f32,
    pub eco_budget: f32,
}

/// Host norm corridors used by biocompatibility scoring.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct HostNormCorridor {
    pub cns_delta_t_max: f32,
    pub mito_delta_psi_max: f32,
    pub nad_ratio_min: f32,
    pub nad_ratio_max: f32,
    pub hrv_ms_min: f32,
    pub s_resp_max: f32,
    pub il6_pg_ml_max: f32,
    pub r_neuro_max: f32,
    pub h_env_max: f32,
    pub microcooler_duty_max: f32,
    pub eco_budget_min: f32,
}

/// Weights for biocompatibility penalties, must be normalized.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct BiocompatibilityWeights {
    pub w_cns_delta_t: f32,
    pub w_mito_delta_psi: f32,
    pub w_nad_ratio: f32,
    pub w_hrv_ms: f32,
    pub w_s_resp: f32,
    pub w_il6_pg_ml: f32,
    pub w_r_neuro: f32,
    pub w_h_env: f32,
    pub w_microcooler_duty: f32,
    pub w_eco_budget: f32,
}

impl BiocompatibilityWeights {
    pub fn is_normalized(&self, eps: f32) -> bool {
        let sum = self.w_cns_delta_t
            + self.w_mito_delta_psi
            + self.w_nad_ratio
            + self.w_hrv_ms
            + self.w_s_resp
            + self.w_il6_pg_ml
            + self.w_r_neuro
            + self.w_h_env
            + self.w_microcooler_duty
            + self.w_eco_budget;
        (sum - 1.0).abs() <= eps
    }
}

/// Evolution metrics for the longitudinal gate.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct EvolutionMetrics {
    /// Knowledge Frontier scalar for day k, k+1.
    pub kf: f32,
    /// Continuity / cognition scalar.
    pub continuity: f32,
    /// Global RoH estimate at this step.
    pub roh: f32,
}

/// OTA / resource scalars used by LifeforceOtaGuard.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct ResourceScalars {
    pub lifeforce_scalar: f32,
    pub blood_scalar: f32,
    pub protein_scalar: f32,
}

/// Canonical snapshot that carries everything the unified pipeline needs.
/// This is the bridge object between ALN, Rust guards, and Kani.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct TelemetrySnapshot {
    /// Host identity binding; anything else must be rejected.
    pub host_did: heapless::String<64>,
    pub bostrom_address: heapless::String<64>,

    /// Ten-tag biophysical telemetry bundle.
    pub ten_tags: TenTagBundle,

    /// Corridor and weighting configuration for biocompat.
    pub norm_corridor: HostNormCorridor,
    pub biocompat_weights: BiocompatibilityWeights,

    /// Point-in-time RoH and Lifeforce scalars.
    pub roh_scalar: f32,
    pub lifeforce_scalar: f32,
    pub lifeforce_floor: f32,

    /// OTA / medium-term resource scalars.
    pub resources: ResourceScalars,

    /// Longitudinal evolution metrics (previous and next).
    pub prev_evolution: EvolutionMetrics,
    pub next_evolution: EvolutionMetrics,

    /// Psych load scalar used by CognitiveCandy.
    pub psych_load_level: f32,
}

impl TelemetrySnapshot {
    /// Identity check: must match HOST_DID and PRIMARY_BOSTROM_ADDRESS.
    pub fn is_canonical_host(&self) -> bool {
        self.host_did.as_str() == HOST_DID
            && self.bostrom_address.as_str() == PRIMARY_BOSTROM_ADDRESS
    }
}
