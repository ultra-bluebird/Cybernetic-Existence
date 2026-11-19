// Path: crates/sovereign-decision-pipeline/src/kani_pipeline.rs
// Edition 2024, Kani-only module.
#![forbid(unsafe_code)]
#![cfg(feature = "kani")]

extern crate alloc;

use kani::any;
use crate::model::{PsychLoadBand, SovereignVerdict};
use crate::snapshot::{
    BiocompatibilityWeights, EvolutionMetrics, ResourceScalars, TelemetrySnapshot,
    GLOBAL_ROH_CEILING, HOST_DID, PRIMARY_BOSTROM_ADDRESS,
};
use crate::{
    evaluate_pipeline, CognitiveCandyHostProfile, CognitiveCandyInput, LifeforceOtaThresholds,
    PipelineConfig,
};

fn canonical_weights() -> BiocompatibilityWeights {
    // Simple equal weights for proof; production code can load from ALN.
    BiocompatibilityWeights {
        w_cns_delta_t: 0.1,
        w_mito_delta_psi: 0.1,
        w_nad_ratio: 0.1,
        w_hrv_ms: 0.1,
        w_s_resp: 0.1,
        w_il6_pg_ml: 0.1,
        w_r_neuro: 0.1,
        w_h_env: 0.1,
        w_microcooler_duty: 0.1,
        w_eco_budget: 0.1,
    }
}

fn base_snapshot() -> TelemetrySnapshot {
    use crate::snapshot::{HostNormCorridor, TenTagBundle};
    use heapless::String;

    let mut did = String::<64>::new();
    did.push_str(HOST_DID).unwrap();
    let mut addr = String::<64>::new();
    addr.push_str(PRIMARY_BOSTROM_ADDRESS).unwrap();

    TelemetrySnapshot {
        host_did: did,
        bostrom_address: addr,
        ten_tags: TenTagBundle {
            cns_delta_t: 0.0,
            mito_delta_psi: 0.0,
            nad_ratio: 0.0,
            hrv_ms: 0.0,
            s_resp: 0.0,
            il6_pg_ml: 0.0,
            r_neuro: 0.0,
            h_env: 0.0,
            microcooler_duty: 0.0,
            eco_budget: 0.0,
        },
        norm_corridor: HostNormCorridor {
            cns_delta_t_max: 1.0,
            mito_delta_psi_max: 1.0,
            nad_ratio_min: 0.0,
            nad_ratio_max: 1.0,
            hrv_ms_min: 0.0,
            s_resp_max: 1.0,
            il6_pg_ml_max: 1.0,
            r_neuro_max: 1.0,
            h_env_max: 1.0,
            microcooler_duty_max: 1.0,
            eco_budget_min: 0.0,
        },
        biocompat_weights: canonical_weights(),
        roh_scalar: 0.0,
        lifeforce_scalar: 0.5,
        lifeforce_floor: 0.3,
        resources: ResourceScalars {
            lifeforce_scalar: 0.5,
            blood_scalar: 0.5,
            protein_scalar: 0.5,
        },
        prev_evolution: EvolutionMetrics {
            kf: 0.5,
            continuity: 0.5,
            roh: 0.2,
        },
        next_evolution: EvolutionMetrics {
            kf: 0.52,
            continuity: 0.52,
            roh: 0.25,
        },
        psych_load_level: 0.5,
    }
}

/// Harness 1: Hard RoH veto and corridor invariants.
///
/// If we force roh_i_increment > roh_ceiling, the pipeline must AutoDeny.
#[kani::proof]
fn proof_cognitive_roh_veto_enforced() {
    let mut snap = base_snapshot();
    let cfg = PipelineConfig {
        candy_profile: CognitiveCandyHostProfile {
            alpha_psych_risk: 1.0,
            roh_ceiling: GLOBAL_ROH_CEILING,
            psych_load_floor: 0.30,
            psych_load_comfort_max: 0.65,
        },
        ota_thresholds: LifeforceOtaThresholds {
            lifeforce_floor: 0.35,
            blood_floor: 0.25,
            protein_floor: 0.20,
        },
    };

    // Base snapshot passes all biocompat + OTA thresholds.
    snap.roh_scalar = 0.10;
    snap.lifeforce_scalar = 0.5;
    snap.resources.lifeforce_scalar = 0.5;
    snap.resources.blood_scalar = 0.5;
    snap.resources.protein_scalar = 0.5;

    // Symbolic risk benefit scalars.
    let ri: f32 = any();
    let pi: f32 = any();

    // Force RoH increment above ceiling.
    let roh_i: f32 = any();
    kani::assume(roh_i > cfg.candy_profile.roh_ceiling);

    let candy_input = CognitiveCandyInput {
        ri_neurorights: ri,
        pi_psych_risk: pi,
        roh_i_increment: roh_i,
        psych_load_level: snap.psych_load_level,
        lifeforce_ok: true,
        neurorights_ok: true,
    };

    let (verdict, _) = evaluate_pipeline(&cfg, &snap, &candy_input);
    assert!(matches!(verdict, SovereignVerdict::AutoDeny));
}

