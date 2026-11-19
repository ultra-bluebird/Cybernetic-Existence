//! nanorobotics-neuroshield
//!
//! Neurorights-aware pain/fear shield LUT generator and clamp evaluation.
//!
//! This crate defines data structures and functions to map normalized pain
//! and fear indices onto an actuation clamp factor in [0.0, 1.0], suitable
//! for nanoswarm control paths. It is designed to be embedded in firmware,
//! hardware abstraction layers, or guard processes.

#![forbid(unsafe_code)]
#![deny(missing_docs)]

/// Represents the parameters of a per-host pain model.
///
/// The model is assumed to produce a normalized pain index p in [0.0, 1.0].
#[derive(Clone, Debug)]
pub struct PainModelParams {
    /// Lower nociceptive boundary; values at or below this are treated as "background pain".
    pub p_min: f32,
    /// Upper nociceptive boundary; values at or above this should force a hard clamp.
    pub p_max: f32,
    /// Slope scalar in the intermediate region (0.0 < alpha_p <= 1.0).
    pub alpha_p: f32,
}

/// Represents the parameters of a per-host fear model.
///
/// The model is assumed to produce a normalized fear index f in [0.0, 1.0].
#[derive(Clone, Debug)]
pub struct FearModelParams {
    /// Lower fear boundary; values at or below this are treated as "background fear".
    pub f_min: f32,
    /// Upper fear boundary; values at or above this should force a hard clamp.
    pub f_max: f32,
    /// Slope scalar in the intermediate region (0.0 < alpha_f <= 1.0).
    pub alpha_f: f32,
}

/// Configuration for LUT discretization.
#[derive(Clone, Debug)]
pub struct LutConfig {
    /// Number of discrete bins along each axis (pain, fear).
    /// A value like 64 yields a 64x64 LUT.
    pub bins: usize,
}

/// Two-dimensional clamp LUT for pain and fear indices.
///
/// The LUT stores clamp factors c in [0.0, 1.0] indexed by discrete pain/fear
/// bins. It is generated from continuous model parameters with monotonicity
/// properties enforced by construction.
#[derive(Clone, Debug)]
pub struct PainFearShieldLut {
    /// Number of bins along each axis.
    pub bins: usize,
    /// Row-major clamp factors of length bins * bins.
    ///
    /// Indexing convention:
    ///   idx = pain_idx * bins + fear_idx
    /// where pain_idx and fear_idx are in [0, bins).
    pub data: Vec<f32>,
}

impl PainFearShieldLut {
    /// Returns the clamp factor for a pair of normalized pain/fear indices.
    ///
    /// This performs nearest-neighbor lookup on the discretized grid.
    pub fn clamp(&self, pain: f32, fear: f32) -> f32 {
        let p = pain.clamp(0.0, 1.0);
        let f = fear.clamp(0.0, 1.0);
        let p_idx = (p * (self.bins.saturating_sub(1)) as f32).round() as usize;
        let f_idx = (f * (self.bins.saturating_sub(1)) as f32).round() as usize;
        let idx = p_idx.saturating_mul(self.bins).saturating_add(f_idx);
        // Safe because generation always fills data with bins*bins entries.
        self.data[idx]
    }

    /// Returns the total number of entries.
    pub fn len(&self) -> usize {
        self.data.len()
    }

    /// Returns true if there are no entries.
    pub fn is_empty(&self) -> bool {
        self.data.is_empty()
    }
}

