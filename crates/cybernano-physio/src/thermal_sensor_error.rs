// destination: crates/cybernano-physio/src/thermal_sensor_error.rs
#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum SensorKind {
    InternalProbe,
    SkinThermistor,
    IRNonContact,
    AmbientShielded,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct SensorErrorConfig {
    pub sensor_kind: SensorKind,
    pub bias_min_c: f32,
    pub bias_max_c: f32,
    pub noise_bound_c: f32,
    pub gamma_radiant_c_per_unit: f32,
    pub gamma_aq_c_per_unit: f32,
    pub gamma_radiant_aq_c_per_unit: f32,
    pub r_min: f32,
    pub r_max: f32,
    pub q_min: f32,
    pub q_max: f32,
}

impl SensorErrorConfig {
    fn delta_env_max(&self, radiant: f32, aq: f32) -> f32 {
        let r = radiant.clamp(self.r_min, self.r_max);
        let q = aq.clamp(self.q_min, self.q_max);
        self.gamma_radiant_c_per_unit * r
            + self.gamma_aq_c_per_unit * q
            + self.gamma_radiant_aq_c_per_unit * r * q
    }

    pub fn error_bound(&self, radiant: f32, aq: f32) -> f32 {
        let delta_env = self.delta_env_max(radiant, aq);
        self.bias_max_c.abs() + self.noise_bound_c + delta_env
    }

    pub fn risk_upper(
        &self,
        measured_c: f32,
        radiant: f32,
        aq: f32,
    ) -> f32 {
        let e = self.error_bound(radiant, aq);
        measured_c + e
    }
}
