// crates/risk-of-harm-kernel/src/polytope.rs
#![forbid(unsafe_code)]
#![no_std]

use core::cmp::min;

/// Minimal BioState projection used for the polytope gate.
/// All fields are host-local, pre-normalized where appropriate.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct BioState {
    /// HRV SDNN in milliseconds.
    pub hrv_sdnn_ms: f32,
    /// EEG theta/beta ratio (dimensionless).
    pub eeg_theta_beta_ratio: f32,
    /// Core temperature delta from baseline (Celsius).
    pub core_temp_delta_c: f32,
    /// Interleukin-6 in pg/mL.
    pub il6_pg_ml: f32,
    /// Fatigue index in [0, 1].
    pub fatigue_index: f32,
    /// Ecoimpact score in [0, 1], higher is better.
    pub ecoimpact_score: f32,
}

/// Corridor polytope Ax <= b with fixed dimensions (6 axes, max M constraints).
///
/// All storage is bounded at compile time; there is no dynamic allocation.
#[repr(C)]
pub struct CorridorPolytope<const M: usize> {
    /// Row-major A matrix with shape (num_constraints, 6).
    a: [[f32; 6]; M],
    /// Right-hand side vector b.
    b: [f32; M],
    /// Actual number of active constraints (<= M).
    num_constraints: usize,
}

impl<const M: usize> CorridorPolytope<M> {
    /// Creates a new, empty polytope (no constraints).
    pub const fn empty() -> Self {
        Self {
            a: [[0.0; 6]; M],
            b: [0.0; M],
            num_constraints: 0,
        }
    }

    /// Adds a new constraint row a_row^T x <= b_val.
    ///
    /// If the buffer is full, the new constraint is ignored.
    pub fn push_constraint(&mut self, a_row: [f32; 6], b_val: f32) {
        if self.num_constraints < M {
            let idx = self.num_constraints;
            self.a[idx] = a_row;
            self.b[idx] = b_val;
            self.num_constraints += 1;
        }
    }

    /// Returns true iff state is inside the corridor: Ax <= b for all rows.
    pub fn contains(&self, state: &BioState) -> bool {
        let x = self.state_vector(state);
        for i in 0..self.num_constraints {
            let mut dot = 0.0_f32;
            let row = &self.a[i];
            dot += row[0] * x[0];
            dot += row[1] * x[1];
            dot += row[2] * x[2];
            dot += row[3] * x[3];
            dot += row[4] * x[4];
            dot += row[5] * x[5];

            if dot > self.b[i] {
                return false;
            }
        }
        true
    }

    /// Returns the minimum signed margin to all constraint boundaries.
    ///
    /// margin = min_i (b_i - a_i^T x).
    /// Positive => inside corridor; negative => outside (violation extent).
    pub fn distance_to_boundary(&self, state: &BioState) -> f32 {
        if self.num_constraints == 0 {
            return core::f32::INFINITY;
        }
        let x = self.state_vector(state);
        let mut min_margin = core::f32::INFINITY;
        for i in 0..self.num_constraints {
            let mut dot = 0.0_f32;
            let row = &self.a[i];
            dot += row[0] * x[0];
            dot += row[1] * x[1];
            dot += row[2] * x[2];
            dot += row[3] * x[3];
            dot += row[4] * x[4];
            dot += row[5] * x[5];
            let margin = self.b[i] - dot;
            if margin < min_margin {
                min_margin = margin;
            }
        }
        min_margin
    }

    #[inline]
    fn state_vector(&self, state: &BioState) -> [f32; 6] {
        [
            state.hrv_sdnn_ms,
            state.eeg_theta_beta_ratio,
            state.core_temp_delta_c,
            state.il6_pg_ml,
            state.fatigue_index,
            state.ecoimpact_score,
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn simple_box_corridor_contains_and_distance() {
        // Example: 6D box with simple bounds.
        //  x0 >= 40  => -x0 <= -40
        //  x0 <= 100 =>  x0 <= 100
        let mut poly: CorridorPolytope<4> = CorridorPolytope::empty();
        poly.push_constraint([-1.0, 0.0, 0.0, 0.0, 0.0, 0.0], -40.0);
        poly.push_constraint([ 1.0, 0.0, 0.0, 0.0, 0.0, 0.0], 100.0);

        let inside = BioState {
            hrv_sdnn_ms: 60.0,
            eeg_theta_beta_ratio: 0.7,
            core_temp_delta_c: 0.1,
            il6_pg_ml: 1.5,
            fatigue_index: 0.3,
            ecoimpact_score: 0.8,
        };
        assert!(poly.contains(&inside));
        assert!(poly.distance_to_boundary(&inside) > 0.0);

        let outside = BioState { hrv_sdnn_ms: 20.0, ..inside };
        assert!(!poly.contains(&outside));
        assert!(poly.distance_to_boundary(&outside) < 0.0);
    }
}
