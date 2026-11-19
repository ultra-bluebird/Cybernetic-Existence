// crates/nanoswarm_core/src/controller.rs
#![forbid(unsafe_code)]
#![deny(warnings)]

use crate::energy_floor::{NanoswarmEnergyFloor, OrganichainAssetEnvelope};

#[derive(Clone, Debug)]
pub struct SwarmActuationRequest {
    /// Normalized energy demand for this actuation in [0, 1].
    pub required_energy_norm: f32,
    // ... other fields: tissue, duty, mission kind ...
}

#[derive(Clone, Debug)]
pub enum SwarmActuationVerdict {
    Allow,
    Brake,
    Deny,
}

/// Host-bound nanoswarm controller; must respect energy floors and RoH corridors.
#[derive(Clone, Debug)]
pub struct NanoswarmController {
    pub sovereignty: HostSovereigntyBinding,
    pub energy_floor: NanoswarmEnergyFloor,
    // ... other fields: RoHKernel, thermal guards, clogging guards ...
}

impl NanoswarmController {
    pub fn validate(&self) -> Result<(), String> {
        if !self.sovereignty.is_primary_and_compliant()
            || !self.energy_floor.sovereignty.is_primary_and_compliant()
        {
            return Err("NanoswarmController sovereignty mismatch".into());
        }
        Ok(())
    }

    /// Mandatory gate: consult nanoswarm_energy_floor before any actuation.
    pub fn evaluate_actuation(
        &self,
        req: &SwarmActuationRequest,
        env: &OrganichainAssetEnvelope,
    ) -> Result<SwarmActuationVerdict, String> {
        self.validate()?;
        // Tighten floor with latest metabolic envelope (measurement-tethered).
        let mut floor = self.energy_floor.clone();
        floor.tighten(env)?;

        let floor_val = floor.value();
        let demand = req.required_energy_norm;

        // If demand exceeds monotone floor, deny or brake.
        if demand > floor_val {
            // Conservative: Deny; variants could Brake if near floor.
            Ok(SwarmActuationVerdict::Deny)
        } else {
            Ok(SwarmActuationVerdict::Allow)
        }
    }
}
