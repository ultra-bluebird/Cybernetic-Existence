// crates/nanorobotics-fpot-adjoint/src/tumour_latency_controller.rs
// Dual-licensed: MIT OR Apache-2.0
// Rust edition: 2024, rust-version = "1.85"
// Kani verifier: 0.56.0 (non-optional)
// Asserts ALN.MIGRATION.CYBERCORE_AUTHORITY.v1 via HostSovereigntyBinding.

#![forbid(unsafe_code)]

use std::time::Duration;

use aln_governance::host_binding::HostSovereigntyBinding;
use aln_governance::roh::{GlobalRoH, RoHCeiling};
use advanced_safety_math::fokker_planck::{DensityField1D, FokkerPlanckParams};
use advanced_safety_math::latency_fp::{LatencyFpParams, LatencyRisk};
use nanorobotics_core::biospatial::{OrganCorridorId, VoxelIndex};
use nanorobotics_core::fpot::FpotParams;
use nanorobotics_core::roh_kernel::{RoHKernelInput, RoHKernelOutput};
use nanorobotics_core::telemetry::TumourBloodTelemetrySnapshot;
use nanorobotics_core::timegrid::{TimeGrid, TimeStep};

/// Control for nanoswarm drug release in tumour vs BLOOD under FPOTBayes corridors
/// with an adjoint-based gradient and a latency Fokker–Planck penalty.
/// This is a pure logic struct; no IO or side effects.
pub struct TumourLatencyController {
    pub host_binding: HostSovereigntyBinding,
    pub roh_ceiling: RoHCeiling,
    pub time_grid: TimeGrid,
    pub tumour_corridor: OrganCorridorId,
    pub blood_corridor: OrganCorridorId,
    pub fpot_params: FpotParams,
    pub fp_drug_params: FokkerPlanckParams,
    pub latency_fp_params: LatencyFpParams,
    pub latency_budget: Duration,
}

/// State of one optimisation horizon (forward PDE + backward adjoint + latency FP).
pub struct TumourLatencyState {
    pub drug_concentration: DensityField1D,
    pub adjoint_field: DensityField1D,
    pub latency_density: DensityField1D,
    pub roh_traj: Vec<GlobalRoH>,
    pub latency_risk_traj: Vec<LatencyRisk>,
}

/// Point-source control at a given time step (per nanoswarm microdepot).
#[derive(Clone)]
pub struct PointSourceControl {
    pub voxel: VoxelIndex,
    pub release_rate: f32,
}

pub struct PointSourceControlHorizon {
    pub controls: Vec<Vec<PointSourceControl>>, // time_grid.len() slices
}

impl TumourLatencyController {
    /// Construct a controller with invariants:
    /// - host_binding carries ALN.MIGRATION.CYBERCORE_AUTHORITY.v1 and the OrganicCPU DID.
    /// - roh_ceiling is exactly 0.30.
    /// - latency_budget encodes the 2-hop BCI→ALN corridor.
    pub fn new(
        host_binding: HostSovereigntyBinding,
        roh_ceiling: RoHCeiling,
        time_grid: TimeGrid,
        tumour_corridor: OrganCorridorId,
        blood_corridor: OrganCorridorId,
        fpot_params: FpotParams,
        fp_drug_params: FokkerPlanckParams,
        latency_fp_params: LatencyFpParams,
        latency_budget: Duration,
    ) -> Self {
        assert!(roh_ceiling.value <= 0.30_f32);
        assert!(host_binding.aln_migration_cybercore_authority_v1);
        TumourLatencyController {
            host_binding,
            roh_ceiling,
            time_grid,
            tumour_corridor,
            blood_corridor,
            fpot_params,
            fp_drug_params,
            latency_fp_params,
            latency_budget,
        }
    }

