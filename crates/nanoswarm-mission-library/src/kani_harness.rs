// mk-bluebird/nanorobotics/crates/nanoswarm-mission-library/src/kani_harness.rs
#![cfg(kani)]
#![forbid(unsafe_code)]

use kani::any;
use nanoswarm_mission_library::{
    SwarmEnvelopeSet, SwarmMissionKind, SwarmMissionSpec, VirtualTwinCoherenceProof,
};
use ordered_float::OrderedFloat;

#[kani::proof]
fn virtual_twin_coherence_enforces_roh_and_lyapunov() {
    let vmax = any::<f32>().abs().min(1.2);
    let roh_max = any::<f32>().abs().min(0.5);

    let proof = VirtualTwinCoherenceProof {
        lyapunov_vmax_7p1: OrderedFloat(vmax),
        roh_global_max: OrderedFloat(roh_max),
    };

    let envelopes = SwarmEnvelopeSet {
        organ_corridor_id: "heart.lv.v1".to_owned(),
        thermal_envelope_id: "nano.thermal.v1".to_owned(),
        density_envelope_id: "density.risk.v1".to_owned(),
        evidence_bundle_ids: [
            "a1f3c9b2".to_owned(),
            "4be79d01".to_owned(),
            "9cd4a7e8".to_owned(),
            "2f8c6b44".to_owned(),
            "7e1da2ff".to_owned(),
            "5b93e0c3".to_owned(),
            "d0174aac".to_owned(),
            "6ac2f9d9".to_owned(),
            "c4e61b20".to_owned(),
            "8f09d5ee".to_owned(),
        ],
    };

    let spec = SwarmMissionSpec {
        kind: SwarmMissionKind::MicrovascularRecanalization,
        envelopes,
        twin_proof: proof,
    };

    if spec.is_admissible() {
        assert!(spec.twin_proof.lyapunov_vmax_7p1.into_inner() <= 1.0 + 1.0e-6);
        assert!(spec.twin_proof.roh_global_max.into_inner() <= 0.3 + 1.0e-6);
    }
}
