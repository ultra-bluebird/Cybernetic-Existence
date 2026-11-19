// filename: crates/cybernano-shear-thermo-metro/src/lib.rs
// edition: 2024
// rust-version: 1.85
// license: MIT OR Apache-2.0

#![forbid(unsafe_code)]
#![deny(warnings)]

use serde::{Deserialize, Serialize};

/// Sovereignty binding shared across all host-critical structs.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HostSovereigntyBinding {
    pub host_did: String,
    pub bostrom_address: String,
    pub governed_by: String,
}

impl HostSovereigntyBinding {
    pub const PRIMARY_DID: &'static str = "did.aln.bostrom-organic-host";
    pub const PRIMARY_BOSTROM: &'static str =
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    pub const REQUIRED_CLAUSE: &'static str =
        "ALN.MIGRATION.CYBERCOREAUTHORITY.v1";

    pub fn is_primary_and_compliant(&self) -> bool {
        self.host_did == Self::PRIMARY_DID
            && self.bostrom_address == Self::PRIMARY_BOSTROM
            && self.governed_by == Self::REQUIRED_CLAUSE
    }
}

/// 91. FPGA-ready liquid state machine reservoir for WSS prediction.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LsmReservoirConfig {
    pub num_units: usize,
    pub spectral_radius: f32,
    pub leak_rate: f32,
    pub input_scale: f32,
    pub quant_bits: u8,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LsmReadout {
    /// Flattened matrix of shape [num_outputs, num_units + num_inputs].
    pub weights: Vec<i16>,
    /// Fixed-point scale factor for weights (e.g., 2^-q).
    pub weight_scale: f32,
    pub num_inputs: usize,
    pub num_units: usize,
    pub num_outputs: usize,
}

/// Single-timestep fixed-point reservoir update + linear readout.
/// This is written in scalar form so it can be mapped directly to FPGA fabric.
pub fn lsm_step_fixed(
    cfg: &LsmReservoirConfig,
    readout: &LsmReadout,
    state: &mut [i16],
    input: &[i16],
    reservoir_w: &[i16],
    reservoir_scale: f32,
    out: &mut [f32],
) {
    let n = cfg.num_units;
    let nin = input.len();
    assert_eq!(state.len(), n);
    assert_eq!(reservoir_w.len(), n * n);
    assert_eq!(readout.num_units, n);
    assert_eq!(readout.num_inputs, nin);
    assert_eq!(out.len(), readout.num_outputs);

    // Reservoir update: x_{t+1} = (1 - leak)*x_t + leak * tanh(Wx + Win u)
    // Implemented in fixed-point with an approximate tanh.
    let leak = cfg.leak_rate;
    let one_minus_leak = 1.0f32 - leak;

    // Temporary floating state for correctness; FPGA implementation can be direct fixed-point.
    let mut new_state_f = vec![0.0f32; n];

    for i in 0..n {
        let mut sum = 0.0f32;

        // Recurrent term.
        for j in 0..n {
            let w_ij = reservoir_w[i * n + j] as f32 * reservoir_scale;
            sum += w_ij * (state[j] as f32);
        }

        // Input term (simple fan-in).
        for k in 0..nin {
            // Here we assume input weights are folded into readout; reservoir sees scaled inputs.
            let in_scale = cfg.input_scale;
            sum += in_scale * (input[k] as f32);
        }

        let x_prev = state[i] as f32;
        // Smooth, hardware-friendly tanh approximation.
        let x_raw = sum;
        let x_nl = x_raw.tanh();
        let x_next = one_minus_leak * x_prev + leak * x_nl;
        new_state_f[i] = x_next;
    }

    // Quantize back into fixed-point.
    let max_q = (1i16::MAX) as f32;
    for i in 0..n {
        let v = new_state_f[i].clamp(-1.0, 1.0);
        state[i] = (v * max_q) as i16;
    }

    // Readout: y = W_out [x; u].
    let qw = readout.weight_scale;
    for o in 0..readout.num_outputs {
        let mut acc = 0.0f32;
        let row_offset = o * (readout.num_units + readout.num_inputs);

        // Reservoir part.
        for i in 0..readout.num_units {
            let w = readout.weights[row_offset + i] as f32 * qw;
            acc += w * (state[i] as f32);
        }
        // Input skip-connection part.
        for k in 0..readout.num_inputs {
            let w = readout.weights[row_offset + readout.num_units + k] as f32 * qw;
            acc += w * (input[k] as f32);
        }

        out[o] = acc;
    }
}

