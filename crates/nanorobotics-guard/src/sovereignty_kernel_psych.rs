// Path: crates/nanorobotics-guard/src/sovereignty_kernel_psych.rs
//
// Plug PsychosisRisk + PsychosisMicroshield into the psych gate
// of SovereigntyKernel. [file:3]

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use crate::sovereignty_kernel_core::{GuardDecision, SovereigntyKernelCore};
use neurorights_microshield::psychosis_clamp::PsychosisMicroshield;
use psychcaps_core::psychosis_risk::{PsychosisInputsNorm, PsychosisRisk, compute_psychosis_risk_default};

pub struct SovereigntyKernelPsych {
    pub core: SovereigntyKernelCore,
    pub microshield: PsychosisMicroshield,
}

impl SovereigntyKernelPsych {
    /// Evaluate command with psych gate driven by PsychosisRisk and clamp. [file:3]
    pub fn evaluate_with_psych(
        &self,
        cmd: &SwarmCommand,              // includes raw PsychMetrics→PsychosisInputsNorm mapping
        psych_inputs: PsychosisInputsNorm,
    ) -> GuardDecision {
        // Gate 1 + 2 (signature, evidence) are handled by core.evaluate_pre_psych.
        if let GuardDecision::Deny(code) = self.core.evaluate_pre_psych(cmd) {
            return GuardDecision::Deny(code);
        }

        // Compute psychosis risk.
        let risk: PsychosisRisk = match compute_psychosis_risk_default(psych_inputs) {
            Ok(r) => r,
            Err(_) => {
                self.core.audit_deny(cmd, 30); // code: psychosis_eval_error
                return GuardDecision::Deny(30);
            }
        };

        // Enforce PsychCaps ceilings (noworsethan) via policy shard, if present.
        if !self.core.policy_within_psych_limits(&risk) {
            self.core.audit_deny(cmd, 31); // code: psych_caps_exceeded
            return GuardDecision::Deny(31);
        }

        // Microshield clamp: if clamp hits 0, hard deny. [file:3]
        let c = self.microshield.clamp(&risk);
        if c <= 0.0 {
            self.core.audit_deny(cmd, 32); // code: microshield_zero_clamp
            return GuardDecision::Deny(32);
        }

        // Otherwise, allow but pass clamp factor downstream to actuation path.
        self.core.audit_allow(cmd, c);
        GuardDecision::Allow
    }
}
