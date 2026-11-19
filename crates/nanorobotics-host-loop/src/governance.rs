// crates/nanorobotics-host-loop/src/governance.rs

/// Cybercore authority marker for host-loop artifacts.
pub const CYBERCORE_AUTHORITY_MIGRATION: &str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

pub fn default_host_loop_mode() -> &'static str {
    "host_local_nanorobotics_control_loop_v1"
}

pub fn default_host_compliance() -> &'static str {
    "roh_max_0.3_capability_floor_0.8_no_rollback_without_host_token"
}
