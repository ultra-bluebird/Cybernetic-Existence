// filename: crates/daily-evolution-loop-core/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]
#![feature(rust2024_preview)]

use serde::{Deserialize, Serialize};

use nanorobotics_cbf_guards::{
    BarrierGuard,
    BarrierVerdict,
    ScalarBarrierGuard,
};
use cybercore_category::{
    CorridorMonoidalCorridor,
    CorridorRiskBundle,
    SovereigntyInvariants,
};
use cybercore_rights::{
    RightsShard,
};
use cybercore_thresholds::{
    AdaptiveCorridorThresholds,
};
use cybercore_vampiric_envelope::{
    VampiricHealthcareEnvelope,
};
use cybercore_sovereignty::{
    HostSovereigntyBinding,
};

/// Global non-degradation invariants shared with Kani harnesses.
/// These are typically backed by ALN shards and act as the schema-level
/// contract that evolution windows must respect.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct NonDegradationInvariants {
    pub sovereignty: HostSovereigntyBinding,
    pub roh_ceiling_hard: f32,
    pub capability_floor_hard: f32,
    pub rights_minima: RightsShard,
    pub float_tol: f32,
}

/// Core evolution-window state. This struct is deliberately shallow and composed
/// of already-verified primitives from other crates.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct EvolutionWindowState {
    pub sovereignty: HostSovereigntyBinding,
    pub roh_max_observed: f32,
    pub roh_ceiling: f32,
    pub vampiric_envelope: VampiricHealthcareEnvelope,
    pub corridor_thresholds: AdaptiveCorridorThresholds,
    pub responsibility_scalar: f32,
    pub capability_floor: f32,
    pub rights_state: RightsShard,
    pub has_host_authorized_downgrade: bool,
}

impl EvolutionWindowState {
    pub fn satisfies_invariants(&self, inv: &NonDegradationInvariants) -> bool {
        if !self.sovereignty.is_primary_and_compliant() {
            return false;
        }
        if self.roh_ceiling > inv.roh_ceiling_hard + inv.float_tol {
            return false;
        }
        if self.roh_max_observed > inv.roh_ceiling_hard + inv.float_tol {
            return false;
        }
        if self.capability_floor + inv.float_tol < inv.capability_floor_hard {
            return false;
        }
        if !self.rights_state.dominates(&inv.rights_minima) {
            return false;
        }
        if !self.vampiric_envelope.dominates_or_equal(&VampiricHealthcareEnvelope::usf_floor()) {
            return false;
        }
        true
    }
}

/// Per-row manifest entry. Each row encodes a candidate upgrade plus its
/// associated deltas and evidence. Guard kernels decide whether it is
/// admissible given the current state and telemetry.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ManifestUpgradeGift {
    pub sovereignty: HostSovereigntyBinding,
    pub roh_before: f32,
    pub roh_after: f32,
    pub rdelta: f32,
    pub eco_delta: f32,
    pub blood_delta: f32,
    pub protein_delta: f32,
    pub lifeforce_delta: f32,
    pub capability_delta: f32,
    pub rights_delta: RightsShard,
    pub host_authorized_downgrade: bool,
    pub corridor_risk_bundle: CorridorRiskBundle,
}

impl ManifestUpgradeGift {
    /// Sanitize fields for Kani harnesses; in production, syntactic and
    /// semantic checks should be done by parsing from ALN manifests.
    pub fn sanitize_for_kani(&mut self) {
        if self.roh_before.is_nan() {
            self.roh_before = 0.0;
        }
        if self.roh_after.is_nan() {
            self.roh_after = self.roh_before;
        }
    }
}

/// Local telemetry and guard wiring that are not explicitly encoded in the
/// manifest rows. In a real system, these would be loaded from ALN telemetry
/// shards and Phoenix twin states.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct EvolutionGuardContext {
    pub sovereignty_invariants: SovereigntyInvariants,
    pub corridor: CorridorMonoidalCorridor,
    pub barrier_guard: ScalarBarrierGuard,
}

