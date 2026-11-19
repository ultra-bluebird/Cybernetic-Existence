// destination-path: crates/cybernano-physio/src/corridor.rs
// edition: 2024
// rust-version: 1.85
#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

pub const ROH_CEILING: f32 = 0.30;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StateVector {
    pub sdnn_ms: f32,
    pub lfhf_ratio: f32,
    pub eeg_gamma_alpha: f32,
    pub temp_delta_c: f32,
    pub fatigue_index: f32,
    pub il6_pg_ml: f32,
}

impl StateVector {
    pub fn to_vec(&self) -> [f32; 6] {
        [
            self.sdnn_ms,
            self.lfhf_ratio,
            self.eeg_gamma_alpha,
            self.temp_delta_c,
            self.fatigue_index,
            self.il6_pg_ml,
        ]
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CorridorPolytope {
    pub a_matrix: Vec<f32>,
    pub b_vector: Vec<f32>,
    pub n_rows: usize,
    pub n_cols: usize,
}

impl CorridorPolytope {
    pub fn new(a_matrix: Vec<f32>, b_vector: Vec<f32>, n_cols: usize) -> Result<Self, String> {
        if n_cols == 0 {
            return Err("n_cols must be > 0".to_string());
        }
        let n_rows = b_vector.len();
        let expected = n_rows
            .checked_mul(n_cols)
            .ok_or_else(|| "matrix dimension overflow".to_string())?;
        if a_matrix.len() != expected {
            return Err(format!(
                "Matrix size mismatch: expected {}, got {}",
                expected,
                a_matrix.len()
            ));
        }
        Ok(Self {
            a_matrix,
            b_vector,
            n_rows,
            n_cols,
        })
    }

    pub fn contains(&self, x: &[f32]) -> Option<bool> {
        if x.len() != self.n_cols {
            return None;
        }
        for row in 0..self.n_rows {
            let mut ax = 0.0_f32;
            let base = row * self.n_cols;
            for col in 0..self.n_cols {
                ax += self.a_matrix[base + col] * x[col];
            }
            if ax > self.b_vector[row] {
                return Some(false);
            }
        }
        Some(true)
    }

    pub fn margin(&self, x: &[f32]) -> Option<f32> {
        if x.len() != self.n_cols {
            return None;
        }
        if self.n_rows == 0 {
            return Some(f32::INFINITY);
        }
        let mut min_margin = f32::INFINITY;
        for row in 0..self.n_rows {
            let mut ax = 0.0_f32;
            let base = row * self.n_cols;
            for col in 0..self.n_cols {
                ax += self.a_matrix[base + col] * x[col];
            }
            let m_k = self.b_vector[row] - ax;
            if m_k < min_margin {
                min_margin = m_k;
            }
        }
        Some(min_margin)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BiospatialCorridorPolytope {
    pub region_id: String,
    pub corridor: CorridorPolytope,
    pub roh_slice_max: f32,
    pub safe_margin: f32,
    pub evidence_tags: [String; 10],
}

impl BiospatialCorridorPolytope {
    pub fn roh_region_from_state(&self, state: &StateVector) -> Option<f32> {
        let x = state.to_vec();
        self.roh_region(&x)
    }

    pub fn roh_region(&self, x: &[f32]) -> Option<f32> {
        if self.roh_slice_max <= 0.0 {
            return Some(0.0);
        }
        if self.safe_margin < 0.0 {
            return None;
        }
        let margin_raw = self.corridor.margin(x)?;
        if !margin_raw.is_finite() {
            return Some(self.roh_slice_max);
        }
        if self.safe_margin == 0.0 {
            return Some(self.roh_slice_max);
        }
        let margin_clamped = margin_raw.max(0.0).min(self.safe_margin);
        let ratio = margin_clamped / self.safe_margin;
        let roh = self.roh_slice_max * (1.0 - ratio);
        let roh_clamped = roh.max(0.0).min(self.roh_slice_max);
        Some(roh_clamped)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn corridor_unit_box(dim: usize, lower: f32, upper: f32) -> CorridorPolytope {
        let mut a = Vec::new();
        let mut b = Vec::new();
        for j in 0..dim {
            let mut row = vec![0.0_f32; dim];
            row[j] = 1.0;
            a.extend_from_slice(&row);
            b.push(upper);
        }
        for j in 0..dim {
            let mut row = vec![0.0_f32; dim];
            row[j] = -1.0;
            a.extend_from_slice(&row);
            b.push(-lower);
        }
        CorridorPolytope::new(a, b, dim).unwrap()
    }

    #[test]
    fn margin_inside_box_positive() {
        let c = corridor_unit_box(2, -1.0, 1.0);
        let x = [0.0_f32, 0.0_f32];
        let m = c.margin(&x).unwrap();
        assert!(m > 0.0);
    }

    #[test]
    fn roh_region_bounded_by_slice_max() {
        let c = corridor_unit_box(6, -1.0, 1.0);
        let bp = BiospatialCorridorPolytope {
            region_id: "cns".to_string(),
            corridor: c,
            roh_slice_max: 0.15,
            safe_margin: 1.0,
            evidence_tags: Default::default(),
        };
        let state = StateVector {
            sdnn_ms: 0.0,
            lfhf_ratio: 0.0,
            eeg_gamma_alpha: 0.0,
            temp_delta_c: 0.0,
            fatigue_index: 0.0,
            il6_pg_ml: 0.0,
        };
        let roh = bp.roh_region_from_state(&state).unwrap();
        assert!(roh >= 0.0);
        assert!(roh <= bp.roh_slice_max + f32::EPSILON);
    }

    #[test]
    fn roh_region_zero_deep_inside() {
        let c = corridor_unit_box(1, -10.0, 10.0);
        let bp = BiospatialCorridorPolytope {
            region_id: "cardiac".to_string(),
            corridor: c,
            roh_slice_max: 0.2,
            safe_margin: 1.0,
            evidence_tags: Default::default(),
        };
        let x = [0.0_f32];
        let roh = bp.roh_region(&x).unwrap();
        assert!(roh >= 0.0);
        assert!(roh <= bp.roh_slice_max + f32::EPSILON);
    }

    #[test]
    fn roh_region_conservative_when_safe_margin_zero() {
        let c = corridor_unit_box(1, -1.0, 1.0);
        let bp = BiospatialCorridorPolytope {
            region_id: "renal".to_string(),
            corridor: c,
            roh_slice_max: 0.1,
            safe_margin: 0.0,
            evidence_tags: Default::default(),
        };
        let x = [0.0_f32];
        let roh = bp.roh_region(&x).unwrap();
        assert!((roh - bp.roh_slice_max).abs() <= f32::EPSILON);
    }
}
