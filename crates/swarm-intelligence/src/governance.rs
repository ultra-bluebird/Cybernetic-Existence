// crates/swarm-intelligence/src/governance.rs

/// Cybercore authority marker for swarm intelligence artifacts.
pub const CYBERCORE_AUTHORITY_MIGRATION: &str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

/// Default governance mode for trait-based nanoswarm policies.
pub fn default_swarm_governance_mode() -> &'static str {
    "host_local_swarm_intelligence_v1"
}

/// Compliance tag encoding RoH <= 0.3 and capability floor >= 0.8 for swarm behavior.
pub fn default_swarm_compliance() -> &'static str {
    "roh_max_0.3_capability_floor_0.8_no_rollback_without_host_token"
}
