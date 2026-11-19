// crates/swarm-intelligence/src/policy.rs

use serde::{Deserialize, Serialize};
use nanoswarm_telemetry::row::TelemetryRow;
use crate::state::SwarmContext;

/// Output command for a single robot in the swarm.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RobotCommand {
    pub robot_id: String,
    pub new_mode: String,
    pub target_position_nm: Option<(f64, f64, f64)>,
}

/// High-level trait for nanoswarm policies.
/// Implementations can use AFM samples, motion targets, DNA designs, and lattices
/// contained in recent telemetry rows to produce new commands.
pub trait SwarmPolicy {
    fn compute_commands(&mut self, ctx: &SwarmContext) -> Vec<RobotCommand>;
}

/// Example policy: "follow AFM gradient".
/// Robots move toward regions where AFM height increases, a simple proxy for surface features.
#[derive(Debug, Default)]
pub struct AfmGradientPolicy;

impl SwarmPolicy for AfmGradientPolicy {
    fn compute_commands(&mut self, ctx: &SwarmContext) -> Vec<RobotCommand> {
        let mut commands = Vec::new();

        // Group rows by robot_id.
        let mut by_robot: std::collections::HashMap<String, Vec<&TelemetryRow>> = std::collections::HashMap::new();
        for row in &ctx.recent_rows {
            by_robot.entry(row.robot_id.clone()).or_default().push(row);
        }

        for (robot_id, rows) in by_robot {
            // Compute a simple average AFM height and position for this robot.
            let mut count = 0u64;
            let mut sum_x = 0.0;
            let mut sum_y = 0.0;
            let mut sum_z = 0.0;

            for row in rows {
                if let Some(sample) = &row.afm_sample {
                    count += 1;
                    sum_x += sample.x_nm;
                    sum_y += sample.y_nm;
                    sum_z += sample.z_nm;
                }
            }

            let target_position_nm = if count > 0 {
                let n = count as f64;
                Some((sum_x / n, sum_y / n, sum_z / n))
            } else {
                None
            };

            // Basic mode decision: if we have AFM data, set mode to "dock", otherwise "survey".
            let new_mode = if target_position_nm.is_some() {
                "dock".to_string()
            } else {
                "survey".to_string()
            };

            commands.push(RobotCommand {
                robot_id,
                new_mode,
                target_position_nm,
            });
        }

        commands
    }
}

/// Example policy: DNA-structure-aware behavior.
/// If a lattice is present, we bias robots toward the lattice center of mass for coordinated actions.
#[derive(Debug, Default)]
pub struct DnaStructurePolicy;

impl SwarmPolicy for DnaStructurePolicy {
    fn compute_commands(&mut self, ctx: &SwarmContext) -> Vec<RobotCommand> {
        let mut commands = Vec::new();

        // Compute approximate lattice center.
        let mut sum_x = 0.0;
        let mut sum_y = 0.0;
        let mut sum_z = 0.0;
        let mut node_count = 0u64;

        for row in &ctx.recent_rows {
            if let Some(lattice) = &row.lattice {
                for node in &lattice.nodes {
                    node_count += 1;
                    sum_x += node.x_nm;
                    sum_y += node.y_nm;
                    sum_z += node.z_nm;
                }
            }
        }

        let lattice_center = if node_count > 0 {
            let n = node_count as f64;
            Some((sum_x / n, sum_y / n, sum_z / n))
        } else {
            None
        };

        // Assign commands based on lattice presence.
        for row in &ctx.recent_rows {
            let target_position_nm = lattice_center;
            let new_mode = if lattice_center.is_some() {
                "coordinate".to_string()
            } else {
                "survey".to_string()
            };

            commands.push(RobotCommand {
                robot_id: row.robot_id.clone(),
                new_mode,
                target_position_nm,
            });
        }

        commands
    }
}
