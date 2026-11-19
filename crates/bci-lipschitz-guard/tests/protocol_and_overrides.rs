
#![forbid(unsafe_code)]

use bcilipschitzguard::*;
use rohkerneltypes::RoHScalar;
use alncore::AlnScalar;
use neurorights_firewall::{NeurorightsPolicy, NeurorightsIntentSummary};

#[test]
fn protocol_measures_lipschitz_and_bounded_box() {
    let cfg = BciDecoderConfig {
        decoder_id: "motor-decoder-v1".to_string(),
        max_gain: 5.0,
        roh_ceiling: 0.3,
    };

    // Synthetic protocol data: EEG norms and motor intents.
    let eeg_norms: Vec<AlnScalar> = vec![0.1, 0.2, 0.25, 0.3];
    let intents: Vec<[AlnScalar; 3]> = vec![
        [0.05, 0.05, 0.05],
        [0.10, 0.10, 0.10],
        [0.12, 0.12, 0.12],
        [0.15, 0.15, 0.15],
    ];

    let measured_l = estimate_lipschitz_constant(&intents, &eeg_norms);
    let env = DecoderLipschitzEnvelope {
        lipschitz_constant: measured_l,
        input_norm_ceiling: 0.3,
        intent_box: MotorIntentBox {
            min_vec: [-0.3, -0.3, -0.3],
            max_vec: [0.3, 0.3, 0.3],
        },
    };

    let verdict = check_lipschitz_bound(&cfg, &env, measured_l);
    assert!(matches!(verdict, BciDecoderLipschitzGuardVerdict::Allow));
}

#[test]
fn hrv_leak_guard_denies_excessive_leakage() {
    let env = HrvLeakageEnvelope {
        neurorights_threshold_bits: 2.0,
        max_swarm_state_entropy_bits: 8.0,
        max_hrv_entropy_bits: 8.0,
    };

    let h_s: AlnScalar = 4.0;
    let h_hrv: AlnScalar = 4.0;
    let bound = hrv_mutual_information_bound(h_s, h_hrv);

    let summary = SwarmStateSummary {
        swarm_state_entropy_bits: h_s,
        hrv_entropy_bits: h_hrv,
        mutual_information_bound_bits: bound,
    };

    let verdict = evaluate_hrv_leakage(&env, &summary);
    assert!(matches!(verdict, HrvLeakGuardVerdict::Deny));
}

#[test]
fn free_energy_override_respects_non_rollback() {
    let cfg = RohFreeEnergyMappingConfig {
        roh_ceiling: 0.3,
        free_energy_scale: 1.0,
        non_rollback_weight: 0.5,
    };

    let roh: RoHScalar = 0.1;
    let policy = NeurorightsPolicy {
        policyid: "nr-1".to_string(),
        requirenondowngrade: true,
        requirenoinnergovernance: true,
        maxrohdelta: 0.1,
    };

    let intent = NeurorightsIntentSummary {
        intentid: "override-1".to_string(),
        woulddowngradeaugmentation: false,
        wouldenableinnergovernance: false,
        predictedrohdelta: 0.05,
    };

    let (decision, verdict) =
        generate_override_from_free_energy(&cfg, roh, &policy, &intent);

    assert!(decision.override_allowed);
    assert!(matches!(verdict, FreeEnergyOverrideVerdict::AllowOverride));
}