/// Harness 2: Biocompat score and admission corridor.
///
/// If score < 0.70, or Lifeforce margin < 0.05, pipeline must AutoDeny.
#[kani::proof]
fn proof_biocompat_admission_corridor() {
    let mut snap = base_snapshot();
    let cfg = PipelineConfig {
        candy_profile: CognitiveCandyHostProfile {
            alpha_psych_risk: 0.5,
            roh_ceiling: GLOBAL_ROH_CEILING,
            psych_load_floor: 0.30,
            psych_load_comfort_max: 0.65,
        },
        ota_thresholds: LifeforceOtaThresholds {
            lifeforce_floor: snap.lifeforce_floor,
            blood_floor: 0.25,
            protein_floor: 0.20,
        },
    };

    // Construct a penalty pattern that forces a low score.
    snap.ten_tags.cns_delta_t = 1.0;
    snap.ten_tags.il6_pg_ml = 1.0;
    snap.ten_tags.h_env = 1.0;

    // Also shrink lifeforce margin below 0.05 above floor.
    snap.lifeforce_scalar = snap.lifeforce_floor + 0.01;

    let candy_input = CognitiveCandyInput {
        ri_neurorights: 1.0,
        pi_psych_risk: 0.0,
        roh_i_increment: 0.0,
        psych_load_level: snap.psych_load_level,
        lifeforce_ok: true,
        neurorights_ok: true,
    };

    let (verdict, diag) = evaluate_pipeline(&cfg, &snap, &candy_input);
    assert!(diag.biocompat_score <= 0.70 + 1e-3 || !diag.biocompat_admissible);
    assert!(matches!(verdict, SovereignVerdict::AutoDeny));
}

/// Harness 3: Evolution monotonicity.
///
/// If KF or continuity fail to grow by 0.01, final verdict cannot be AutoAllow
/// regardless of CognitiveCandy result.
#[kani::proof]
fn proof_evolution_monotonicity() {
    let mut snap = base_snapshot();
    let cfg = PipelineConfig {
        candy_profile: CognitiveCandyHostProfile {
            alpha_psych_risk: 0.0,
            roh_ceiling: GLOBAL_ROH_CEILING,
            psych_load_floor: 0.30,
            psych_load_comfort_max: 0.65,
        },
        ota_thresholds: LifeforceOtaThresholds {
            lifeforce_floor: 0.35,
            blood_floor: 0.25,
            protein_floor: 0.20,
        },
    };

    // Force a non-growing evolution step.
    snap.prev_evolution.kf = 0.5;
    snap.prev_evolution.continuity = 0.5;

    let kf_next: f32 = any();
    let c_next: f32 = any();

    // Assume at least one of the deltas fails the 0.01 growth requirement.
    let dk = kf_next - snap.prev_evolution.kf;
    let dc = c_next - snap.prev_evolution.continuity;
    kani::assume(dk < 0.01 || dc < 0.01);

    snap.next_evolution.kf = kf_next;
    snap.next_evolution.continuity = c_next;
    snap.next_evolution.roh = snap.prev_evolution.roh + 0.01;
    kani::assume(snap.next_evolution.roh <= GLOBAL_ROH_CEILING);

    // CognitiveCandy is configured for a positive net benefit in the preferred band.
    snap.psych_load_level = 0.5;
    let candy_input = CognitiveCandyInput {
        ri_neurorights: 1.0,
        pi_psych_risk: 0.0,
        roh_i_increment: 0.0,
        psych_load_level: snap.psych_load_level,
        lifeforce_ok: true,
        neurorights_ok: true,
    };

    let (verdict, _) = evaluate_pipeline(&cfg, &snap, &candy_input);
    // AutoAllow is only legal if evolution verdict was Allow; with growth failure,
    // orchestrator must downgrade to Brake or Deny.
    assert!(!matches!(verdict, SovereignVerdict::AutoAllow));
}
