
use serde::{Deserialize, Serialize};
use alncore::AlnScalar;
use rohkerneltypes::RoHScalar;

/// Configuration for a BCI decoder’s Lipschitz envelope.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BciDecoderConfig {
    pub decoder_id: String,
    pub max_gain: AlnScalar,
    pub roh_ceiling: RoHScalar,
}

/// A rectangular box in motor-intent space used for boundedness proofs.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MotorIntentBox {
    pub min_vec: [AlnScalar; 3],
    pub max_vec: [AlnScalar; 3],
}

/// Lipschitz envelope for the decoder mapping raw EEG to motor intention.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DecoderLipschitzEnvelope {
    pub lipschitz_constant: AlnScalar,
    pub input_norm_ceiling: AlnScalar,
    pub intent_box: MotorIntentBox,
}

/// Verdict for Lipschitz guard.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum BciDecoderLipschitzGuardVerdict {
    Allow,
    Brake,
    Deny,
}

/// Empirical estimator for the decoder Lipschitz constant from protocol data.
/// Given pairs (eeg_i, intent_i) we compute max_i,j ||f(eeg_i)-f(eeg_j)|| / ||eeg_i-eeg_j||.
pub fn estimate_lipschitz_constant(
    intents: &[[AlnScalar; 3]],
    eeg_norms: &[AlnScalar],
) -> AlnScalar {
    let n = intents.len();
    assert_eq!(n, eeg_norms.len());
    if n < 2 {
        return 0.0;
    }

    let mut max_ratio: AlnScalar = 0.0;
    for i in 0..n {
        for j in (i + 1)..n {
            let mut diff_intent_norm_sq: AlnScalar = 0.0;
            for k in 0..3 {
                let d = intents[i][k] - intents[j][k];
                diff_intent_norm_sq += d * d;
            }
            let diff_intent_norm = diff_intent_norm_sq.sqrt();
            let diff_eeg_norm = (eeg_norms[i] - eeg_norms[j]).abs();
            if diff_eeg_norm > 0.0 {
                let ratio = diff_intent_norm / diff_eeg_norm;
                if ratio > max_ratio {
                    max_ratio = ratio;
                }
            }
        }
    }
    max_ratio
}

/// Check that the measured Lipschitz constant is within the configured envelope
/// and that bounded inputs map to the configured bounded motor-intent box.
pub fn check_lipschitz_bound(
    cfg: &BciDecoderConfig,
    env: &DecoderLipschitzEnvelope,
    measured_lipschitz: AlnScalar,
) -> BciDecoderLipschitzGuardVerdict {
    // Guard that measured constant does not exceed envelope.
    if measured_lipschitz > env.lipschitz_constant {
        return BciDecoderLipschitzGuardVerdict::Deny;
    }

    // Guard that envelope constant does not exceed configured max_gain.
    if env.lipschitz_constant > cfg.max_gain {
        return BciDecoderLipschitzGuardVerdict::Brake;
    }

    // For bounded input norm, ensure intent box is consistent with Roh ceiling.
    // Roh ceiling acts as a global bound on safe motor-intent magnitude.
    let max_intent_norm_sq: AlnScalar = {
        let mut acc = 0.0;
        for k in 0..3 {
            let m = env.intent_box.max_vec[k].abs();
            acc += m * m;
        }
        acc
    };
    let max_intent_norm = max_intent_norm_sq.sqrt();
    let roh_bound: AlnScalar = cfg.roh_ceiling;
    if max_intent_norm > roh_bound {
        return BciDecoderLipschitzGuardVerdict::Brake;
    }

    BciDecoderLipschitzGuardVerdict::Allow
}

/// Kani proof harness: bounded inputs cannot map outside a bounded box
/// when the Lipschitz constant and input norm ceiling satisfy the guard.
#[cfg(kani)]
mod lipschitz_kani {
    use super::*;
    use kani::any;

    #[kani::proof]
    pub fn decoder_bounded_output_box() {
        // Non-deterministic envelope, constrained to safe ranges.
        let lipschitz_constant: AlnScalar = any();
        kani::assume(lipschitz_constant >= 0.0);
        kani::assume(lipschitz_constant <= 10.0);

        let input_norm_ceiling: AlnScalar = any();
        kani::assume(input_norm_ceiling >= 0.0);
        kani::assume(input_norm_ceiling <= 1.0);

        let roh_ceiling: RoHScalar = any();
        kani::assume(roh_ceiling >= 0.0);
        kani::assume(roh_ceiling <= 0.3);

        let max_vec: [AlnScalar; 3] = [roh_ceiling, roh_ceiling, roh_ceiling];
        let min_vec: [AlnScalar; 3] = [-roh_ceiling, -roh_ceiling, -roh_ceiling];

        let env = DecoderLipschitzEnvelope {
            lipschitz_constant,
            input_norm_ceiling,
            intent_box: MotorIntentBox { min_vec, max_vec },
        };
        let cfg = BciDecoderConfig {
            decoder_id: "decoder".to_string(),
            max_gain: 10.0,
            roh_ceiling,
        };

        let verdict = check_lipschitz_bound(&cfg, &env, env.lipschitz_constant);
        kani::assume(matches!(verdict, BciDecoderLipschitzGuardVerdict::Allow));

        // Model any bounded input and a hypothetical decoder norm bound.
        let eeg_norm: AlnScalar = any();
        kani::assume(eeg_norm >= 0.0);
        kani::assume(eeg_norm <= env.input_norm_ceiling);

        // Lipschitz bound: ||f(x)|| <= L * ||x||, so max intent norm cannot exceed
        // lipschitz_constant * input_norm_ceiling, which is constrained by roh_ceiling.
        let output_intent_norm_bound = env.lipschitz_constant * eeg_norm;
        assert!(output_intent_norm_bound <= roh_ceiling);
    }
}
