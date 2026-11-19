
use serde::{Deserialize, Serialize};
use alncore::AlnScalar;
use rohkerneltypes::RoHScalar;
use neurorights_firewall::{NeurorightsPolicy, NeurorightsIntentSummary, NeurorightsVerdict};

/// Mapping configuration from RoH scalar to variational free energy.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RohFreeEnergyMappingConfig {
    pub roh_ceiling: RoHScalar,
    pub free_energy_scale: AlnScalar,
    pub non_rollback_weight: AlnScalar,
}

/// Override decision generated from free-energy minimization.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FreeEnergyOverrideDecision {
    pub roh_scalar: RoHScalar,
    pub free_energy_value: AlnScalar,
    pub override_allowed: bool,
}

/// Verdict for free-energy-based override generation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FreeEnergyOverrideVerdict {
    AllowOverride,
    KeepCurrentPolicy,
    DenyOverride,
}

/// Compute a scalar free-energy proxy from RoH.
/// Here F = free_energy_scale * (RoH_ceiling - RoH), treating lower RoH
/// as lower free energy, bounded by the constitutional RoH ceiling.
pub fn compute_roh_free_energy_scalar(
    cfg: &RohFreeEnergyMappingConfig,
    roh: RoHScalar,
) -> AlnScalar {
    let delta = (cfg.roh_ceiling - roh).max(0.0);
    cfg.free_energy_scale * delta
}

/// Generate override decisions from free-energy minimization, ensuring
/// neurorights and non-rollback constraints are respected.
pub fn generate_override_from_free_energy(
    cfg: &RohFreeEnergyMappingConfig,
    roh: RoHScalar,
    current_policy: &NeurorightsPolicy,
    proposed_intent: &NeurorightsIntentSummary,
) -> (FreeEnergyOverrideDecision, FreeEnergyOverrideVerdict) {
    let f = compute_roh_free_energy_scalar(cfg, roh);

    // If free energy is high (RoH far below ceiling), an override may be beneficial.
    // But we must check neurorights firewall and non-rollback weight.
    let firewall_verdict = neurorights_firewall::checkintentagainstpolicy(
        current_policy.clone(),
        proposed_intent.clone(),
    );

    let override_allowed = match firewall_verdict {
        NeurorightsVerdict::Allow => true,
        NeurorightsVerdict::Warn => cfg.non_rollback_weight < 1.0,
        NeurorightsVerdict::Deny => false,
    };

    let decision = FreeEnergyOverrideDecision {
        roh_scalar: roh,
        free_energy_value: f,
        override_allowed,
    };

    let verdict = if !override_allowed {
        FreeEnergyOverrideVerdict::DenyOverride
    } else if f > 0.0 {
        FreeEnergyOverrideVerdict::AllowOverride
    } else {
        FreeEnergyOverrideVerdict::KeepCurrentPolicy
    };

    (decision, verdict)
}

#[cfg(kani)]
mod roh_free_energy_kani {
    use super::*;
    use kani::any;

    #[kani::proof]
    pub fn free_energy_mapping_respects_roh_ceiling() {
        let roh_ceiling: RoHScalar = any();
        kani::assume(roh_ceiling >= 0.0);
        kani::assume(roh_ceiling <= 0.3);

        let free_energy_scale: AlnScalar = any();
        kani::assume(free_energy_scale >= 0.0);
        kani::assume(free_energy_scale <= 10.0);

        let cfg = RohFreeEnergyMappingConfig {
            roh_ceiling,
            free_energy_scale,
            non_rollback_weight: 0.5,
        };

        let roh: RoHScalar = any();
        kani::assume(roh >= 0.0);
        kani::assume(roh <= roh_ceiling);

        let f = compute_roh_free_energy_scalar(&cfg, roh);
        // Free energy is bounded above by free_energy_scale * roh_ceiling.
        assert!(f <= free_energy_scale * roh_ceiling);
        // And non-negative due to max(0, roh_ceiling - roh).
        assert!(f >= 0.0);
    }
}
