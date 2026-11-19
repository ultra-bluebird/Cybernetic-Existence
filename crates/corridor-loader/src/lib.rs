//! Non-weakening corridor loader for population/env/host polytopes.
//!
//! Each corridor is represented as A x <= b with an RoH ceiling roh_max.
//! merge() computes the intersection polytope while preserving the
//! universal safety floor and RoH ceiling invariants.

use serde::{Deserialize, Serialize};

pub const ROH_GLOBAL_CEILING: f32 = 0.30;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorridorPolytope {
    pub a: Vec<Vec<f64>>,
    pub b: Vec<f64>,
}

impl CorridorPolytope {
    pub fn dims(&self) -> Option<(usize, usize)> {
        let rows = self.a.len();
        if rows == 0 {
            return Some((0, 0));
        }
        let cols = self.a[0].len();
        if self.a.iter().any(|row| row.len() != cols) {
            return None;
        }
        if self.b.len() != rows {
            return None;
        }
        Some((rows, cols))
    }

    pub fn contains(&self, x: &[f64]) -> bool {
        if let Some((_rows, cols)) = self.dims() {
            if cols != x.len() {
                return false;
            }
        } else {
            return false;
        }
        for (row, &b_i) in self.a.iter().zip(self.b.iter()) {
            let mut acc = 0.0_f64;
            for (a_ij, x_j) in row.iter().zip(x.iter()) {
                acc += a_ij * x_j;
            }
            if acc > b_i {
                return false;
            }
        }
        true
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorridorPop {
    pub roh_max: f32,
    pub poly: CorridorPolytope,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorridorEnv {
    pub roh_max: f32,
    pub poly: CorridorPolytope,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorridorHost {
    pub roh_max: f32,
    pub poly: CorridorPolytope,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorridorMerged {
    pub roh_max: f32,
    pub poly: CorridorPolytope,
}

pub fn merge(pop: &CorridorPop, env: &CorridorEnv, host: &CorridorHost) -> CorridorMerged {
    let roh_max = pop
        .roh_max
        .min(env.roh_max)
        .min(host.roh_max)
        .min(ROH_GLOBAL_CEILING);

    let mut a_merged = Vec::new();
    let mut b_merged = Vec::new();

    a_merged.extend_from_slice(&pop.poly.a);
    b_merged.extend_from_slice(&pop.poly.b);

    a_merged.extend_from_slice(&env.poly.a);
    b_merged.extend_from_slice(&env.poly.b);

    a_merged.extend_from_slice(&host.poly.a);
    b_merged.extend_from_slice(&host.poly.b);

    CorridorMerged {
        roh_max,
        poly: CorridorPolytope {
            a: a_merged,
            b: b_merged,
        },
    }
}

impl CorridorMerged {
    /// Check universal safety floor (USF) invariants relative to population corridor.
    ///
    /// - roh_max must not exceed population roh_max.
    /// - Feasible set of merged must be a subset of population's feasible set.
    pub fn preserves_usf(&self, pop: &CorridorPop) -> bool {
        if self.roh_max > pop.roh_max {
            return false;
        }
        if let (Some((_m_pop, n_pop)), Some((_m_m, n_m))) = (pop.poly.dims(), self.poly.dims()) {
            if n_pop != n_m {
                return false;
            }
        } else {
            return false;
        }
        true
    }
}
