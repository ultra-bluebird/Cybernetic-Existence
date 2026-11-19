// crates/neuroproximal-nei/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

use core::cmp::Ordering;
use cybernano_physio::{GuardKernel, GuardVerdict, PhysioCaps, PhysioState, SovereignIdentity};
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct EnvTelemetry {
    pub rf_power_density_mw_cm2: f32,
    pub rf_power_density_max_mw_cm2: f32,
    pub sound_db_spl: f32,
    pub sound_db_spl_max: f32,
    pub lux: f32,
    pub lux_max: f32,
    pub vib_power: f32,
    pub vib_power_max: f32,
    pub thermal_radiant_delta_c: f32,
    pub thermal_radiant_delta_max_c: f32,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum NeiVerdict {
    AllowWithinCorridor,
    DenyEnvExceedsCorridor,
    DenyIdentity,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct NeiConfig {
    pub w_rf: f32,
    pub w_acoustic: f32,
    pub w_lux: f32,
    pub w_vib: f32,
    pub w_th: f32,
    pub eenv_comfort: f32,
    pub k_env: f32,
    pub roh_env_max_delta: f32,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct NeuroproximalNei {
    pub cfg: NeiConfig,
}

impl NeuroproximalNei {
    fn norm_ratio(value: f32, max: f32) -> f32 {
        if max <= 0.0 {
            0.0
        } else {
            (value / max).max(0.0)
        }
    }

    fn norm_acoustic_db(db: f32, db_max: f32) -> f32 {
        if db_max <= 0.0 {
            0.0
        } else {
            let num = 10_f32.powf(db / 20.0);
            let den = 10_f32.powf(db_max / 20.0);
            (num / den).max(0.0)
        }
    }

    fn compute_eenv(&self, env: &EnvTelemetry) -> f32 {
        let e_rf = Self::norm_ratio(env.rf_power_density_mw_cm2, env.rf_power_density_max_mw_cm2);
        let e_ac = Self::norm_acoustic_db(env.sound_db_spl, env.sound_db_spl_max);
        let e_lux = Self::norm_ratio(env.lux, env.lux_max);
        let e_vib = Self::norm_ratio(env.vib_power, env.vib_power_max);
        let e_th = Self::norm_ratio(
            env.thermal_radiant_delta_c.abs(),
            env.thermal_radiant_delta_max_c,
        );
        self.cfg.w_rf * e_rf
            + self.cfg.w_acoustic * e_ac
            + self.cfg.w_lux * e_lux
            + self.cfg.w_vib * e_vib
            + self.cfg.w_th * e_th
    }

    fn roh_delta_from_eenv(&self, eenv: f32) -> f32 {
        let excess = (eenv - self.cfg.eenv_comfort).max(0.0);
        let raw = self.cfg.k_env * excess;
        raw.min(self.cfg.roh_env_max_delta).max(0.0)
    }
}

#[derive(Debug, Clone, Copy)]
pub enum NeiError {
    IdentityNotCanonical,
    PhysioAlreadyAtCeiling,
}

impl GuardKernel for NeuroproximalNei {
    type Input = EnvTelemetry;
    type Output = NeiVerdict;
    type Error = NeiError;

    fn evaluate(
        &self,
        id: &SovereignIdentity,
        input: Self::Input,
        state: &PhysioState,
        caps: &PhysioCaps,
    ) -> Result<(GuardVerdict, Self::Output, PhysioState), Self::Error> {
        if !id.is_canonical() {
            return Err(NeiError::IdentityNotCanonical);
        }
        if state.roh_scalar >= caps.roh_ceiling {
            return Err(NeiError::PhysioAlreadyAtCeiling);
        }

        let eenv = self.compute_eenv(&input);
        let delta = self.roh_delta_from_eenv(eenv);
        let new_roh = state.roh_scalar + delta;

        match new_roh
            .partial_cmp(&caps.roh_ceiling)
            .unwrap_or(Ordering::Greater)
        {
            Ordering::Greater => Ok((
                GuardVerdict::Deny,
                NeiVerdict::DenyEnvExceedsCorridor,
                *state,
            )),
            _ => {
                let mut new_state = *state;
                new_state.roh_scalar = new_roh;
                Ok((
                    GuardVerdict::Allow,
                    NeiVerdict::AllowWithinCorridor,
                    new_state,
                ))
            }
        }
    }
}
