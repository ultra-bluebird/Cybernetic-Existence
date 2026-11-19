// crates/nanoswarm-corridor/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

use cybernano_physio::{GuardKernel, GuardVerdict, PhysioCaps, PhysioState, SovereignIdentity};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct NanoEndpointDescriptor {
    pub endpoint_id: String,
    pub biospatial_region_id: String,
    pub corridor_id: String,
    pub max_energy_j: f32,
    pub max_duty_cycle: f32,
    pub max_temp_delta_c: f32,
    pub roh_slice_max: f32,
    pub evidence_tags: [String; 10],
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum NanoswarmVerdict {
    Allow,
    Brake,
    Deny,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct NanoswarmCorridorGuard;

#[derive(Debug, Clone, Copy)]
pub enum NanoswarmGuardError {
    IdentityNotCanonical,
    RohSliceExceeded,
}

impl GuardKernel for NanoswarmCorridorGuard {
    type Input = NanoEndpointDescriptor;
    type Output = NanoswarmVerdict;
    type Error = NanoswarmGuardError;

    fn evaluate(
        &self,
        id: &SovereignIdentity,
        input: Self::Input,
        state: &PhysioState,
        caps: &PhysioCaps,
    ) -> Result<(GuardVerdict, Self::Output, PhysioState), Self::Error> {
        if !id.is_canonical() {
            return Err(NanoswarmGuardError::IdentityNotCanonical);
        }

        // Placeholder: actual thermal/energy/RoH slice math should be wired to BiospatialCorridorPolytope.
        if input.roh_slice_max > 0.30 || input.roh_slice_max > caps.roh_ceiling {
            return Err(NanoswarmGuardError::RohSliceExceeded);
        }

        Ok((GuardVerdict::Allow, NanoswarmVerdict::Allow, *state))
    }
}
