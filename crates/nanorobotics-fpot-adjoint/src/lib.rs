// crates/nanorobotics-fpot-adjoint/src/lib.rs
// Dual-licensed: MIT OR Apache-2.0
// Rust edition: 2024, rust-version = "1.85"
// Asserts ALN.MIGRATION.CYBERCORE_AUTHORITY.v1 and host-local sovereignty.
// Kani 0.56.0 required via dev-dependency, harnesses live in kani_latency.rs.

#![forbid(unsafe_code)]

pub mod tumour_latency_controller;

use std::time::Duration;

use aln_governance::host_binding::HostSovereigntyBinding;
use aln_governance::provenance::{DataOrigin, CalibrationStage, RequiresEmpirical};
use aln_governance::runtime_mode::{RuntimeMode, SimulationMode};
use aln_governance::roh::{GlobalRoH, RoHCeiling};

use nanorobotics_core::fpot::FpotParams;
use nanorobotics_core::telemetry::TumourBloodTelemetrySnapshot;
use nanorobotics_core::biospatial::{OrganCorridorId, VoxelIndex};
use nanorobotics_core::roh_kernel::{RoHKernelInput, RoHKernelOutput};

use advanced_safety_math::fokker_planck::{DensityField1D, FokkerPlanckParams};
use advanced_safety_math::latency_fp::{LatencyFpParams, LatencyRisk};

pub use tumour_latency_controller::{
    TumourLatencyController,
    TumourLatencyState,
    PointSourceControl,
    PointSourceControlHorizon,
};

/// Marker struct tying this crate's FPOT adjoint logic to Cybercore authority and
/// runtime mode semantics. Pure metadata, no IO.
#[derive(Clone)]
pub struct FpotAdjointContext {
    pub host_binding: HostSovereigntyBinding,
    pub roh_ceiling: RoHCeiling,
    pub runtime_mode: RuntimeMode,
}

impl FpotAdjointContext {
    /// Construct a context with hard sovereignty and RoH invariants.
    ///
    /// Invariants:
    /// - host_binding asserts ALN.MIGRATION.CYBERCORE_AUTHORITY.v1 and matches OrganicCPU DID.
    /// - roh_ceiling.value == 0.30.
    /// - runtime_mode is either SyntheticTrusted or ClinicalGuarded.
    pub fn new(host_binding: HostSovereigntyBinding,
               roh_ceiling: RoHCeiling,
               runtime_mode: RuntimeMode) -> Self {
        assert!(host_binding.aln_migration_cybercore_authority_v1);
        assert!(host_binding.host_did == "OrganicCPU");
        assert!(host_binding.bostrom_address == "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7");
        assert!((roh_ceiling.value - 0.30_f32).abs() < 1.0e-6);

        match runtime_mode.simulation_mode {
            SimulationMode::SyntheticTrusted | SimulationMode::ClinicalGuarded => {}
        }

        FpotAdjointContext {
            host_binding,
            roh_ceiling,
            runtime_mode,
        }
    }

    /// Enforce RequiresEmpirical for FPOTBayes parameters in ClinicalGuarded mode.
    ///
    /// This is the type-level safety gate: no synthetic params are allowed when
    /// runtime_mode is ClinicalGuarded. In SyntheticTrusted mode, synthetic
    /// params are permitted but cannot be used for clinical ALN shards.
    pub fn require_empirical_params<P>(&self, params: &P) -> Result<(), &'static str>
    where
        P: RequiresEmpirical,
    {
        match self.runtime_mode.simulation_mode {
            SimulationMode::SyntheticTrusted => Ok(()),
            SimulationMode::ClinicalGuarded => params.ensure_empirical()
                .map_err(|_| "Non-empirical FPOTBayes params in ClinicalGuarded mode"),
        }
    }
}

/// Convenience constructor for a tumour latency controller under this context.
///
/// This keeps all FPOTBayes wiring host-local and sovereignty-bound, and does
/// not perform any IO or network calls.
pub fn make_tumour_latency_controller(
    ctx: &FpotAdjointContext,
    tumour_corridor: OrganCorridorId,
    blood_corridor: OrganCorridorId,
    fpot_params: FpotParams,
    fp_drug_params: FokkerPlanckParams,
    latency_fp_params: LatencyFpParams,
    latency_budget: Duration,
) -> Result<TumourLatencyController, &'static str> {
    // Enforce empirical provenance when required.
    ctx.require_empirical_params(&fpot_params)?;
    ctx.require_empirical_params(&fp_drug_params)?;
    ctx.require_empirical_params(&latency_fp_params)?;

    let controller = TumourLatencyController::new(
        ctx.host_binding.clone(),
        ctx.roh_ceiling,
        nanorobotics_core::timegrid::TimeGrid::default(), // caller usually overrides
        tumour_corridor,
        blood_corridor,
        fpot_params,
        fp_drug_params,
        latency_fp_params,
        latency_budget,
    );

    Ok(controller)
}

/// Thin wrapper: run forward+backward once and return gradient, checking RoH.
/// This is pure logic and suitable for Kani harnesses.
pub fn tumour_latency_step(
    ctx: &FpotAdjointContext,
    snapshot: &TumourBloodTelemetrySnapshot,
    controller: &TumourLatencyController,
    control: &PointSourceControlHorizon,
) -> (TumourLatencyState, PointSourceControlHorizon, GlobalRoH) {
    let state = controller.forward_pass(snapshot, control);
    let grad = controller.backward_gradient(&state, snapshot, control);

    let roh_next = state
        .roh_traj
        .last()
        .cloned()
        .unwrap_or(GlobalRoH { value: 0.0 });

    assert!(roh_next.value <= ctx.roh_ceiling.value + 1.0e-6);

    (state, grad, roh_next)
}
