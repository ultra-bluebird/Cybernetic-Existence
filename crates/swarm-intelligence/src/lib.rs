// nanorobotics/swarm-intelligence/src/lib.rs

use serde::{Deserialize, Serialize};

pub mod state;
pub mod policy;
pub mod governance;

/// Core swarm state representation, usable directly in policies or
/// as a reduced view derived from `state::SwarmContext`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwarmState {
    pub positions_nm: Vec<(f64, f64, f64)>,
    pub velocities_nm_s: Vec<(f64, f64, f64)>,
}

/// Minimal trait for state-based swarm policies.
/// This complements the telemetry-driven traits in `policy`.
pub trait SwarmPolicy {
    fn step(&mut self, state: &SwarmState) -> SwarmState;
}

/// Convenience function to build a `SwarmState` from a `state::SwarmContext`,
/// aggregating robot positions from recent telemetry.
pub fn state_from_context(ctx: &state::SwarmContext) -> SwarmState {
    let mut positions_nm = Vec::new();
    let mut velocities_nm_s = Vec::new();

    for row in &ctx.recent_rows {
        if let Some(sample) = &row.afm_sample {
            positions_nm.push((sample.x_nm, sample.y_nm, sample.z_nm));
        } else {
            positions_nm.push((0.0, 0.0, 0.0));
        }

        // Placeholder velocities; these can be upgraded by integrating motion telemetry.
        velocities_nm_s.push((0.0, 0.0, 0.0));
    }

    SwarmState {
        positions_nm,
        velocities_nm_s,
    }
}
