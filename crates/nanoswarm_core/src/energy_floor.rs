// crates/nanoswarm_core/src/energy_floor.rs
#![forbid(unsafe_code)]
#![deny(warnings)]

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HostSovereigntyBinding {
    pub host_did: String,
    pub bostrom_address: String,
    pub governed_by: String,
}

impl HostSovereigntyBinding {
    pub const PRIMARY_DID: &'static str = "did.aln.bostrom-organic-host";
    pub const PRIMARY_BOSTROM: &'static str =
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    pub const REQUIRED_CLAUSE: &'static str =
        "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

    pub fn is_primary_and_compliant(&self) -> bool {
        self.host_did == Self::PRIMARY_DID
            && self.bostrom_address == Self::PRIMARY_BOSTROM
            && self.governed_by == Self::REQUIRED_CLAUSE
    }
}

/// Organichain-backed metabolic asset view: glucose, ATP, Lifeforce
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OrganichainAssetEnvelope {
    pub sovereignty: HostSovereigntyBinding,
    /// Normalized blood glucose in [0, 1] per corridor.
    pub glucose_norm: f32,
    /// Normalized ATP reserve in [0, 1] including MT6883 and biofilm terms.
    pub atp_norm: f32,
    /// Lifeforce ATP scalar in [0, 1] respecting lifeforce floors.
    pub lifeforce_norm: f32,
}

impl OrganichainAssetEnvelope {
    pub fn validate(&self) -> Result<(), String> {
        if !self.sovereignty.is_primary_and_compliant() {
            return Err("OrganichainAssetEnvelope sovereignty mismatch".into());
        }
        for (name, v) in [
            ("glucose_norm", self.glucose_norm),
            ("atp_norm", self.atp_norm),
            ("lifeforce_norm", self.lifeforce_norm),
        ] {
            if !(0.0..=1.0).contains(&v) {
                return Err(format!("{name} must lie in [0,1]"));
            }
        }
        Ok(())
    }
}

/// Immutable, monotone nanoswarm energy floor derived from host metabolism.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NanoswarmEnergyFloor {
    pub sovereignty: HostSovereigntyBinding,
    /// Monotone floor scalar in [0, 1]; only increases via tighten().
    pub floor_norm: f32,
}

impl NanoswarmEnergyFloor {
    /// Initialize floor from first calibrated Organichain envelope.
    pub fn from_envelope(env: &OrganichainAssetEnvelope) -> Result<Self, String> {
        env.validate()?;
        let s = &env.sovereignty;
        Ok(Self {
            sovereignty: s.clone(),
            floor_norm: Self::compute_scalar(env),
        })
    }

    /// Compute conservative energy scalar E_host from metabolic axes.
    fn compute_scalar(env: &OrganichainAssetEnvelope) -> f32 {
        // Weights drawn from ALN lifeforce/ATP calibration shards.
        const W_GLUCOSE: f32 = 0.3;
        const W_ATP: f32 = 0.4;
        const W_LIFEFORCE: f32 = 0.3;
        W_GLUCOSE * env.glucose_norm
            + W_ATP * env.atp_norm
            + W_LIFEFORCE * env.lifeforce_norm
    }

    /// Monotone tighten: new floor is max(old_floor, E_host(env)).
    pub fn tighten(&mut self, env: &OrganichainAssetEnvelope) -> Result<(), String> {
        env.validate()?;
        if !self.sovereignty.is_primary_and_compliant()
            || !env.sovereignty.is_primary_and_compliant()
        {
            return Err("Sovereignty mismatch in energy floor tighten".into());
        }
        let candidate = Self::compute_scalar(env);
        // Monotonicity: floor_norm' = max(floor_norm, candidate) ≥ floor_norm
        if candidate > self.floor_norm {
            self.floor_norm = candidate;
        }
        Ok(())
    }

    /// Query floor value for controller logic.
    pub fn value(&self) -> f32 {
        self.floor_norm
    }
}
