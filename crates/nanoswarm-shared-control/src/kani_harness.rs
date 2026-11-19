// mk-bluebird/nanorobotics/crates/nanoswarm-shared-control/src/kani_harness.rs
#![cfg(kani)]
#![forbid(unsafe_code)]

use kani::any;
use nanoswarm_shared_control::{
    barrier::{DensityBarrier, OrganCorridorBarrier, RiskOfHarmBarrier, ThermalBarrier},
    lyapunov::{Lyapunov7Plus1, LyapunovConfig},
    supervisor::SwarmSupervisoryController,
    types::{
        BostromAddress, BiomarkerSnapshot, HostBinding, HostDid, SwarmCommand, SwarmFormationMode,
        SwarmState, UnifiedSafetyAxes7Plus1,
    },
};
use nalgebra::Vector3;

#[kani::proof]
fn fuse_preserves_lyapunov_and_roh() {
    let axes = UnifiedSafetyAxes7Plus1 {
        axes: [
            any::<f32>().abs().min(1.0),
            any::<f32>().abs().min(1.0),
            any::<f32>().abs().min(1.0),
            any::<f32>().abs().min(1.0),
            any::<f32>().abs().min(1.0),
            any::<f32>().abs().min(1.0),
            any::<f32>().abs().min(1.0),
            any::<f32>().abs().min(1.0),
        ],
    };

    let roh_scalar_pre = any::<f32>().abs().min(0.3);

    let state = SwarmState {
        position: Vector3::new(any::<f32>(), any::<f32>(), any::<f32>()),
        velocity: Vector3::new(any::<f32>(), any::<f32>(), any::<f32>()),
        local_density: any::<f32>().abs().min(1.0),
        local_temperature: any::<f32>().abs().min(42.0),
        distance_to_no_fly: any::<f32>().abs().min(10.0),
        unified_axes_7p1: axes,
        biomarkers: BiomarkerSnapshot {
            lifeforce_scalar: any::<f32>().abs().min(1.0),
            roh_scalar: roh_scalar_pre,
        },
    };

    let host_cmd = SwarmCommand {
        velocity: Vector3::new(any::<f32>(), any::<f32>(), any::<f32>()),
        formation: SwarmFormationMode::Stream,
        actuation_intensity: any::<f32>().abs().min(1.0),
    };

    let lyap_cfg = LyapunovConfig {
        weights: [1.0; 8],
        vmax: 1.0,
    };
    let lyap = Lyapunov7Plus1::new(lyap_cfg);

    let ctrl = SwarmSupervisoryController {
        host_binding: HostBinding {
            host_did: HostDid("did:vital:bostrom".to_owned()),
            bostrom_address: BostromAddress(
                "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_owned(),
            ),
            aln_clause: "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1".to_owned(),
        },
        lyapunov: lyap,
        roh_barrier_active: true,
        organ_barrier: OrganCorridorBarrier {
            d_min: 0.5,
            alpha_org: 1.0,
        },
        thermal_barrier: ThermalBarrier {
            t_max: 40.0,
            alpha_th: 1.0,
        },
        density_barrier: DensityBarrier {
            r_max: 1.0,
            alpha_dens: 1.0,
        },
        roh_barrier: RiskOfHarmBarrier {
            roh_max: 0.3,
            alpha_roh: 1.0,
        },
    };

    let (fused_cmd, _dec) = ctrl.fuse(&state, &host_cmd);

    let v_host = host_cmd.velocity.norm();
    let v_fused = fused_cmd.velocity.norm();

    assert!(v_fused <= v_host + 1.0e-6);
    assert!(ctrl.lyapunov.is_within_level_set(&state.unified_axes_7p1));
    assert!(state.biomarkers.roh_scalar <= ctrl.roh_barrier.roh_max + 1.0e-6);
}
