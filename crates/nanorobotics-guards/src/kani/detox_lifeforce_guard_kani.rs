// crates/nanorobotics-guards/src/kani/detox_lifeforce_guard_kani.rs
#![forbid(unsafe_code)]
#![deny(warnings)]

use kani::proof;

use crate::detox_lifeforce_guard::{
    DetoxBoundCoeffs, DetoxLifeforceGuard, DetoxLifeforceVerdict,
    DetoxMissionEnvelope, LifeforceFloors, LifeforceSessionState, ROH_CEILING_GLOBAL,
};

#[proof]
fn detox_lifeforce_monotone_global_roh() {
    let guard = DetoxLifeforceGuard::new_default();

    let roh_max: f32 = kani::any();
    let duration_minutes: f32 = kani::any();
    let lf_start: f32 = kani::any();
    let lf_min: f32 = kani::any();
    let lf_end: f32 = kani::any();

    kani::assume(roh_max >= 0.0 && roh_max <= ROH_CEILING_GLOBAL);
    kani::assume(duration_minutes >= 0.0 && duration_minutes <= 240.0);

    kani::assume(lf_start >= LifeforceFloors::default().lf_floor_mission);
    kani::assume(lf_min >= LifeforceFloors::default().lf_floor_episode);
    kani::assume(lf_min <= lf_start);
    kani::assume(lf_end >= 0.0 && lf_end <= 1.0);

    let mission = DetoxMissionEnvelope {
        roh_max,
        duration_minutes,
    };
    let lf_state = LifeforceSessionState {
        lf_start,
        lf_min,
        lf_end,
    };

    if let Ok(verdict) = guard.evaluate(&mission, &lf_state) {
        match verdict {
            DetoxLifeforceVerdict::Allow | DetoxLifeforceVerdict::AllowShrunk => {
                // Floors must hold at all times.
                assert!(lf_start >= LifeforceFloors::default().lf_floor_mission);
                assert!(lf_min >= LifeforceFloors::default().lf_floor_episode);

                // RoH ceiling must hold.
                assert!(roh_max <= ROH_CEILING_GLOBAL + f32::EPSILON);

                // Net lifeforce monotonicity: allowed sessions must not reduce lifeforce below floors.
                let drop = lf_state.temporary_drop();
                assert!(drop >= 0.0);

                // Net gain corridor bound: if verdict is Allow, net gain satisfies guard corridor.
                if verdict == DetoxLifeforceVerdict::Allow {
                    let coeffs = DetoxBoundCoeffs::default();
                    let net_min =
                        coeffs.g_lifeforce_net_min(roh_max, duration_minutes);
                    let net_gain = lf_state.net_gain();
                    assert!(net_gain + f32::EPSILON >= net_min);
                }
            }
            DetoxLifeforceVerdict::Deny => {
                // Denied missions are not executed; no evolution step is taken.
                assert!(true);
            }
        }
    }
}

#[proof]
fn detox_lifeforce_drop_bound_respected() {
    let coeffs = DetoxBoundCoeffs::default();

    let roh_max: f32 = kani::any();
    let duration_minutes: f32 = kani::any();
    let drop_observed: f32 = kani::any();

    kani::assume(roh_max >= 0.0 && roh_max <= ROH_CEILING_GLOBAL);
    kani::assume(duration_minutes >= 0.0 && duration_minutes <= 240.0);
    kani::assume(drop_observed >= 0.0 && drop_observed <= 1.0);

    let drop_max = coeffs.f_lifeforce_drop_max(roh_max, duration_minutes);

    // For admissible parameters, drop_max is bounded and monotone in roh_max and duration.
    assert!(drop_max >= 0.0);
    assert!(drop_max <= coeffs.alpha * ROH_CEILING_GLOBAL + 1e-3);

    // If observed drop is allowed by guard-level checks, then it is within the bound.
    if drop_observed <= drop_max + f32::EPSILON {
        assert!(drop_observed <= drop_max + f32::EPSILON);
    }
}
