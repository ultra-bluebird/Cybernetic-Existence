// mk-bluebird/nanorobotics/crates/nanorobotics-cbf-guards/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]
#![feature(rust_2024_preview)]

use serde::{Deserialize, Serialize};

use cybercore_category::{
    CorridorMonoidalCorridor,
    CorridorRiskBundle,
    CorridorControlProposal,
    SovereigntyInvariants,
};

use sacrifice_zone_envelope::{HazardMetrics, SacrificeZoneModel};

/// Host-global migration authority marker.
pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCOREAUTHORITY.v1";

/// Primary host DID and Bostrom address bindings.
pub const HOST_DID: &str = "OrganicCPU";
pub const BOSTROM_ADDRESS: &str =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Merge Sacrifice Zone material risk into the corridor materialrisk axis.
///
/// Call this before constructing CorridorRiskBundle or evaluating BarrierGuard,
/// so the 7D axes include Sacrifice Zone risk.
pub fn inject_sacrifice_zone_materialrisk(
    corridor: &mut CorridorMonoidalCorridor,
    sz_model: &SacrificeZoneModel,
) {
    let sz_risk = sz_model.metrics.materialrisk_contribution();

    let axes = corridor.axes7();
    let mut axes_new = axes;
    axes_new[6] = axes_new[6].max(sz_risk);

    // Update the unified state materialrisk axis if available.
    // This assumes UnifiedMonoidalCorridor exposes safety axes with a materialrisk field.
    corridor.unified.state.safety_axes.materialrisk = axes_new[6];
}

/// Result of a barrier guard evaluation at one control step.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub enum BarrierVerdict {
    Allow {
        u_filtered: Vec<f32>,
    },
    Brake {
        u_filtered: Vec<f32>,
    },
    Deny,
}

/// Trait for actuation-time barrier guards that fuse FP/OT/Bayes outputs and
/// enforce CBF-style inequalities and RoH ceilings.
pub trait BarrierGuard {
    fn evaluate_step(
        &self,
        inv: &SovereigntyInvariants,
        corridor: &CorridorMonoidalCorridor,
        risk_bundle: &CorridorRiskBundle,
    ) -> BarrierVerdict;
}

/// Conservative scalar barrier guard.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ScalarBarrierGuard {
    pub kappa: f32,
    pub p_safe_min: f32,
    pub ot_cost_max: f32,
}

impl ScalarBarrierGuard {
    fn fused_axes(
        &self,
        _corridor: &CorridorMonoidalCorridor,
        risk_bundle: &CorridorRiskBundle,
    ) -> [f32; 7] {
        let axes_fp = risk_bundle.fp.axes_fp;
        let axes_ot = risk_bundle.ot.axes_ot;

        if risk_bundle.ot.cost <= self.ot_cost_max {
            let mut fused = [0.0_f32; 7];
            for i in 0..7 {
                fused[i] = axes_fp[i].max(axes_ot[i]);
            }
            fused
        } else {
            axes_fp
        }
    }

    fn barrier_value(
        &self,
        corridor: &CorridorMonoidalCorridor,
        axes: &[f32; 7],
    ) -> f32 {
        corridor.polytope7d.min_margin(axes)
    }

    fn zero_control_like(proposal: &CorridorControlProposal) -> Vec<f32> {
        vec![0.0_f32; proposal.u_bci.len()]
    }

    fn averaged_control(proposal: &CorridorControlProposal) -> Vec<f32> {
        let mut u_filtered = Vec::with_capacity(proposal.u_bci.len());
        for (u_bci_i, u_nano_i) in proposal
            .u_bci
            .iter()
            .zip(proposal.u_nano.iter())
        {
            let u_raw = 0.5_f32 * (u_bci_i + u_nano_i);
            u_filtered.push(u_raw);
        }
        u_filtered
    }

    fn scaled_control(proposal: &CorridorControlProposal, scale: f32) -> Vec<f32> {
        let mut u_filtered = Vec::with_capacity(proposal.u_bci.len());
        for (u_bci_i, u_nano_i) in proposal
            .u_bci
            .iter()
            .zip(proposal.u_nano.iter())
        {
            let u_raw = 0.5_f32 * (u_bci_i + u_nano_i);
            u_filtered.push(scale * u_raw);
        }
        u_filtered
    }
}

impl BarrierGuard for ScalarBarrierGuard {
    fn evaluate_step(
        &self,
        inv: &SovereigntyInvariants,
        corridor: &CorridorMonoidalCorridor,
        risk_bundle: &CorridorRiskBundle,
    ) -> BarrierVerdict {
        if risk_bundle.fp.roh_fp > inv.roh_ceiling {
            return BarrierVerdict::Deny;
        }

        if risk_bundle.bayes.p_safe < self.p_safe_min {
            return BarrierVerdict::Deny;
        }

        let axes_current = corridor.axes7();
        let h_current = self.barrier_value(corridor, &axes_current);

        let axes_fused = self.fused_axes(corridor, risk_bundle);
        let h_next = self.barrier_value(corridor, &axes_fused);

        if h_current <= 0.0 {
            if h_next < h_current {
                return BarrierVerdict::Deny;
            }
            return BarrierVerdict::Brake {
                u_filtered: Self::zero_control_like(&risk_bundle.proposal),
            };
        }

        let required = self.kappa * h_current;

        if h_next < required {
            let scale = (h_next / required).clamp(0.0, 1.0);
            let u_filtered = Self::scaled_control(&risk_bundle.proposal, scale);
            BarrierVerdict::Brake { u_filtered }
        } else {
            let u_filtered = Self::averaged_control(&risk_bundle.proposal);
            BarrierVerdict::Allow { u_filtered }
        }
    }
}
