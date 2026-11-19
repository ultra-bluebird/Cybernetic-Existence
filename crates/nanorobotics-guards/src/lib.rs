//! Nanorobotics Guards: host-sovereign nanoswarm and bioscale guard kernels.
//!
//! This crate provides hardware-level and software-level guard functions that enforce
//! neurorights constraints, pain/fear clamping, lifeforce corridors, hemodynamic and
//! lymphatic safety envelopes, RoH emergency ceilings, and safety invariants before
//! any nanoswarm or related actuation can proceed.

#![forbid(unsafe_code)]
#![deny(warnings)]

pub mod neurorights;
pub mod pain_fear_clamp;
pub mod safety_invariants;
pub mod guard_orchestrator;

// Nanoswarm detox / lifeforce corridor guard.
pub mod detox_lifeforce_guard;

// Hemodynamic, lymphatic, venous, and RoH emergency guards.
pub mod hemodynamic_lattice_guard;
pub mod lymphatic_clearance_guard;
pub mod venous_valve_guard;
pub mod roh_emergency_guard;

// Neurorights and consent surfaces.
pub use neurorights::{ConsentRecord, NeurorightsEnforcer, NeurorightsProfile};

// Pain / fear clamp guard surfaces.
pub use pain_fear_clamp::{ClampFactor, NociceptiveIndex, PainFearClamp};

// Generic safety invariant checker.
pub use safety_invariants::{InvariantChecker, SafetyInvariant, ViolationReport};

// High-level guard orchestrator for composing decisions.
pub use guard_orchestrator::{GuardContext, GuardDecision, GuardOrchestrator};

// Detox lifeforce guard surfaces and sovereign bindings.
pub use detox_lifeforce_guard::{
    ALNMIGRATIONCYBERCOREAUTHORITYV1,
    BOSTROMADDRESSPRIMARY,
    DetoxBoundCoeffs,
    DetoxLifeforceGuard,
    DetoxLifeforceGuardError,
    DetoxLifeforceVerdict,
    DetoxMissionEnvelope,
    HOSTDID,
    HostSovereigntyBinding,
    LifeforceFloors,
    LifeforceSessionState,
    ROHCEILINGGLOBAL,
};

// Hemodynamic lattice guard types and helpers.
pub use hemodynamic_lattice_guard::{
    HemodynamicState,
    HemodynamicVerdict,
    compose_verdicts,
    density_guard,
    wss_guard,
};

// Lymphatic clearance guard surfaces.
pub use lymphatic_clearance_guard::{
    LymphState,
    LymphaticVerdict,
    evaluate_lymphatic_clearance,
};

// Venous valve guard surfaces.
pub use venous_valve_guard::{
    ValveMeta,
    VenousValveVerdict,
    evaluate_valve_segment,
};

// RoH emergency guard parameters and helpers.
pub use roh_emergency_guard::{
    EmergencyRohParams,
    effective_roh_ceiling,
};
