// Filename: mk-bluebird/nanorobotics/crates/nanorobotics-guards/src/guards_impl.rs
// Destination: mk-bluebird/nanorobotics

#![forbid(unsafe_code)]

use crate::corridor_traits::{CorridorGuard, GuardState};
use crate::verdict::Verdict;
use enum_dispatch::enum_dispatch;

pub struct WssGuard;
pub struct DensityGuard;
pub struct ThermalGuard;
pub struct ImmuneGuard;

impl CorridorGuard for WssGuard {
    fn evaluate(&self, state: &GuardState) -> Verdict {
        if state.wss > 1.0 {
            Verdict::Deny
        } else {
            Verdict::Allow
        }
    }
}

impl CorridorGuard for DensityGuard {
    fn evaluate(&self, state: &GuardState) -> Verdict {
        if state.density > 1.0 {
            Verdict::Brake
        } else {
            Verdict::Allow
        }
    }
}

impl CorridorGuard for ThermalGuard {
    fn evaluate(&self, state: &GuardState) -> Verdict {
        if state.thermal > 1.0 {
            Verdict::Brake
        } else {
            Verdict::Allow
        }
    }
}

impl CorridorGuard for ImmuneGuard {
    fn evaluate(&self, state: &GuardState) -> Verdict {
        if state.immune > 1.0 {
            Verdict::Deny
        } else {
            Verdict::Allow
        }
    }
}

#[enum_dispatch(CorridorGuard)]
pub enum GuardDispatch {
    WssGuard,
    DensityGuard,
    ThermalGuard,
    ImmuneGuard,
}
