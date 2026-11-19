// destination-path: mk-bluebird/nanorobotics/crates/nanoswarm-guard/src/emi_guard.rs
// edition: 2024
// rust-version: 1.85

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use serde::{Deserialize, Serialize};

pub const HOST_DID: &str = "did:aln:organic-host";
pub const PRIMARY_BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
pub const ALN_MIGRATION_CLAUSE: &str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SwarmEmiCorridor {
    pub corridor_id: String,
    pub host_did: String,
    pub bostrom_address: String,
    pub freq_hz_low: f32,
    pub freq_hz_high: f32,
    pub e_field_max: f32,
    pub b_field_max: f32,
    pub acoustic_max: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EmiGuardVerdict {
    Safe,
    Veto,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EmiSample {
    pub freq_hz: f32,
    pub e_field: f32,
    pub b_field: f32,
    pub acoustic: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EmiGuardError {
    SovereignBindingMismatch,
    CorridorInvalid,
}

impl SwarmEmiCorridor {
    pub fn new(
        corridor_id: String,
        freq_hz_low: f32,
        freq_hz_high: f32,
        e_field_max: f32,
        b_field_max: f32,
        acoustic_max: f32,
    ) -> Result<Self, EmiGuardError> {
        if freq_hz_low < 0.0 || freq_hz_high < freq_hz_low {
            return Err(EmiGuardError::CorridorInvalid);
        }
        if e_field_max < 0.0 || b_field_max < 0.0 || acoustic_max < 0.0 {
            return Err(EmiGuardError::CorridorInvalid);
        }
        Ok(Self {
            corridor_id,
            host_did: HOST_DID.to_string(),
            bostrom_address: PRIMARY_BOSTROM_ADDRESS.to_string(),
            freq_hz_low,
            freq_hz_high,
            e_field_max,
            b_field_max,
            acoustic_max,
        })
    }

    pub fn check_binding(&self) -> Result<(), EmiGuardError> {
        if self.host_did != HOST_DID || self.bostrom_address != PRIMARY_BOSTROM_ADDRESS {
            return Err(EmiGuardError::SovereignBindingMismatch);
        }
        Ok(())
    }

    pub fn evaluate_sample(&self, sample: EmiSample) -> EmiGuardVerdict {
        if sample.freq_hz < self.freq_hz_low || sample.freq_hz > self.freq_hz_high {
            return EmiGuardVerdict::Safe;
        }
        if sample.e_field > self.e_field_max
            || sample.b_field > self.b_field_max
            || sample.acoustic > self.acoustic_max
        {
            EmiGuardVerdict::Veto
        } else {
            EmiGuardVerdict::Safe
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn emi_guard_respects_limits() {
        let corridor = SwarmEmiCorridor::new(
            "brain-bci-band".to_string(),
            5.0,
            90.0,
            0.5,
            1.0e-3,
            100.0,
        )
        .unwrap();

        corridor.check_binding().unwrap();

        let safe = EmiSample {
            freq_hz: 10.0,
            e_field: 0.1,
            b_field: 5.0e-4,
            acoustic: 10.0,
        };
        assert_eq!(corridor.evaluate_sample(safe), EmiGuardVerdict::Safe);

        let veto = EmiSample {
            freq_hz: 10.0,
            e_field: 0.6,
            b_field: 5.0e-4,
            acoustic: 10.0,
        };
        assert_eq!(corridor.evaluate_sample(veto), EmiGuardVerdict::Veto);
    }
}

#[cfg(kani)]
mod kani_harnesses {
    use super::*;
    use kani::any;

    /// Prove that any sample exceeding a field limit in-band leads to Veto.
    #[kani::proof]
    fn kani_emi_veto_on_violation() {
        let corridor = SwarmEmiCorridor::new(
            "brain-bci-band".to_string(),
            5.0,
            90.0,
            0.5,
            1.0e-3,
            100.0,
        )
        .unwrap();

        let mut sample: EmiSample = any();
        kani::assume(sample.freq_hz >= corridor.freq_hz_low);
        kani::assume(sample.freq_hz <= corridor.freq_hz_high);

        let violation_choice: u8 = any();
        if violation_choice == 0 {
            kani::assume(sample.e_field > corridor.e_field_max);
        } else if violation_choice == 1 {
            kani::assume(sample.b_field > corridor.b_field_max);
        } else {
            kani::assume(sample.acoustic > corridor.acoustic_max);
        }

        let verdict = corridor.evaluate_sample(sample);
        assert_eq!(verdict, EmiGuardVerdict::Veto);
    }
}
