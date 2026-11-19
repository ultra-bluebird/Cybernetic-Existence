#![feature(rust_2024_preview)]
#![forbid(unsafe_code)]
#![cfg_attr(not(feature = "std"), no_std)]

//! neuro-ad-guard
//!
//! Alzheimer network-health Lyapunov guard for BCI/EEG and nanoswarm-safe
//! evolution.
//!
//! This crate implements a simple scalar envelope
//!
//!   V_AD = a1 * (1 - CSI) + a2 * (1 - sigma) + a3 * xbar_tau
//!
//! with invariants:
//!   - 0 <= CSI <= 1
//!   - 0 <= sigma <= 1
//!   - 0 <= xbar_tau <= 1
//!   - RoH_step <= roh_max <= 0.30
//!   - V_AD_next <= V_AD_prev
//!   - V_AD_next <= v_ad_max
//!
//! Host binding and authority are enforced at the ALN layer via
//! neuro.ad.progression.v1 shards bound to:
//!   - hostdid        = OrganicCPU
//!   - bostromaddress = bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
//!   - authority      = ALN.MIGRATION.CYBERCORE_AUTHORITY.v1

extern crate alloc;

use alloc::string::String;
use serde::{Deserialize, Serialize};

/// Static constants for host binding (mirrors ALN shards).
pub const HOST_DID: &str = "OrganicCPU";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Invariants for the Alzheimer Lyapunov envelope.
///
/// These should be loaded from ALN neuro.ad.progression.v1 invariants
/// and treated as host-bound configuration.
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct AdInvariants {
    pub a1: f64,
    pub a2: f64,
    pub a3: f64,
    pub v_ad_max: f64,
    pub roh_max: f64,
    pub csi_min: f64,
    pub sigma_min: f64,
    pub xbar_max: f64,
}

/// Per-step Alzheimer telemetry sample aggregated from EEG/graph/diffusion.
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct AdSample {
    pub csi: f64,       // 0–1 microstate stability index
    pub sigma_sw: f64,  // 0–1 small-world index
    pub xbar_tau: f64,  // 0–1 normalized mean tau burden
    pub roh: f64,       // step-level RoH scalar
}

/// Compute V_AD(t) = a1*(1-CSI) + a2*(1-sigma) + a3*xbar_tau.
///
/// Caller is responsible for ensuring the inputs are already
/// clamped into [0,1] where appropriate.
pub fn compute_v_ad(inv: &AdInvariants, s: AdSample) -> f64 {
    let one_minus_csi = 1.0_f64 - s.csi;
    let one_minus_sigma = 1.0_f64 - s.sigma_sw;
    inv.a1 * one_minus_csi + inv.a2 * one_minus_sigma + inv.a3 * s.xbar_tau
}

/// Verdict for a proposed AD-relevant step (session, upgrade, or mission).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum AdSafetyVerdict {
    /// Step is allowed; v_ad_next is the accepted next Lyapunov value.
    Allow { v_ad_next: f64 },

    /// Denied because RoH exceeds roh_max.
    DenyRoH { v_ad_next: f64 },

    /// Denied because V_AD_next > V_AD_prev (Lyapunov non-decrease).
    DenyLyapunov { v_ad_prev: f64, v_ad_next: f64 },

    /// Denied because V_AD_next exceeds configured ceiling v_ad_max.
    DenyCeiling { v_ad_next: f64 },

    /// Denied because raw inputs violate configured domain bounds.
    DenyDomain { reason: String },
}

/// Validate raw sample fields against the configured domain bounds.
///
/// This ensures that CSI, sigma, and xbar_tau are inside [0,1] and
/// meet the configured minimum/maximum constraints.
fn validate_sample(inv: &AdInvariants, s: &mut AdSample) -> Result<(), String> {
    if s.csi < 0.0 || s.csi > 1.0 {
        return Err("CSI out of [0,1] range".into());
    }
    if s.sigma_sw < 0.0 || s.sigma_sw > 1.0 {
        return Err("sigma_sw out of [0,1] range".into());
    }
    if s.xbar_tau < 0.0 || s.xbar_tau > 1.0 {
        return Err("xbar_tau out of [0,1] range".into());
    }
    if s.roh < 0.0 {
        return Err("RoH negative".into());
    }

    if s.csi < inv.csi_min {
        return Err("CSI below configured minimum".into());
    }
    if s.sigma_sw < inv.sigma_min {
        return Err("sigma_sw below configured minimum".into());
    }
    if s.xbar_tau > inv.xbar_max {
        return Err("xbar_tau above configured maximum".into());
    }

    Ok(())
}

/// Enforce:
///   1) roh <= roh_max
///   2) V_AD_next <= v_ad_max
///   3) V_AD_next <= V_AD_prev  (monotone non-increase)
///
/// Returns an AdSafetyVerdict describing whether the step is allowed
/// and, if so, the next V_AD value to commit.
///
/// This function does not mutate any external state; callers are
/// responsible for storing v_ad_next into their progression records
/// when verdict is Allow.
pub fn check_ad_step(
    inv: &AdInvariants,
    prev_v_ad: f64,
    mut s: AdSample,
) -> AdSafetyVerdict {
    if let Err(reason) = validate_sample(inv, &mut s) {
        return AdSafetyVerdict::DenyDomain { reason };
    }

    if s.roh > inv.roh_max {
        let v_next = compute_v_ad(inv, s);
        return AdSafetyVerdict::DenyRoH { v_ad_next: v_next };
    }

    let v_next = compute_v_ad(inv, s);

    if v_next > inv.v_ad_max {
        return AdSafetyVerdict::DenyCeiling { v_ad_next: v_next };
    }

    if v_next > prev_v_ad {
        return AdSafetyVerdict::DenyLyapunov {
            v_ad_prev: prev_v_ad,
            v_ad_next: v_next,
        };
    }

    AdSafetyVerdict::Allow { v_ad_next: v_next }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn v_ad_monotone_under_improvement() {
        let inv = AdInvariants {
            a1: 1.0,
            a2: 1.0,
            a3: 1.0,
            v_ad_max: 10.0,
            roh_max: 0.30,
            csi_min: 0.5,
            sigma_min: 0.6,
            xbar_max: 1.0,
        };

        let prev = AdSample {
            csi: 0.6,
            sigma_sw: 0.7,
            xbar_tau: 0.6,
            roh: 0.10,
        };
        let prev_v = compute_v_ad(&inv, prev);

        // Improved CSI & sigma, reduced tau, same RoH.
        let s = AdSample {
            csi: 0.7,
            sigma_sw: 0.8,
            xbar_tau: 0.5,
            roh: 0.10,
        };

        let verdict = check_ad_step(&inv, prev_v, s);
        match verdict {
            AdSafetyVerdict::Allow { v_ad_next } => {
                assert!(v_ad_next <= prev_v);
            }
            _ => panic!("expected Allow verdict"),
        }
    }
}
