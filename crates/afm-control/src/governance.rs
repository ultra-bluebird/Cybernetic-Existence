// nanorobotics/afm-control/src/governance.rs
pub const CYBERCORE_AUTHORITY_MIGRATION: &str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

pub fn default_governance_mode() -> &'static str {
    "host_local_afm_control_v1"
}
