//! Nanorobotics Scheduler: Duty-cycle, thermal, and energy-aware swarm orchestration.
//!
//! This crate provides scheduling primitives that respect HostBudget constraints,
//! thermodynamic envelopes, and neurorights safety corridors. All scheduling decisions
//! are deterministic, auditable, and reversible only through explicit consent.

pub mod duty_cycle;
pub mod thermal_guard;
pub mod energy_allocator;
pub mod scheduler_core;

pub use duty_cycle::{DutyCycleConfig, DutyCycleState, DutyScheduler};
pub use thermal_guard::{ThermalGuard, ThermalEnvelope, TemperatureReading};
pub use energy_allocator::{EnergyAllocator, EnergyBudget, PowerProfile};
pub use scheduler_core::{ScheduleRequest, ScheduleDecision, SwarmScheduler};
