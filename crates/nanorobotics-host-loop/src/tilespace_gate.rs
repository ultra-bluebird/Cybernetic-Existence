use organichain_tilespace::{AlnMigrationAuthority, FpicStatus, SimSwarmConfig};
use swarm_guard_lattice::SafetyVerdict;

/// Gate nanoswarm simulations based on tilespace identity, authority, and FPIC status.
pub fn gate_simswarm(config: &SimSwarmConfig) -> SafetyVerdict {
    if config.tilespace.host_did.is_empty()
        || config.tilespace.bostrom_address.is_empty()
        || config.tilespace.migration_authority != AlnMigrationAuthority::CybercoreV1
    {
        return SafetyVerdict::Veto;
    }

    match config.fpic.status {
        FpicStatus::Granted => SafetyVerdict::Allow,
        FpicStatus::Withheld => SafetyVerdict::Brake,
        FpicStatus::Denied => SafetyVerdict::Veto,
    }
}

/// Join two verdicts under the lattice max operator (worst verdict dominates).
pub fn join_verdict(a: SafetyVerdict, b: SafetyVerdict) -> SafetyVerdict {
    core::cmp::max(a, b)
}
