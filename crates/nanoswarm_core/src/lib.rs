#![forbid(unsafe_code)]
#![deny(warnings)]

use serde::{Deserialize, Serialize};

use cybernano_physio::{GuardKernel, GuardVerdict, PhysioCaps, PhysioState, SovereignIdentity};
use cybernano_biospatial::roh::{BiospatialRegionState, BiospatialRoHGuard, SafetyVerdict};

/// Canonical host identity binding for nanoswarm endpoints and guards.
pub const HOSTDID: &str = "didalnorganic-host";
pub const BOSTROMADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Nanoswarm endpoint descriptor, mirroring `NanoswarmEndpointV1` in ALN.
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

impl NanoEndpointDescriptor {
    pub fn validate(&self) -> Result<(), String> {
        if self.roh_slice_max < 0.0 || self.roh_slice_max > 0.30 {
            return Err("roh_slice_max must lie in [0.0, 0.30]".into());
        }
        if self.evidence_tags.iter().any(|t| t.is_empty()) {
            return Err("all evidence_tags must be non-empty".into());
        }
        Ok(())
    }
}

/// Verdict for nanoswarm corridor evaluation.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum NanoswarmVerdict {
    Allow,
    Brake,
    Deny,
}

/// Guard errors for nanoswarm corridor checking.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum NanoswarmGuardError {
    IdentityNotCanonical,
    RohSliceExceeded,
}

/// Nanoswarm corridor guard: enforces endpoint slice ceilings and host binding.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct NanoswarmCorridorGuard;

impl GuardKernel for NanoswarmCorridorGuard {
    type Input = NanoEndpointDescriptor;
    type Output = NanoswarmVerdict;
    type Error = NanoswarmGuardError;

    fn evaluate(
        &self,
        id: SovereignIdentity,
        input: Self::Input,
        state: PhysioState,
        caps: PhysioCaps,
    ) -> Result<GuardVerdict<Self::Output, PhysioState, Self::Error>, Self::Error> {
        if !id.is_canonical() {
            return Err(NanoswarmGuardError::IdentityNotCanonical);
        }

        input
            .validate()
            .map_err(|_| NanoswarmGuardError::RohSliceExceeded)?;

        // Enforce endpoint slice ceiling against physio caps.
        if input.roh_slice_max > 0.30 || input.roh_slice_max > caps.roh_ceiling {
            return Err(NanoswarmGuardError::RohSliceExceeded);
        }

        Ok(GuardVerdict::Allow(
            NanoswarmVerdict::Allow,
            state,
        ))
    }
}

/// RealityWindow proposal id.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProposalId(pub String);

/// Nanoswarm mission proposal in RealityWindow.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct NanoswarmProposal {
    pub id: ProposalId,
    pub endpoint_id: String,
    // Future fields: duty profile, mission kind, etc.
}

/// Simple endpoint registry mapping IDs to descriptors.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct EndpointRegistry {
    endpoints: Vec<NanoEndpointDescriptor>,
}

impl EndpointRegistry {
    pub fn new(endpoints: Vec<NanoEndpointDescriptor>) -> Self {
        Self { endpoints }
    }

    pub fn lookup(&self, endpoint_id: &str) -> Option<NanoEndpointDescriptor> {
        self.endpoints
            .iter()
            .find(|e| e.endpoint_id == endpoint_id)
            .cloned()
    }
}

/// RealityWindow: integrates nanoswarm guard with biospatial RoH guard.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct RealityWindow {
    pub endpoint_registry: EndpointRegistry,
    pub nanoswarm_guard: NanoswarmCorridorGuard,
    pub biospatial_guard: BiospatialRoHGuard,
}

impl RealityWindow {
    /// Evaluate proposals under biospatial RoH and nanoswarm corridor constraints.
    pub fn evaluate_biospatial(
        &self,
        id: SovereignIdentity,
        biospatial_state: Vec<BiospatialRegionState>,
        proposals: Vec<NanoswarmProposal>,
        physio_state: PhysioState,
        physio_caps: PhysioCaps,
    ) -> Vec<(ProposalId, NanoswarmVerdict)> {
        // Aggregate regional RoH to global and check SafetyVerdict.
        let (safety_verdict, roh_global) = self.biospatial_guard.evaluate_scalar(&biospatial_state);

        let _roh_global_clamped = roh_global.min(0.30);

        let mut out = Vec::with_capacity(proposals.len());

        for prop in proposals {
            let endpoint = match self.endpoint_registry.lookup(&prop.endpoint_id) {
                Some(e) => e,
                None => {
                    out.push((prop.id.clone(), NanoswarmVerdict::Deny));
                    continue;
                }
            };

            // Enforce safety verdict first.
            let verdict = match safety_verdict {
                SafetyVerdict::RollbackRequired => NanoswarmVerdict::Deny,
                SafetyVerdict::Brake => NanoswarmVerdict::Brake,
                SafetyVerdict::Safe => {
                    // Delegate to nanoswarm corridor guard.
                    match self
                        .nanoswarm_guard
                        .evaluate(id.clone(), endpoint, physio_state, physio_caps)
                    {
                        Ok(GuardVerdict::Allow(v, _)) => v,
                        Ok(GuardVerdict::AllowWithBrake(_, _)) => NanoswarmVerdict::Brake,
                        Ok(GuardVerdict::Deny(_, _)) | Err(_) => NanoswarmVerdict::Deny,
                    }
                }
            };

            out.push((prop.id.clone(), verdict));
        }

        out
    }
}
