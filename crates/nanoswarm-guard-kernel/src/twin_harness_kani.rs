// destination-path: mk-bluebird/nanorobotics/crates/nanoswarm-guard-kernel/src/twin_harness_kani.rs
// license: MIT OR Apache-2.0
#![cfg(kani)]
#![forbid(unsafe_code)]
#![feature(rust_2024)]

extern crate twin_policy;

use twin_policy::{
    AlnIdentity, BostromAddress, HostDid, SimulationProofContext, TwinAdvisoryInput,
    TwinAdvisoryError, TwinSimulationResult, TwinSovereignGuard,
    EvidenceBundleId, HexString,
};

#[kani::proof]
fn twin_cannot_become_control_surface() {
    let sim_hash = HexString("00".to_string());
    let proof_hash = HexString("11".to_string());
    let evidence = EvidenceBundleId("0xroh01a3".to_string());

    let policy = TwinSovereignGuard::new_observer_only(sim_hash, proof_hash, evidence);

    let result = TwinSimulationResult {
        host_did: HostDid::ORGANIC,
        bostrom_address: BostromAddress::PRIMARY,
        aln_identity: AlnIdentity::PRIMARY,
        roh_global_max: kani::any(),
        min_margin_per_region: kani::any(),
    };

    let proof_ctx = SimulationProofContext {
        simulation_hash_kind: policy.simulation_hash_kind,
        simulation_hash_hex: policy.simulation_hash_hex.clone(),
        evidence_bundle_id: policy.evidence_bundle_id.clone(),
    };

    let adv = TwinAdvisoryInput::from_result(&policy, &result, &proof_ctx);

    match adv {
        Ok(input) => {
            assert!(policy.is_observe_only());
            assert!(input.roh_upper_bound >= 0.0);
        }
        Err(e) => {
            assert!(matches!(
                e,
                TwinAdvisoryError::PolicyViolation | TwinAdvisoryError::SovereignBindingMismatch
            ));
        }
    }
}
