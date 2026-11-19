#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";
pub const HOSTDID: &str = "OrganicCPU";
pub const BOSTROM_ADDRESS: &str =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Parameters of an oxygen corridor for a single microvascular region.
/// Numeric ranges are enforced at ALN level; here we assume already-validated input.
#[derive(Clone, Debug)]
pub struct OxygenCorridorParams {
    pub corridor_id: String,
    pub organ: String,
    pub region_id: String,

    pub pO2_min_mmHg: f32,
    pub pO2_ref_mmHg: f32,
    pub pO2_max_mmHg: f32,

    pub rho_max_frac: f32,

    pub alpha_density_o2: f32,
    pub beta_deficit_weight: f32,
    pub kappa_feedback_gain: f32,

    pub roh_slice_o2_max: f32,

    pub safemargin_mmHg: f32,
}

/// Current O2 and density state of a region.
#[derive(Clone, Debug)]
pub struct OxygenState {
    pub pO2_mmHg: f32,
    pub rho_frac: f32,
}

impl OxygenCorridorParams {
    /// Normalized deficit d_norm ∈ [0, 1] based on pO2_ref and pO2_min.
    /// If pO2 is above pO2_ref, deficit is zero.
    pub fn deficit_norm(&self, state: &OxygenState) -> f32 {
        let span = (self.pO2_ref_mmHg - self.pO2_min_mmHg).max(1.0);
        let raw_deficit = (self.pO2_ref_mmHg - state.pO2_mmHg).max(0.0);
        let d_norm = raw_deficit / span;
        d_norm.clamp(0.0, 1.0)
    }

    /// O2 RoH slice contribution R_O2 ∈ [0, roh_slice_o2_max], monotone in deficit_norm.
    pub fn roh_slice_o2(&self, state: &OxygenState) -> f32 {
        let d_norm = self.deficit_norm(state);
        let roh = self.roh_slice_o2_max * d_norm;
        roh.clamp(0.0, self.roh_slice_o2_max)
    }

    /// Check whether current state respects the density–O2 corridor constraints:
    /// 1) density ≤ rho_max_frac
    /// 2) pO2 ≥ pO2_min_mmHg
    /// 3) alpha * rho - pO2 ≤ b_corridor, with b_corridor derived from safemargin.
    pub fn corridor_ok(&self, state: &OxygenState) -> bool {
        let rho_ok = state.rho_frac <= self.rho_max_frac;
        let o2_ok = state.pO2_mmHg >= self.pO2_min_mmHg;
        let b_corridor = self.pO2_min_mmHg + self.safemargin_mmHg;
        let coupled = self.alpha_density_o2 * state.rho_frac - state.pO2_mmHg;
        let coupling_ok = coupled <= b_corridor;
        rho_ok && o2_ok && coupling_ok
    }