    /// Forward pass: integrate convection–diffusion–reaction with point sources
    /// and latency FP, compute RoH and latency risk trajectories.
    pub fn forward_pass(
        &self,
        snapshot: &TumourBloodTelemetrySnapshot,
        control: &PointSourceControlHorizon,
    ) -> TumourLatencyState {
        // Placeholder call-outs to already-implemented FPOTBayes and FP envelopes.
        // Assumes virtual-supercomputer-sim provides PDE stepping routines.
        let mut drug = DensityField1D::new(self.fp_drug_params.grid_len);
        let mut adjoint = DensityField1D::new(self.fp_drug_params.grid_len);
        let mut latency_density = DensityField1D::new(self.latency_fp_params.grid_len);

        let mut roh_traj = Vec::with_capacity(self.time_grid.len());
        let mut latency_risk_traj = Vec::with_capacity(self.time_grid.len());

        for (k, t) in self.time_grid.times().iter().enumerate() {
            let u_k = &control.controls[k];

            // 1. Convection–diffusion–reaction step for drug concentration.
            nanorobotics_core::pde::step_convection_diffusion_reaction(
                &mut drug,
                snapshot,
                u_k,
                &self.fp_drug_params,
            );

            // 2. Latency FP step for cyber-physical twin delay distribution.
            advanced_safety_math::latency_fp::step_latency_fp(
                &mut latency_density,
                &self.latency_fp_params,
            );

            // 3. Compute RoH slice from current drug field and host state.
            let roh_input = RoHKernelInput::from_tumour_blood(
                snapshot,
                &drug,
                self.tumour_corridor,
                self.blood_corridor,
            );
            let roh_out: RoHKernelOutput =
                nanorobotics_core::roh_kernel::compute_roh(&roh_input);
            assert!(roh_out.global.value <= self.roh_ceiling.value + 1.0e-6);
            roh_traj.push(roh_out.global);

            // 4. Compute latency risk from latency_density and corridor budget.
            let lr = advanced_safety_math::latency_fp::compute_latency_risk(
                &latency_density,
                self.latency_budget,
            );
            latency_risk_traj.push(lr);
        }

        TumourLatencyState {
            drug_concentration: drug,
            adjoint_field: adjoint,
            latency_density,
            roh_traj,
            latency_risk_traj,
        }
    }

    /// Backward pass: solve adjoint PDE for drug and latency FP adjoint, then
    /// return gradient of the objective w.r.t. point-source release rates.
    pub fn backward_gradient(
        &self,
        state: &TumourLatencyState,
        snapshot: &TumourBloodTelemetrySnapshot,
        control: &PointSourceControlHorizon,
    ) -> PointSourceControlHorizon {
        let mut grad: Vec<Vec<PointSourceControl>> =
            vec![Vec::new(); self.time_grid.len()];

        // Adjoint for spatial drug PDE (tumour vs BLOOD + RoH).
        nanorobotics_core::pde::solve_adjoint_convection_diffusion_reaction(
            &state.drug_concentration,
            &mut state.adjoint_field.clone(),
            snapshot,
            &self.fp_drug_params,
            self.tumour_corridor,
            self.blood_corridor,
        );

        // Adjoint for latency FP penalty.
        let mut latency_adj =
            DensityField1D::new(self.latency_fp_params.grid_len);
        advanced_safety_math::latency_fp::solve_latency_adjoint(
            &state.latency_density,
            &mut latency_adj,
            &self.latency_fp_params,
            self.latency_budget,
        );

        // Gradient: adjoint evaluated at point sources + latency penalty term.
        for (k, controls_k) in control.controls.iter().enumerate() {
            let mut grad_k = Vec::with_capacity(controls_k.len());
            for ps in controls_k {
                let p_val =
                    nanorobotics_core::pde::adjoint_value_at_voxel(
                        &state.adjoint_field,
                        ps.voxel,
                    );
                let latency_pen =
                    advanced_safety_math::latency_fp::gradient_wrt_release(
                        &latency_adj,
                        ps.release_rate,
                    );
                grad_k.push(PointSourceControl {
                    voxel: ps.voxel,
                    release_rate: p_val + latency_pen,
                });
            }
            grad[k] = grad_k;
        }

        PointSourceControlHorizon { controls: grad }
    }
}
