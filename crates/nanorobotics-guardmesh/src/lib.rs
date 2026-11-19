//! nanorobotics-guardmesh
//!
//! Threshold-based sovereignty guard mesh configuration and Brake decisions.
//!
//! This crate does not implement a full network protocol. Instead, it defines
//! configuration structures and deterministic decision logic for when a mesh
//! of guard nodes may issue a HardBrake, SoftBrake, or Defer result based on
//! approvals and emergency conditions.

#![forbid(unsafe_code)]
#![deny(missing_docs)]

use std::collections::HashSet;
use std::time::Duration;

/// Logical identifier of a guard node.
///
/// This can be bound to a DID or other higher-level identity construct.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct GuardNodeId(pub String);

/// Configuration for a sovereignty guard mesh associated with a single host.
///
/// This configuration is intended to be derived from append-only governance
/// artifacts and validated before being used at runtime.
#[derive(Clone, Debug)]
pub struct MeshGuardConfig {
    /// All guard nodes participating in the mesh for a given host.
    pub nodes: Vec<GuardNodeId>,
    /// Maximum number of Byzantine (arbitrary-fault) nodes tolerated.
    pub max_byzantine: usize,
    /// Quorum threshold for issuing a HardBrake.
    ///
    /// Must satisfy quorum >= 2 * max_byzantine + 1 and quorum <= nodes.len().
    pub quorum: usize,
    /// Maximum allowed Risk-of-Harm or nociceptive severity before an emergency
    /// solo Brake path may be considered.
    pub emergency_threshold: f32,
    /// Maximum time to wait for mesh approvals before emergency solo decisions.
    pub emergency_timeout: Duration,
}

impl MeshGuardConfig {
    /// Validates configuration invariants.
    pub fn validate(&self) -> Result<(), String> {
        let n = self.nodes.len();
        if n == 0 {
            return Err("nodes must not be empty".into());
        }
        if self.max_byzantine == 0 {
            return Err("max_byzantine must be >= 1".into());
        }
        if n < 3 * self.max_byzantine + 1 {
            return Err("n < 3f+1 violation".into());
        }
        if self.quorum < 2 * self.max_byzantine + 1 {
            return Err("quorum < 2f+1 violation".into());
        }
        if self.quorum > n {
            return Err("quorum > n violation".into());
        }
        if self.emergency_threshold <= 0.0 || self.emergency_threshold > 1.0 {
            return Err("emergency_threshold must be in (0,1]".into());
        }
        if self.emergency_timeout.as_millis() == 0 {
            return Err("emergency_timeout must be > 0".into());
        }
        Ok(())
    }
}

/// Represents an approval for a Brake proposal from a guard node.
///
/// The actual signature or cryptographic envelope is not modeled here; this
/// struct only captures the fact that a node has approved.
#[derive(Clone, Debug)]
pub struct Approval {
    /// Guard node issuing the approval.
    pub node_id: GuardNodeId,
    /// Local Risk-of-Harm or nociception severity observed at approval time.
    ///
    /// Normalized to [0.0, 1.0].
    pub local_severity: f32,
}

/// Result of running the mesh decision engine.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MeshDecision {
    /// Quorum reached; all guards should coordinate a global Brake.
    HardBrake,
    /// Local emergency Brake is permitted; mesh did not reach quorum in time,
    /// but emergency conditions were observed.
    SoftBrake,
    /// No Brake is authorized yet; continue gathering approvals or monitoring.
    Defer,
}

/// Computes a mesh Brake decision based on approvals and configuration.
///
/// Parameters:
///   - approvals: current set of approvals (possibly including duplicates).
///   - cfg: mesh configuration, previously validated.
///   - elapsed_since_proposal: time elapsed since the Brake proposal was initiated.
///   - max_observed_severity: maximum severity observed across all guard nodes,
///     including those that may not have submitted approvals yet.
///
/// Behavior:
///   - If unique approvals >= quorum => HardBrake.
///   - Else if max_severity >= emergency_threshold and elapsed >= emergency_timeout
///     => SoftBrake.
///   - Else => Defer.
pub fn decide_brake(
    approvals: &[Approval],
    cfg: &MeshGuardConfig,
    elapsed_since_proposal: Duration,
    max_observed_severity: f32,
) -> MeshDecision {
    let mut unique = HashSet::new();
    for a in approvals {
        unique.insert(a.node_id.clone());
    }
    let unique_count = unique.len();

    if unique_count >= cfg.quorum {
        MeshDecision::HardBrake
    } else if max_observed_severity >= cfg.emergency_threshold
        && elapsed_since_proposal >= cfg.emergency_timeout
    {
        MeshDecision::SoftBrake
    } else {
        MeshDecision::Defer
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_config(n: usize, f: usize) -> MeshGuardConfig {
        let nodes = (0..n)
            .map(|i| GuardNodeId(format!("node-{}", i)))
            .collect::<Vec<_>>();
        let quorum = 2 * f + 1;
        MeshGuardConfig {
            nodes,
            max_byzantine: f,
            quorum,
            emergency_threshold: 0.9,
            emergency_timeout: Duration::from_millis(100),
        }
    }

    #[test]
    fn config_invariants_hold() {
        let cfg = sample_config(4, 1);
        assert!(cfg.validate().is_ok());

        let bad_cfg = MeshGuardConfig {
            nodes: vec![GuardNodeId("a".into()), GuardNodeId("b".into())],
            max_byzantine: 1,
            quorum: 2,
            emergency_threshold: 0.9,
            emergency_timeout: Duration::from_millis(100),
        };
        assert!(bad_cfg.validate().is_err());
    }

    #[test]
    fn hard_brake_requires_quorum() {
        let cfg = sample_config(4, 1);
        let mut approvals = Vec::new();
        approvals.push(Approval {
            node_id: GuardNodeId("node-0".into()),
            local_severity: 0.8,
        });
        let elapsed = Duration::from_millis(50);
        let max_sev = 0.8;

        let decision = decide_brake(&approvals, &cfg, elapsed, max_sev);
        assert_eq!(decision, MeshDecision::Defer);

        approvals.push(Approval {
            node_id: GuardNodeId("node-1".into()),
            local_severity: 0.95,
        });
        approvals.push(Approval {
            node_id: GuardNodeId("node-2".into()),
            local_severity: 0.7,
        });

        let decision2 = decide_brake(&approvals, &cfg, elapsed, 0.95);
        assert_eq!(decision2, MeshDecision::HardBrake);
    }

    #[test]
    fn soft_brake_on_emergency_timeout() {
        let cfg = sample_config(4, 1);
        let approvals = Vec::new();
        let elapsed = Duration::from_millis(200);
        let max_sev = 0.95;

        let decision = decide_brake(&approvals, &cfg, elapsed, max_sev);
        assert_eq!(decision, MeshDecision::SoftBrake);
    }
}