    /// FP drift feedback component from O2 deficit gradient ∇d (units: mmHg⁻¹ per coordinate).
    /// u_O2 = -kappa * beta * ∇d, returned as a 3D vector.
    pub fn fp_drift_feedback(&self, grad_deficit: [f32; 3]) -> [f32; 3] {
        let gain = self.kappa_feedback_gain * self.beta_deficit_weight;
        [
            -gain * grad_deficit[0],
            -gain * grad_deficit[1],
            -gain * grad_deficit[2],
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roh_slice_o2_monotone_simple() {
        let params = OxygenCorridorParams {
            corridor_id: "test".into(),
            organ: "Heart".into(),
            region_id: "region-1".into(),
            pO2_min_mmHg: 20.0,
            pO2_ref_mmHg: 40.0,
            pO2_max_mmHg: 80.0,
            rho_max_frac: 0.5,
            alpha_density_o2: 1.0,
            beta_deficit_weight: 1.0,
            kappa_feedback_gain: 1.0,
            roh_slice_o2_max: 0.30,
            safemargin_mmHg: 5.0,
        };

        let s_high = OxygenState {
            pO2_mmHg: 50.0,
            rho_frac: 0.1,
        };
        let s_ref = OxygenState {
            pO2_mmHg: 40.0,
            rho_frac: 0.1,
        };
        let s_low = OxygenState {
            pO2_mmHg: 20.0,
            rho_frac: 0.1,
        };

        let r_high = params.roh_slice_o2(&s_high);
        let r_ref = params.roh_slice_o2(&s_ref);
        let r_low = params.roh_slice_o2(&s_low);

        assert!(r_high <= r_ref + 1e-6);
        assert!(r_ref <= r_low + 1e-6);
        assert!(r_low <= params.roh_slice_o2_max + 1e-6);
    }

    #[test]
    fn corridor_ok_respects_bounds() {
        let params = OxygenCorridorParams {
            corridor_id: "test".into(),
            organ: "Brain".into(),
            region_id: "region-2".into(),
            pO2_min_mmHg: 25.0,
            pO2_ref_mmHg: 40.0,
            pO2_max_mmHg: 80.0,
            rho_max_frac: 0.4,
            alpha_density_o2: 0.5,
            beta_deficit_weight: 1.0,
            kappa_feedback_gain: 1.0,
            roh_slice_o2_max: 0.30,
            safemargin_mmHg: 10.0,
        };

        let safe_state = OxygenState {
            pO2_mmHg: 50.0,
            rho_frac: 0.2,
        };

        assert!(params.corridor_ok(&safe_state));

        let hypoxic_state = OxygenState {
            pO2_mmHg: 10.0,
            rho_frac: 0.2,
        };

        assert!(!params.corridor_ok(&hypoxic_state));

        let dense_state = OxygenState {
            pO2_mmHg: 50.0,
            rho_frac: 0.8,
        };

        assert!(!params.corridor_ok(&dense_state));
    }
}

#[cfg(feature = "kani")]
mod kani_harnesses {
    use super::*;
    use kani::any;
    use kani::{assume, proof};

    /// Harness: O2 RoH slice is bounded in [0, roh_slice_o2_max] and monotone in deficit_norm.
    #[proof]
    fn kani_oxygen_roh_monotone_and_bounded() {
        let params = OxygenCorridorParams {
            corridor_id: "kani".into(),
            organ: "Lung".into(),
            region_id: "region-kani".into(),
            pO2_min_mmHg: 20.0,
            pO2_ref_mmHg: 60.0,
            pO2_max_mmHg: 120.0,
            rho_max_frac: 0.5,
            alpha_density_o2: 1.0,
            beta_deficit_weight: 1.0,
            kappa_feedback_gain: 1.0,
            roh_slice_o2_max: 0.30,
            safemargin_mmHg: 5.0,
        };

        let mut s1 = OxygenState {
            pO2_mmHg: any(),
            rho_frac: any(),
        };
        let mut s2 = OxygenState {
            pO2_mmHg: any(),
            rho_frac: any(),
        };

        assume(s1.pO2_mmHg.is_finite());
        assume(s2.pO2_mmHg.is_finite());
        assume(s1.rho_frac.is_finite());
        assume(s2.rho_frac.is_finite());

        // Clamp pO2 to a reasonable physiological range.
        s1.pO2_mmHg = s1.pO2_mmHg.clamp(0.0, 200.0);
        s2.pO2_mmHg = s2.pO2_mmHg.clamp(0.0, 200.0);

        let r1 = params.roh_slice_o2(&s1);
        let r2 = params.roh_slice_o2(&s2);

        assert!(r1 >= 0.0);
        assert!(r2 >= 0.0);
        assert!(r1 <= params.roh_slice_o2_max + 1e-6);
        assert!(r2 <= params.roh_slice_o2_max + 1e-6);

        let d1 = params.deficit_norm(&s1);
        let d2 = params.deficit_norm(&s2);

        if d2 >= d1 {
            assert!(r2 + 1e-6 >= r1);
        }
    }

    /// Harness: corridor_ok implies density and O2 respect shard ceilings and floor.
    #[proof]
    fn kani_oxygen_corridor_safe() {
        let params = OxygenCorridorParams {
            corridor_id: "kani2".into(),
            organ: "Heart".into(),
            region_id: "region-kani2".into(),
            pO2_min_mmHg: 30.0,
            pO2_ref_mmHg: 60.0,
            pO2_max_mmHg: 120.0,
            rho_max_frac: 0.4,
            alpha_density_o2: 1.0,
            beta_deficit_weight: 1.0,
            kappa_feedback_gain: 1.0,
            roh_slice_o2_max: 0.30,
            safemargin_mmHg: 10.0,
        };

        let mut state = OxygenState {
            pO2_mmHg: any(),
            rho_frac: any(),
        };

        assume(state.pO2_mmHg.is_finite());
        assume(state.rho_frac.is_finite());

        state.pO2_mmHg = state.pO2_mmHg.clamp(0.0, 200.0);
        state.rho_frac = state.rho_frac.clamp(0.0, 1.0);

        if params.corridor_ok(&state) {
            assert!(state.pO2_mmHg >= params.pO2_min_mmHg - 1e-6);
            assert!(state.rho_frac <= params.rho_max_frac + 1e-6);

            let b_corridor = params.pO2_min_mmHg + params.safemargin_mmHg;
            let coupled = params.alpha_density_o2 * state.rho_frac - state.pO2_mmHg;
            assert!(coupled <= b_corridor + 1e-6);
        }
    }
}
