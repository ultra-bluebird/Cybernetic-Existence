// mk-bluebird/nanorobotics/crates/nanoswarm-shared-control/src/lib.rs
#![forbid(unsafe_code)]

pub mod types;
pub mod barrier;
pub mod lyapunov;
pub mod supervisor;

pub use crate::types::{
    BostromAddress, HostDid, HostBinding, SwarmCommand, SwarmFormationMode, SwarmState,
    UnifiedSafetyAxes7Plus1,
};
pub use crate::barrier::{
    BarrierOutcome, ControlBarrierFunction, DensityBarrier, OrganCorridorBarrier,
    RiskOfHarmBarrier, ThermalBarrier,
};
pub use crate::lyapunov::{Lyapunov7Plus1, LyapunovConfig};
pub use crate::supervisor::{FuseDecision, SwarmSupervisoryController};
