// filename: mk-bluebird/Cybercore/crates/nanoswarm-guard-kernel/src/virtual_twin_oracle.rs
#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

use nanorobotics_virtual_supercomputer_sim::{
    coeffs::SimulationCoefficients,
    evidence::TwinSimulationProof,
    polytope::{MissionPlanView, SafetyPolytope7D},
    trajectory::TwinSimulationResult,
    HostBinding, VirtualTwinSafetyOracle,
};

/// Verdict lattice used by the guard kernel.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum GuardVerdict {
    Allow,
    Brake,
    Deny,
}

impl GuardVerdict {
    pub fn and_gate(self, other: GuardVerdict) -> GuardVerdict {
        use GuardVerdict::*;
        match (self, other) {
            (Deny, _) | (_, Deny) => Deny,
            (Brake, _) | (_, Brake) => Brake,
            (Allow, Allow) => Allow,
        }
    }
}

/// Static view of the corridor polytope used by the guard.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GuardCorridor {
    pub polytope: SafetyPolytope7D,
    pub roh_ceiling: f32,
}

impl GuardCorridor {
    pub fn dominates_twin_polytope(&self, twin: &SafetyPolytope7D) -> bool {
        // Design-time invariant: A_twin == A_guard, b_twin <= b_guard.
        if twin.rows.len() != self.polytope.rows.len() {
            return false;
        }
        for (row_twin, row_guard) in twin.rows.iter().zip(self.polytope.rows.iter()) {
            if row_twin.a != row_guard.a {
                return false;
            }
            if row_twin.b > row_guard.b {
                return false;
            }
        }
        true
    }
}

/// Mandatory AND-gate integration between twin and guard kernel.
pub struct VirtualTwinGuard<'a, O: VirtualTwinSafetyOracle<Plan = MissionPlanView>> {
    pub oracle: &'a O,
    pub host: HostBinding,
    pub corridor: GuardCorridor,
    pub coeffs: SimulationCoefficients,
}

impl<'a, O> VirtualTwinGuard<'a, O>
where
    O: VirtualTwinSafetyOracle<Plan = MissionPlanView, Error = nanorobotics_virtual_supercomputer_sim::VirtualTwinError>,
{
    pub fn evaluate_plan(
        &self,
        plan: &MissionPlanView,
    ) -> Result<(GuardVerdict, TwinSimulationResult, TwinSimulationProof), O::Error> {
        let mut twin_poly = self.corridor.polytope.clone();
        for row in &mut twin_poly.rows {
            row.b = row.b * 0.95_f32;
        }

        if !self.corridor.dominates_twin_polytope(&twin_poly) {
            return Err(nanorobotics_virtual_supercomputer_sim::VirtualTwinError::InvalidPolytope(
                "twin polytope must be dominated by guard corridor".into(),
            ));
        }

        let (result, mut proof) =
            self.oracle
                .simulate_mission(&self.host, &self.coeffs, &twin_poly, plan)?;

        if !proof.is_host_bound() {
            return Ok((GuardVerdict::Deny, result, proof));
        }

        let twin_verdict = match result.verdict {
            nanorobotics_virtual_supercomputer_sim::trajectory::SafetyVerdict::Allow => GuardVerdict::Allow,
            nanorobotics_virtual_supercomputer_sim::trajectory::SafetyVerdict::Brake => GuardVerdict::Brake,
            nanorobotics_virtual_supercomputer_sim::trajectory::SafetyVerdict::Deny => GuardVerdict::Deny,
        };

        let guard_roh_verdict = if result.max_roh > self.corridor.roh_ceiling {
            GuardVerdict::Deny
        } else {
            GuardVerdict::Allow
        };

        let verdict = twin_verdict.and_gate(guard_roh_verdict);

        proof.summary = format!(
            "VirtualTwinGuard: twin={:?}, guard_roh={:?}, max_roh={:.4}",
            twin_verdict, guard_roh_verdict, result.max_roh
        );

        Ok((verdict, result, proof))
    }
}
