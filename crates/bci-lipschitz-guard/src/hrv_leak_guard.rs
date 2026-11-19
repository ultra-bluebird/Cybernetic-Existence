
use serde::{Deserialize, Serialize};
use alncore::AlnScalar;

/// Envelope for permissible information leakage through HRV.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HrvLeakageEnvelope {
    pub neurorights_threshold_bits: AlnScalar,
    pub max_swarm_state_entropy_bits: AlnScalar,
    pub max_hrv_entropy_bits: AlnScalar,
}

/// Summary of swarm state and HRV metric distribution.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwarmStateSummary {
    pub swarm_state_entropy_bits: AlnScalar,
    pub hrv_entropy_bits: AlnScalar,
    pub mutual_information_bound_bits: AlnScalar,
}

/// Verdict for HRV leak guard.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum HrvLeakGuardVerdict {
    Allow,
    Warn,
    Deny,
}

/// Compute a conservative mutual-information leakage bound I(S;HRV) using
/// a simple entropy-based inequality I(S;HRV) <= min(H(S), H(HRV)).
pub fn hrv_mutual_information_bound(
    swarm_state_entropy_bits: AlnScalar,
    hrv_entropy_bits: AlnScalar,
) -> AlnScalar {
    swarm_state_entropy_bits.min(hrv_entropy_bits)
}

/// Evaluate leakage against neurorights threshold; deny if mutual information
/// exceeds neurorights envelope.
pub fn evaluate_hrv_leakage(
    env: &HrvLeakageEnvelope,
    summary: &SwarmStateSummary,
) -> HrvLeakGuardVerdict {
    if summary.mutual_information_bound_bits > env.neurorights_threshold_bits {
        return HrvLeakGuardVerdict::Deny;
    }

    if summary.mutual_information_bound_bits
        > 0.5 * env.neurorights_threshold_bits
    {
        return HrvLeakGuardVerdict::Warn;
    }

    HrvLeakGuardVerdict::Allow
}

#[cfg(kani)]
mod hrv_leak_kani {
    use super::*;
    use kani::any;

    #[kani::proof]
    pub fn mutual_information_never_exceeds_min_entropy() {
        let h_s: AlnScalar = any();
        let h_hrv: AlnScalar = any();
        kani::assume(h_s >= 0.0);
        kani::assume(h_hrv >= 0.0);
        kani::assume(h_s <= 16.0);
        kani::assume(h_hrv <= 16.0);

        let bound = hrv_mutual_information_bound(h_s, h_hrv);
        assert!(bound <= h_s);
        assert!(bound <= h_hrv);
    }

    #[kani::proof]
    pub fn leak_guard_respects_neurorights_threshold() {
        let neurorights_threshold_bits: AlnScalar = any();
        kani::assume(neurorights_threshold_bits > 0.0);
        kani::assume(neurorights_threshold_bits <= 4.0);

        let env = HrvLeakageEnvelope {
            neurorights_threshold_bits,
            max_swarm_state_entropy_bits: 16.0,
            max_hrv_entropy_bits: 16.0,
        };

        let mi_bits: AlnScalar = any();
        kani::assume(mi_bits >= 0.0);
        kani::assume(mi_bits <= 16.0);

        let summary = SwarmStateSummary {
            swarm_state_entropy_bits: 8.0,
            hrv_entropy_bits: 8.0,
            mutual_information_bound_bits: mi_bits,
        };

        let verdict = evaluate_hrv_leakage(&env, &summary);
        if mi_bits > neurorights_threshold_bits {
            assert!(matches!(verdict, HrvLeakGuardVerdict::Deny));
        }
    }
}
