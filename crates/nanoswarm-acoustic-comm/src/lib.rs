// Path: crates/nanoswarm-acoustic-comm/src/lib.rs
#![forbid(unsafe_code)]
#![deny(warnings)]

use core::f64;
use serde::{Deserialize, Serialize};

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCOREAUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct AcousticCommCorridor {
    pub mi_ceiling: f64,
    pub bbb_integrity_floor: f64,
    pub carrier_frequency_mhz: f64,
    pub bandwidth_mhz: f64,
    pub duty_cycle_max: f64,
    pub snr_min_db: f64,
    pub capacity_safe_floor_bps: f64,
}

impl AcousticCommCorridor {
    pub const fn default() -> Self {
        Self {
            mi_ceiling: 1.3,
            bbb_integrity_floor: 0.85,
            carrier_frequency_mhz: 1.0,
            bandwidth_mhz: 0.5,
            duty_cycle_max: 0.10,
            snr_min_db: 6.0,
            capacity_safe_floor_bps: 100.0,
        }
    }

    pub fn validate(&self) -> bool {
        self.mi_ceiling > 0.0
            && (self.bbb_integrity_floor > 0.0 && self.bbb_integrity_floor <= 1.0)
            && self.carrier_frequency_mhz > 0.0
            && self.bandwidth_mhz > 0.0
            && (self.duty_cycle_max > 0.0 && self.duty_cycle_max <= 1.0)
            && self.capacity_safe_floor_bps > 0.0
    }
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct AcousticCommPlan {
    pub mechanical_index: f64,
    pub bbb_integrity_score: f64,
    pub bandwidth_mhz: f64,
    pub duty_cycle: f64,
    pub snr_db: f64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AcousticCommVerdict {
    Allowed,
    Braked,
    Denied,
}

/// Convert dB SNR into linear S/N ratio.
fn snr_linear(snr_db: f64) -> f64 {
    f64::powf(10.0, snr_db / 10.0)
}

/// Shannon capacity in bits per second for band-limited AWGN channel.
fn shannon_capacity_bps(bandwidth_hz: f64, snr_linear: f64) -> f64 {
    if bandwidth_hz <= 0.0 || snr_linear <= 0.0 {
        0.0
    } else {
        bandwidth_hz * f64::log2(1.0 + snr_linear)
    }
}

/// Evaluate acoustic comm plan against corridor; fail-closed under MI/BBB.
pub fn check_acoustic_comm(
    corridor: &AcousticCommCorridor,
    plan: &AcousticCommPlan,
) -> (AcousticCommVerdict, f64) {
    if !corridor.validate() {
        return (AcousticCommVerdict::Denied, 0.0);
    }

    if plan.mechanical_index > corridor.mi_ceiling {
        return (AcousticCommVerdict::Denied, 0.0);
    }
    if plan.bbb_integrity_score < corridor.bbb_integrity_floor {
        return (AcousticCommVerdict::Denied, 0.0);
    }

    let duty = if plan.duty_cycle < 0.0 {
        0.0
    } else if plan.duty_cycle > 1.0 {
        1.0
    } else {
        plan.duty_cycle
    };

    if duty > corridor.duty_cycle_max {
        // Above corridor duty cycle: at most "Braked" with reduced duty.
        let capped_duty = corridor.duty_cycle_max;
        let bw_hz = plan.bandwidth_mhz.max(0.0) * 1.0e6 * capped_duty;
        let snr_lin = snr_linear(plan.snr_db.max(0.0));
        let cap = shannon_capacity_bps(bw_hz, snr_lin);
        return (AcousticCommVerdict::Braked, cap);
    }

    let bw_hz = plan.bandwidth_mhz.max(0.0) * 1.0e6 * duty;
    let snr_lin = snr_linear(plan.snr_db.max(0.0));
    let cap = shannon_capacity_bps(bw_hz, snr_lin);

    if cap < corridor.capacity_safe_floor_bps {
        (AcousticCommVerdict::Denied, cap)
    } else {
        (AcousticCommVerdict::Allowed, cap)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn corridor_validates() {
        let c = AcousticCommCorridor::default();
        assert!(c.validate());
    }

    #[test]
    fn mi_or_bbb_violation_denies() {
        let c = AcousticCommCorridor::default();
        let plan_bad_mi = AcousticCommPlan {
            mechanical_index: 2.0,
            bbb_integrity_score: 0.9,
            bandwidth_mhz: 0.5,
            duty_cycle: 0.05,
            snr_db: 10.0,
        };
        let plan_bad_bbb = AcousticCommPlan {
            mechanical_index: 1.0,
            bbb_integrity_score: 0.5,
            bandwidth_mhz: 0.5,
            duty_cycle: 0.05,
            snr_db: 10.0,
        };
        assert_eq!(
            check_acoustic_comm(&c, &plan_bad_mi).0,
            AcousticCommVerdict::Denied
        );
        assert_eq!(
            check_acoustic_comm(&c, &plan_bad_bbb).0,
            AcousticCommVerdict::Denied
        );
    }

    #[test]
    fn allowed_plan_exceeds_capacity_floor() {
        let c = AcousticCommCorridor::default();
        let plan = AcousticCommPlan {
            mechanical_index: 1.0,
            bbb_integrity_score: 0.9,
            bandwidth_mhz: 0.5,
            duty_cycle: 0.05,
            snr_db: 12.0,
        };
        let (v, cap) = check_acoustic_comm(&c, &plan);
        assert_eq!(v, AcousticCommVerdict::Allowed);
        assert!(cap >= c.capacity_safe_floor_bps);
    }
}
