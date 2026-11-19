#![forbid(unsafe_code)]

pub struct PhysioCaps {
    pub roh_ceiling: f32,
    pub hr_max_bpm: f32,
    // ... existing fields (Tsafe, organ corridors, etc.)
}

pub struct PhysioState {
    // Existing physio axes (example based on your Phoenix harness).[file:17]
    pub hrv_sdnn_ms: f32,
    pub eeg_theta_beta_ratio: f32,
    pub core_temp_delta_c: f32,
    pub il6_pg_ml: f32,
    pub fatigue_index: f32,
    pub eco_impact_score: f32,
    pub core_temp_c: f32,
    pub baseline_core_temp_c: f32,
    pub brain_temp_c: f32,
    pub hr_bpm: f32,
    pub hr_rest_bpm: f32,
    pub hr_max_bpm: f32,
    pub hr_capacity_fraction: f32,
    pub hr_capacity_effective: f32,
    pub temp_dev_norm: f32,
    pub chronotrope_flag: f32,

    /// Global Risk-of-Harm scalar, normalized 0.0–1.0.
    pub roh_scalar: f32,

    /// New: normalized UV risk axis, 0.0–1.0.
    /// 0.0 = fully safe UV regime given current materials and swarm shading;
    /// 1.0 = at or beyond the UV corridor boundary.
    pub uv_risk_norm: f32,
}

impl PhysioState {
    /// Set the normalized UV risk axis.
    /// This must always be in [0.0, 1.0].
    pub fn set_uv_risk_axis(&mut self, v: f32) {
        self.uv_risk_norm = v.clamp(0.0, 1.0);
    }

    /// Set the global RoH scalar.
    /// Callers must respect caps.roh_ceiling.
    pub fn set_roh_scalar(&mut self, v: f32) {
        self.roh_scalar = v.max(0.0);
    }
}

/// Canonical RoH kernel, extended to include the UV axis.
/// This must preserve the global RoH ≤ 0.30 guarantee.[file:17][file:21]
pub fn calculate_roh(state: &PhysioState, caps: &PhysioCaps) -> f32 {
    // Example structure: weights are calibrated and stored in ALN shards.
    // Here we show the pattern, not final numbers.
    let w_thermal = 0.30_f32;
    let w_cardiac = 0.25_f32;
    let w_inflammatory = 0.20_f32;
    let w_psych = 0.15_f32;
    let w_uv = 0.10_f32;

    // Existing normalized axes, already clamped 0–1 upstream.
    let r_thermal = state.temp_dev_norm.clamp(0.0, 1.0);
    let r_cardiac = (state.hr_bpm - state.hr_rest_bpm)
        / (state.hr_max_bpm - state.hr_rest_bpm + 1.0e-6);
    let r_cardiac = r_cardiac.clamp(0.0, 1.0);
    let r_inflammatory = (state.il6_pg_ml / 1000.0).clamp(0.0, 1.0);
    let r_psych = state.fatigue_index.clamp(0.0, 1.0);

    // New UV axis.
    let r_uv = state.uv_risk_norm.clamp(0.0, 1.0);

    // Convex combination + max “guardrail” to remain conservative.[file:19][file:21]
    let roh_linear = w_thermal * r_thermal
        + w_cardiac * r_cardiac
        + w_inflammatory * r_inflammatory
        + w_psych * r_psych
        + w_uv * r_uv;

    let roh_max = r_thermal
        .max(r_cardiac)
        .max(r_inflammatory)
        .max(r_psych)
        .max(r_uv);

    // Conservative combination: never below any single axis, bounded by roh_ceiling in callers.
    roh_linear.max(roh_max * 0.3)
}