/// Top-level evolution window driver: given a starting state, a batch of
/// manifest rows, and the non-degradation invariants, produce the next state.
/// This function is the single entry point used by Kani and by the runtime
/// daily evolution loop.
pub fn run_evolution_window(
    state_before: &EvolutionWindowState,
    manifest_rows: &[ManifestUpgradeGift],
    invariants: &NonDegradationInvariants,
) -> EvolutionWindowState {
    // In production, this context should be built from host-local ALN shards,
    // twin state, and runtime telemetry; here we treat it as a synchronous
    // composition of corridor, barrier guard, and invariants.
    let context = EvolutionGuardContext {
        sovereignty_invariants: SovereigntyInvariants::from_binding(
            state_before.sovereignty.clone(),
            invariants.roh_ceiling_hard,
        ),
        corridor: CorridorMonoidalCorridor::from_state(
            state_before.corridor_thresholds.clone(),
        ),
        barrier_guard: ScalarBarrierGuard::default_conservative(),
    };

    let mut next = state_before.clone();

    for row in manifest_rows {
        // Sovereignty binding must match host constants.
        if !row.sovereignty.is_primary_and_compliant() {
            continue;
        }

        // Per-row guard: RoH projection and eco responsibility.
        if row.roh_after > invariants.roh_ceiling_hard + invariants.float_tol {
            continue;
        }
        if row.eco_delta < 0.0 {
            continue;
        }

        // Responsibility must not be negative for accepted rows.
        if row.rdelta < 0.0 {
            continue;
        }

        // Rights and capability deltas are subject to downgrade rules.
        if !row.host_authorized_downgrade {
            if !row.rights_delta.dominates(&RightsShard::zero()) {
                continue;
            }
            if row.capability_delta < 0.0 {
                continue;
            }
        }

        // Barrier guard step: use FP/OT/Bayes bundle to refine decision.
        let verdict = context.barrier_guard.evaluate_step(
            context.sovereignty_invariants.clone(),
            context.corridor.clone(),
            row.corridor_risk_bundle.clone(),
        );

        match verdict {
            BarrierVerdict::Deny => {
                continue;
            }
            BarrierVerdict::Brake { .. } | BarrierVerdict::Allow { .. } => {
                apply_row_effects(&mut next, row, invariants);
            }
        }
    }

    // Final clipping to hard invariants to avoid floating-point drift.
    if next.roh_ceiling > invariants.roh_ceiling_hard {
        next.roh_ceiling = invariants.roh_ceiling_hard;
    }
    if next.roh_max_observed > invariants.roh_ceiling_hard {
        next.roh_max_observed = invariants.roh_ceiling_hard;
    }
    if next.capability_floor < invariants.capability_floor_hard {
        next.capability_floor = invariants.capability_floor_hard;
    }

    next
}

/// Apply the deltas from an accepted manifest row into the evolution window
/// state. All call sites must have already enforced non-degradation rules.
fn apply_row_effects(
    state: &mut EvolutionWindowState,
    row: &ManifestUpgradeGift,
    _invariants: &NonDegradationInvariants,
) {
    // RoH tracking.
    if row.roh_after > state.roh_max_observed {
        state.roh_max_observed = row.roh_after;
    }

    // Vampiric envelope: tokens are consumed; ceilings are never increased.
    state.vampiric_envelope.consume_blood(row.blood_delta);
    state.vampiric_envelope.consume_protein(row.protein_delta);
    state.vampiric_envelope.consume_lifeforce(row.lifeforce_delta);

    // Responsibility scalar.
    state.responsibility_scalar += row.rdelta;

    // Capability floor.
    state.capability_floor += row.capability_delta;

    // Rights state: apply monotone floor merge.
    state.rights_state.merge_tightening(&row.rights_delta);

    // Host-authorized downgrade flag: once set, it remains set for this window.
    if row.host_authorized_downgrade {
        state.has_host_authorized_downgrade = true;
    }

    // Corridor thresholds: monotone-tightening update based on evidence.
    state
        .corridor_thresholds
        .merge_tightening_from_manifest(row);
}
