// crates/cdc-co-presence/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

use cybernano_physio::{GuardKernel, GuardVerdict, PhysioCaps, PhysioState, SovereignIdentity};
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum DeviceClass {
    Assistive,
    Diagnostics,
    NanoswarmHub,
    Bci,
    Unknown,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct DeviceDescriptor {
    pub class: DeviceClass,
    pub max_tx_power_dbm: f32,
    pub nominal_radius_m: f32,
    pub requires_aln_neurorights_clause: bool,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct CoPresenceCorridor {
    pub assistive_max_radius_m: f32,
    pub assistive_max_power_dbm: f32,
    pub diagnostics_max_radius_m: f32,
    pub diagnostics_max_power_dbm: f32,
    pub nanoswarm_max_radius_m: f32,
    pub nanoswarm_max_power_dbm: f32,
    pub bci_max_radius_m: f32,
    pub bci_max_power_dbm: f32,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum CdcVerdict {
    AllowCoPresence,
    RequireFreshConsent,
    DenyCorridor,
    DenyIdentity,
    DenyPolicy,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct ConsentBoundCdc {
    pub corridor: CoPresenceCorridor,
}

impl ConsentBoundCdc {
    fn check_limits(&self, desc: &DeviceDescriptor) -> CdcVerdict {
        match desc.class {
            DeviceClass::Assistive => {
                if desc.nominal_radius_m <= self.corridor.assistive_max_radius_m
                    && desc.max_tx_power_dbm <= self.corridor.assistive_max_power_dbm
                {
                    CdcVerdict::RequireFreshConsent
                } else {
                    CdcVerdict::DenyCorridor
                }
            }
            DeviceClass::Diagnostics => {
                if desc.nominal_radius_m <= self.corridor.diagnostics_max_radius_m
                    && desc.max_tx_power_dbm <= self.corridor.diagnostics_max_power_dbm
                {
                    CdcVerdict::RequireFreshConsent
                } else {
                    CdcVerdict::DenyCorridor
                }
            }
            DeviceClass::NanoswarmHub => {
                if desc.nominal_radius_m <= self.corridor.nanoswarm_max_radius_m
                    && desc.max_tx_power_dbm <= self.corridor.nanoswarm_max_power_dbm
                {
                    if desc.requires_aln_neurorights_clause {
                        CdcVerdict::AllowCoPresence
                    } else {
                        CdcVerdict::DenyPolicy
                    }
                } else {
                    CdcVerdict::DenyCorridor
                }
            }
            DeviceClass::Bci => {
                if desc.nominal_radius_m <= self.corridor.bci_max_radius_m
                    && desc.max_tx_power_dbm <= self.corridor.bci_max_power_dbm
                {
                    if desc.requires_aln_neurorights_clause {
                        CdcVerdict::RequireFreshConsent
                    } else {
                        CdcVerdict::DenyPolicy
                    }
                } else {
                    CdcVerdict::DenyCorridor
                }
            }
            DeviceClass::Unknown => CdcVerdict::DenyCorridor,
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub enum CdcError {
    IdentityNotCanonical,
}

impl GuardKernel for ConsentBoundCdc {
    type Input = DeviceDescriptor;
    type Output = CdcVerdict;
    type Error = CdcError;

    fn evaluate(
        &self,
        id: &SovereignIdentity,
        input: Self::Input,
        state: &PhysioState,
        _caps: &PhysioCaps,
    ) -> Result<(GuardVerdict, Self::Output, PhysioState), Self::Error> {
        if !id.is_canonical() {
            return Err(CdcError::IdentityNotCanonical);
        }

        let verdict = self.check_limits(&input);
        let guard_v = match verdict {
            CdcVerdict::AllowCoPresence => GuardVerdict::Allow,
            CdcVerdict::RequireFreshConsent => GuardVerdict::AllowWithBrake,
            CdcVerdict::DenyCorridor
            | CdcVerdict::DenyIdentity
            | CdcVerdict::DenyPolicy => GuardVerdict::Deny,
        };

        Ok((guard_v, verdict, *state))
    }
}
