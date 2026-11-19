// Path: crates/nanorobotics-guards/src/hazard_kernel_dental.rs
// Edition: 2024
// License: MIT OR Apache-2.0

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use nanorobotics_core::telemetry_dental::{
    DentalCranialEnvelope, DentalCranialTelemetry, DentalHazardNorm, dental_hazard_score,
};
use nanorobotics_core::rohfromstatevectorbiohost::{StateVectorNBiohost, RoHWeights, computeroh};

/// Map DentalHazardNorm into an incremental adjustment on Tnorm and Motionnorm.
///
/// This is intentionally conservative: high dental hazard only pushes thermal/motion
/// axes upward; it never reduces them (monotone tightening).
pub fn fold_dental_into_statevector(
    sv: &StateVectorNBiohost,
    env: &DentalCranialEnvelope,
    tel: &DentalCranialTelemetry,
) -> Option<StateVectorNBiohost> {
    if !env.validate() {
        return None;
    }

    let norm = super::normalize_for_kernel(env, tel)?;
    let score = dental_hazard_score(env, tel).ok()? as f64;

    // Conservative mapping factors: 50% of thermal_norm into Tnorm,
    // 50% of duty_norm into Motionnorm.
    let delta_t = 0.5 * (norm.thermal_norm as f64);
    let delta_motion = 0.5 * (norm.duty_norm as f64);

    let mut tnorm = sv.tnorm + delta_t;
    let mut motionnorm = sv.motionnorm + delta_motion;

    if tnorm > 1.0 {
        tnorm = 1.0;
    }
    if motionnorm > 1.0 {
        motionnorm = 1.0;
    }

    Some(StateVectorNBiohost {
        tnorm,
        atpnorm: sv.atpnorm,
        psychnorm: sv.psychnorm,
        biofilmnorm: sv.biofilmnorm,
        motionnorm,
    })
}

/// Reuse the DentalHazardNorm normalization, but expose it locally for Kani-friendly use.
fn normalize_for_kernel(
    env: &DentalCranialEnvelope,
    tel: &DentalCranialTelemetry,
) -> Option<DentalHazardNorm> {
    super::super::nanorobotics_core::telemetry_dental::normalize_dental_hazard(env, tel).ok()
}

/// Compute extended RoH after folding dental hazard into the StateVectorNBiohost.
///
/// Caller is responsible for picking RoHWeights consistent with your global policy.
pub fn dental_extended_roh(
    sv: &StateVectorNBiohost,
    env: &DentalCranialEnvelope,
    tel: &DentalCranialTelemetry,
    w: RoHWeights,
) -> Option<f64> {
    let sv_ext = fold_dental_into_statevector(sv, env, tel)?;
    computeroh(sv_ext, w).ok()
}

#[cfg(test)]
mod tests {
    use super::*;
    use nanorobotics_core::telemetry_dental::DentalCranialTelemetry;
    use nanorobotics_core::rohfromstatevectorbiohost::{RoHWeights, StateVectorNBiohost};

    #[test]
    fn dental_mapping_monotone_tightening() {
        let env = DentalCranialEnvelope::default();
        let tel_low = DentalCranialTelemetry::new(37.05, 5.0, 0.1);
        let tel_high = DentalCranialTelemetry::new(37.5, 25.0, 0.8);

        let sv = StateVectorNBiohost {
            tnorm: 0.1,
            atpnorm: 0.9,
            psychnorm: 0.1,
            biofilmnorm: 0.1,
            motionnorm: 0.1,
        };

        let w = RoHWeights::default_conservative();

        let roh_low = dental_extended_roh(&sv, &env, &tel_low, w).unwrap();
        let roh_high = dental_extended_roh(&sv, &env, &tel_high, w).unwrap();

        // Higher dental hazard cannot reduce RoH.
        assert!(roh_high >= roh_low - 1e-6);
    }
}