/// Generates a pain/fear LUT from per-host model parameters.
///
/// The resulting LUT enforces the following properties by construction:
///   - Clamp factors are in [0.0, 1.0].
///   - Clamp is non-increasing in pain for fixed fear.
///   - Clamp is non-increasing in fear for fixed pain.
///   - Clamp is 1.0 at or below both minima.
///   - Clamp is 0.0 at or above either maximum.
pub fn build_pain_fear_lut(
    pain_params: &PainModelParams,
    fear_params: &FearModelParams,
    cfg: &LutConfig,
) -> PainFearShieldLut {
    assert!(cfg.bins >= 2, "bins must be >= 2");
    assert!(
        pain_params.p_min >= 0.0 && pain_params.p_min <= 1.0,
        "p_min must be in [0,1]"
    );
    assert!(
        pain_params.p_max >= 0.0 && pain_params.p_max <= 1.0,
        "p_max must be in [0,1]"
    );
    assert!(
        pain_params.p_min <= pain_params.p_max,
        "p_min must be <= p_max"
    );
    assert!(
        pain_params.alpha_p > 0.0 && pain_params.alpha_p <= 1.0,
        "alpha_p must be in (0,1]"
    );

    assert!(
        fear_params.f_min >= 0.0 && fear_params.f_min <= 1.0,
        "f_min must be in [0,1]"
    );
    assert!(
        fear_params.f_max >= 0.0 && fear_params.f_max <= 1.0,
        "f_max must be in [0,1]"
    );
    assert!(
        fear_params.f_min <= fear_params.f_max,
        "f_min must be <= f_max"
    );
    assert!(
        fear_params.alpha_f > 0.0 && fear_params.alpha_f <= 1.0,
        "alpha_f must be in (0,1]"
    );

    let n = cfg.bins;
    let mut data = Vec::with_capacity(n * n);

    for p_idx in 0..n {
        let p = p_idx as f32 / (n.saturating_sub(1)) as f32;
        for f_idx in 0..n {
            let f = f_idx as f32 / (n.saturating_sub(1)) as f32;

            let c_p = clamp_axis(
                p,
                pain_params.p_min,
                pain_params.p_max,
                pain_params.alpha_p,
            );
            let c_f = clamp_axis(
                f,
                fear_params.f_min,
                fear_params.f_max,
                fear_params.alpha_f,
            );

            let c = (c_p * c_f).clamp(0.0, 1.0);
            data.push(c);
        }
    }

    PainFearShieldLut { bins: n, data }
}

/// Helper for 1D clamp along a single axis.
///
/// Behavior:
///   value <= v_min    => 1.0
///   value >= v_max    => 0.0
///   between           => 1 - alpha * (value - v_min) / (v_max - v_min)
fn clamp_axis(value: f32, v_min: f32, v_max: f32, alpha: f32) -> f32 {
    if value <= v_min {
        1.0
    } else if value >= v_max {
        0.0
    } else if (v_max - v_min).abs() < f32::EPSILON {
        0.0
    } else {
        let t = (value - v_min) / (v_max - v_min);
        (1.0 - alpha * t).clamp(0.0, 1.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lut_basic_monotonicity() {
        let pain = PainModelParams {
            p_min: 0.2,
            p_max: 0.8,
            alpha_p: 1.0,
        };
        let fear = FearModelParams {
            f_min: 0.1,
            f_max: 0.9,
            alpha_f: 1.0,
        };
        let cfg = LutConfig { bins: 16 };
        let lut = build_pain_fear_lut(&pain, &fear, &cfg);

        assert_eq!(lut.bins, 16);
        assert_eq!(lut.len(), 16 * 16);

        // Check non-increasing in pain along a fixed fear index.
        let fixed_fear_idx = 8;
        let mut last_c = 1.0;
        for p_idx in 0..lut.bins {
            let idx = p_idx * lut.bins + fixed_fear_idx;
            let c = lut.data[idx];
            assert!(
                c <= last_c + 1e-6,
                "non-monotone in pain: p_idx={}, c={}, last_c={}",
                p_idx,
                c,
                last_c
            );
            last_c = c;
        }

        // Check non-increasing in fear along a fixed pain index.
        let fixed_pain_idx = 8;
        let mut last_c_f = 1.0;
        for f_idx in 0..lut.bins {
            let idx = fixed_pain_idx * lut.bins + f_idx;
            let c = lut.data[idx];
            assert!(
                c <= last_c_f + 1e-6,
                "non-monotone in fear: f_idx={}, c={}, last_c={}",
                f_idx,
                c,
                last_c_f
            );
            last_c_f = c;
        }
    }

    #[test]
    fn lut_respects_boundaries() {
        let pain = PainModelParams {
            p_min: 0.3,
            p_max: 0.7,
            alpha_p: 0.5,
        };
        let fear = FearModelParams {
            f_min: 0.2,
            f_max: 0.6,
            alpha_f: 0.5,
        };
        let cfg = LutConfig { bins: 8 };
        let lut = build_pain_fear_lut(&pain, &fear, &cfg);

        let c_low = lut.clamp(0.0, 0.0);
        assert!((c_low - 1.0).abs() < 1e-6);

        let c_high_pain = lut.clamp(1.0, 0.0);
        assert!(c_high_pain <= 1e-6);

        let c_high_fear = lut.clamp(0.0, 1.0);
        assert!(c_high_fear <= 1e-6);
    }
}
