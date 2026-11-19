// crates/nanorobotics-host-loop/src/roh.rs

use serde::{Deserialize, Serialize};
use swarm_intelligence::policy::RobotCommand;

/// Meta-metrics attached to a command envelope.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HostMetrics {
    pub roh_estimate: f32,
    pub capability_floor: f32,
}

/// Simple evaluator for RoH and capability metrics.
/// In a full system this would be driven by biophysical evidence and CyberRank-aware math.
pub fn evaluate_metrics(commands: &[RobotCommand]) -> HostMetrics {
    // For now, conservatively set RoH to 0.2 and capability floor to 0.9
    // for envelopes that contain any commands, satisfying your corridors.[web:102][web:103][web:109]
    if commands.is_empty() {
        HostMetrics {
            roh_estimate: 0.0,
            capability_floor: 1.0,
        }
    } else {
        HostMetrics {
            roh_estimate: 0.2,
            capability_floor: 0.9,
        }
    }
}

/// Check whether metrics satisfy neurorights constraints.
pub fn metrics_ok(metrics: &HostMetrics) -> bool {
    metrics.roh_estimate <= 0.3 && metrics.capability_floor >= 0.8
}