/// Empirical error envelope bin keyed by geometry and nanoswarm density.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WssErrorBinKey {
    pub vessel_radius_mm: f32,
    pub curvature_norm: f32,
    pub stenosis_fraction: f32,
    pub nano_volume_fraction: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WssErrorEnvelopeBin {
    pub key: WssErrorBinKey,
    /// 95th-percentile relative error upper bound for this bin.
    pub rel_error_p95: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WssErrorEnvelopeShard {
    pub sovereignty: HostSovereigntyBinding,
    pub bins: Vec<WssErrorEnvelopeBin>,
}

impl WssErrorEnvelopeShard {
    pub fn validate(&self) -> Result<(), String> {
        if !self.sovereignty.is_primary_and_compliant() {
            return Err("sovereignty binding mismatch for WssErrorEnvelopeShard".into());
        }
        for b in &self.bins {
            if !(b.rel_error_p95 >= 0.0 && b.rel_error_p95 <= 1.0) {
                return Err("rel_error_p95 must lie in [0,1]".into());
            }
        }
        Ok(())
    }

    /// Conservative inflation of predicted WSS by bin-specific error.
    pub fn inflate_wss(
        &self,
        geom: &WssErrorBinKey,
        wss_pred: f32,
    ) -> f32 {
        let mut best = None::<&WssErrorEnvelopeBin>;
        for b in &self.bins {
            let dr = (b.key.vessel_radius_mm - geom.vessel_radius_mm).abs();
            let dc = (b.key.curvature_norm - geom.curvature_norm).abs();
            let ds = (b.key.stenosis_fraction - geom.stenosis_fraction).abs();
            let dn = (b.key.nano_volume_fraction - geom.nano_volume_fraction).abs();
            let dist = dr + dc + ds + dn;
            match best {
                None => best = Some(b),
                Some(prev) => {
                    let drp = (prev.key.vessel_radius_mm - geom.vessel_radius_mm).abs();
                    let dcp = (prev.key.curvature_norm - geom.curvature_norm).abs();
                    let dsp = (prev.key.stenosis_fraction - geom.stenosis_fraction).abs();
                    let dnp = (prev.key.nano_volume_fraction - geom.nano_volume_fraction).abs();
                    let dist_prev = drp + dcp + dsp + dnp;
                    if dist < dist_prev {
                        best = Some(b);
                    }
                }
            }
        }
        if let Some(bin) = best {
            let factor = 1.0 + bin.rel_error_p95;
            wss_pred * factor
        } else {
            wss_pred
        }
    }
}

/// 92. Discrete master-equation model for nanoswarm–tissue energy exchange.

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EnergyStateGrid {
    /// Internal energy levels (J) per nanorobot mode, sorted ascending.
    pub energy_levels_j: Vec<f32>,
    /// Probability mass per level and compartment [level][compartment].
    pub p: Vec<Vec<f32>>,
}

impl EnergyStateGrid {
    pub fn normalize(&mut self) {
        let mut total = 0.0f32;
        for row in &self.p {
            for v in row {
                total += *v;
            }
        }
        if total > 0.0 {
            for row in &mut self.p {
                for v in row {
                    *v /= total;
                }
            }
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TransitionRateMatrix {
    /// W[(j,l) -> (i,k)] flattened as [to_level][to_comp][from_level][from_comp].
    pub rates: Vec<Vec<Vec<Vec<f32>>>>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ThermoBathParams {
    pub tissue_temperature_c: f32,
    pub bath_heat_capacity_j_per_k: f32,
    pub atp_chemical_potential_j: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EntropyProductionSnapshot {
    pub entropy_prod_rate_j_per_k_s: f32,
    pub heat_flux_to_tissue_w: f32,
    pub atp_work_rate_w: f32,
}

pub fn master_equation_step(
    grid: &EnergyStateGrid,
    trans: &TransitionRateMatrix,
    dt_s: f32,
) -> EnergyStateGrid {
    let l = grid.energy_levels_j.len();
    let c = grid.p[0].len();
    let mut dp = vec![vec![0.0f32; c]; l];

    for j in 0..l {
        for cj in 0..c {
            let p_jc = grid.p[j][cj];
            if p_jc <= 0.0 {
                continue;
            }
            for i in 0..l {
                for ci in 0..c {
                    let w = trans.rates[i][ci][j][cj];
                    let flow = w * p_jc;
                    dp[i][ci] += flow * dt_s;
                    dp[j][cj] -= flow * dt_s;
                }
            }
        }
    }

    let mut next = grid.clone();
    for i in 0..l {
        for k in 0..c {
            let v = next.p[i][k] + dp[i][k];
            next.p[i][k] = if v < 0.0 { 0.0 } else { v };
        }
    }
    next.normalize();
    next
}

pub fn entropy_production(
    grid: &EnergyStateGrid,
    trans: &TransitionRateMatrix,
    bath: &ThermoBathParams,
) -> EntropyProductionSnapshot {
    let l = grid.energy_levels_j.len();
    let c = grid.p[0].len();
    let t_k = bath.tissue_temperature_c + 273.15;
    let mut ep_rate = 0.0f32;
    let mut heat_flux = 0.0f32;
    let mut atp_work = 0.0f32;

    for j in 0..l {
        for cj in 0..c {
            let p_jc = grid.p[j][cj];
            if p_jc <= 0.0 {
                continue;
            }
            for i in 0..l {
                for ci in 0..c {
                    let w_f = trans.rates[i][ci][j][cj];
                    let w_b = trans.rates[j][cj][i][ci];
                    let p_i = grid.p[i][ci];
                    if w_f <= 0.0 || w_b <= 0.0 {
                        continue;
                    }
                    let j_ab = w_f * p_jc - w_b * p_i;
                    if j_ab.abs() < 1e-12 {
                        continue;
                    }
                    let a_ab = (w_f * p_jc / (w_b * p_i + 1e-18)).ln();
                    ep_rate += j_ab * a_ab;
                    let d_e = grid.energy_levels_j[i] - grid.energy_levels_j[j];
                    heat_flux += j_ab * d_e;
                    if d_e > 0.0 {
                        atp_work += j_ab * d_e;
                    }
                }
            }
        }
    }

    let s_rate = ep_rate.max(0.0);
    let q_rate_w = heat_flux;
    let atp_rate_w = atp_work;

    EntropyProductionSnapshot {
        entropy_prod_rate_j_per_k_s: s_rate,
        heat_flux_to_tissue_w: q_rate_w,
        atp_work_rate_w: atp_rate_w,
    }
}

/// Conservative bound: require entropy production below a threshold.
pub fn entropy_within_bound(
    snapshot: &EntropyProductionSnapshot,
    bound_j_per_k_s: f32,
) -> bool {
    snapshot.entropy_prod_rate_j_per_k_s <= bound_j_per_k_s + 1e-6
}

/// 93. Tri-culture neurotoxicity dose–response and neuro-RoH.

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TriCultureDoseResponsePoint {
    pub byproduct_concentration_m: f32,
    pub firing_rate_hz: f32,
    pub burst_rate_hz: f32,
    pub synchrony_index: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TriCultureDoseResponseCurve {
    pub sovereignty: HostSovereigntyBinding,
    pub baseline_firing_hz: f32,
    pub baseline_burst_hz: f32,
    pub baseline_synchrony: f32,
    pub points: Vec<TriCultureDoseResponsePoint>,
    pub ec10_m: f32,
    pub ec50_m: f32,
}

impl TriCultureDoseResponseCurve {
    pub fn validate(&self) -> Result<(), String> {
        if !self.sovereignty.is_primary_and_compliant() {
            return Err("tri-culture shard sovereignty mismatch".into());
        }
        if self.points.is_empty() {
            return Err("tri-culture curve requires points".into());
        }
        Ok(())
    }

    /// Neurotoxicity index in [0, 1], 0 safe, 1 severe.
    pub fn neurotoxicity_index(&self, conc_m: f32) -> f32 {
        let mut best = &self.points[0];
        let mut best_d = (conc_m - best.byproduct_concentration_m).abs();
        for p in &self.points {
            let d = (conc_m - p.byproduct_concentration_m).abs();
            if d < best_d {
                best = p;
                best_d = d;
            }
        }

        let fr_dev = ((best.firing_rate_hz - self.baseline_firing_hz)
            / self.baseline_firing_hz.max(1e-3))
            .abs();
        let br_dev = ((best.burst_rate_hz - self.baseline_burst_hz)
            / self.baseline_burst_hz.max(1e-3))
            .abs();
        let syn_dev =
            (best.synchrony_index - self.baseline_synchrony).abs();

        let raw = 0.5 * fr_dev + 0.3 * br_dev + 0.2 * syn_dev;
        let scaled = (raw / 1.0).clamp(0.0, 1.0);
        scaled
    }

    /// Map neurotoxicity into RoH-like corridor bands.
    pub fn neuro_roh_band(&self, conc_m: f32) -> NeuroRohBand {
        let idx = self.neurotoxicity_index(conc_m);
        if idx < 0.2 {
            NeuroRohBand::Allow
        } else if idx < 0.4 {
            NeuroRohBand::Brake
        } else {
            NeuroRohBand::Deny
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum NeuroRohBand {
    Allow,
    Brake,
    Deny,
}

/// 94. Riemannian manifold metadata for organ shapes and CCF registration.

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ShapeManifoldMetric {
    pub sovereignty: HostSovereigntyBinding,
    /// Right-invariant Sobolev-like metric parameters (symbolic).
    pub alpha: f32,
    pub beta: f32,
    pub gamma: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GeodesicRegistrationSummary {
    pub sovereignty: HostSovereigntyBinding,
    pub organ_id: String,
    /// Riemannian distance between template and patient shape.
    pub riemannian_distance: f32,
    /// Minimum Jacobian determinant across organ domain.
    pub jacobian_min: f32,
    /// Maximum Jacobian determinant across organ domain.
    pub jacobian_max: f32,
}

impl GeodesicRegistrationSummary {
    pub fn is_bijective(&self) -> bool {
        self.jacobian_min > 0.0 && self.jacobian_max.is_finite()
    }

    pub fn is_registration_stable(&self, distance_thresh: f32) -> bool {
        self.is_bijective() && self.riemannian_distance <= distance_thresh
    }
}

/// 95. Metabolic-cost corridor and Lifeforce ATP axis.

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MetabolicBaseline {
    pub sovereignty: HostSovereigntyBinding,
    pub vo2_rest_ml_per_min: f32,
    pub vo2_reserve_ml_per_min: f32,
    pub core_temp_rest_c: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MetabolicCorridor {
    pub sovereignty: HostSovereigntyBinding,
    /// Max fraction of VO2 reserve allowed during therapy (e.g., 0.4).
    pub max_vo2_fraction: f32,
    /// Max allowed core temperature increment (e.g., 1.0 C).
    pub max_core_temp_delta_c: f32,
    /// Conversion factor from VO2 increment to Lifeforce ATP token rate.
    pub atp_token_per_ml_o2: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MetabolicSnapshot {
    pub vo2_ml_per_min: f32,
    pub core_temp_c: f32,
    pub elapsed_s: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LifeforceAtpLedger {
    pub sovereignty: HostSovereigntyBinding,
    /// Current accumulated ATP tokens spent in this evolution window.
    pub tokens_spent: f32,
    /// Ceiling for tokens in this window.
    pub token_ceiling: f32,
}

impl MetabolicCorridor {
    pub fn validate(&self) -> Result<(), String> {
        if !self.sovereignty.is_primary_and_compliant() {
            return Err("MetabolicCorridor sovereignty mismatch".into());
        }
        if !(self.max_vo2_fraction > 0.0 && self.max_vo2_fraction <= 1.0) {
            return Err("max_vo2_fraction must be in (0,1]".into());
        }
        if self.max_core_temp_delta_c <= 0.0 {
            return Err("max_core_temp_delta_c must be positive".into());
        }
        if self.atp_token_per_ml_o2 <= 0.0 {
            return Err("atp_token_per_ml_o2 must be positive".into());
        }
        Ok(())
    }

    pub fn allowed_vo2_upper(
        &self,
        baseline: &MetabolicBaseline,
    ) -> f32 {
        baseline.vo2_rest_ml_per_min
            + self.max_vo2_fraction * baseline.vo2_reserve_ml_per_min
    }

    pub fn is_snapshot_within_corridor(
        &self,
        baseline: &MetabolicBaseline,
        snap: &MetabolicSnapshot,
    ) -> bool {
        let vo2_max = self.allowed_vo2_upper(baseline);
        let temp_delta = snap.core_temp_c - baseline.core_temp_rest_c;
        snap.vo2_ml_per_min <= vo2_max + 1e-3
            && temp_delta <= self.max_core_temp_delta_c + 1e-3
    }

    pub fn atp_tokens_for_snapshot(
        &self,
        baseline: &MetabolicBaseline,
        snap: &MetabolicSnapshot,
    ) -> f32 {
        let vo2_excess = (snap.vo2_ml_per_min
            - baseline.vo2_rest_ml_per_min)
            .max(0.0);
        let minutes = snap.elapsed_s / 60.0;
        vo2_excess * minutes * self.atp_token_per_ml_o2
    }
}

impl LifeforceAtpLedger {
    pub fn validate(&self) -> Result<(), String> {
        if !self.sovereignty.is_primary_and_compliant() {
            return Err("LifeforceAtpLedger sovereignty mismatch".into());
        }
        if self.token_ceiling <= 0.0 {
            return Err("token_ceiling must be positive".into());
        }
        Ok(())
    }

    pub fn can_spend(&self, additional: f32) -> bool {
        self.tokens_spent + additional <= self.token_ceiling + 1e-3
    }

    pub fn spend(&mut self, additional: f32) {
        self.tokens_spent += additional;
    }
}
