// crates/nanorobotics-guards/src/sovereignty_kernel.rs

use crate::identity::BrainIdentityProfile;
use crate::neurorights::{NeurorightsMicroshield, PsychMetrics};
use crate::evidence::{AlnParticleRef, EvidenceBundle10};
use crate::identity::verify_command_signature;
use crate::evidence::validate_evidence_ontology;
use crate::audit::NeurorightsAuditSink;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GuardDecision {
    Allow,
    Deny { reason_code: u16 },
}

impl GuardDecision {
    pub fn is_allow(self) -> bool {
        matches!(self, GuardDecision::Allow)
    }

    pub fn is_deny(self) -> bool {
        !self.is_allow()
    }

    pub fn reason_code(self) -> Option<u16> {
        match self {
            GuardDecision::Allow => None,
            GuardDecision::Deny { reason_code } => Some(reason_code),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EvidenceTag {
    pub tag_type: u8,
    pub content_hash: [u8; 32],
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EvidenceBundle10 {
    pub tags: [EvidenceTag; 10],
}

#[derive(Debug)]
pub struct SwarmCommand<'a> {
    pub aln_particle: AlnParticleRef<'a>,
    pub cmd_payload: &'a [u8],
    pub psych_metrics: PsychMetrics,
    pub evidence: EvidenceBundle10,
    pub sig: &'a [u8],
}

impl<'a> SwarmCommand<'a> {
    pub fn new(
        aln_particle: AlnParticleRef<'a>,
        cmd_payload: &'a [u8],
        psych_metrics: PsychMetrics,
        evidence: EvidenceBundle10,
        sig: &'a [u8],
    ) -> Self {
        Self {
            aln_particle,
            cmd_payload,
            psych_metrics,
            evidence,
            sig,
        }
    }
}

pub struct SovereigntyKernel<'a, A: NeurorightsAuditSink> {
    profile: &'a BrainIdentityProfile,
    microshield: &'a NeurorightsMicroshield,
    auditor: &'a A,
}

impl<'a, A: NeurorightsAuditSink> SovereigntyKernel<'a, A> {
    pub fn new(
        profile: &'a BrainIdentityProfile,
        microshield: &'a NeurorightsMicroshield,
        auditor: &'a A,
    ) -> Self {
        Self {
            profile,
            microshield,
            auditor,
        }
    }

    pub fn evaluate(&self, cmd: &SwarmCommand<'_>) -> GuardDecision {
        if !self.verify_signature(cmd) {
            let decision = GuardDecision::Deny { reason_code: 1 };
            self.log_deny(cmd, decision);
            return decision;
        }

        if !self.verify_evidence(&cmd.evidence) {
            let decision = GuardDecision::Deny { reason_code: 2 };
            self.log_deny(cmd, decision);
            return decision;
        }

        if !self.verify_psych_caps(cmd) {
            let decision = GuardDecision::Deny { reason_code: 3 };
            self.log_deny(cmd, decision);
            return decision;
        }

        GuardDecision::Allow
    }

    fn verify_signature(&self, cmd: &SwarmCommand<'_>) -> bool {
        verify_command_signature(self.profile, cmd)
    }

    fn verify_evidence(&self, bundle: &EvidenceBundle10) -> bool {
        validate_evidence_ontology(bundle)
    }

    fn verify_psych_caps(&self, cmd: &SwarmCommand<'_>) -> bool {
        let clamp = self.microshield.clamp(&cmd.psych_metrics);
        clamp > 0.0
    }

    fn log_deny(&self, cmd: &SwarmCommand<'_>, decision: GuardDecision) {
        if let Some(reason_code) = decision.reason_code() {
            let evidence_hash = self.evidence_hash(&cmd.evidence);
            let _ = self.auditor.log_deny(
                self.profile,
                reason_code,
                &cmd.psych_metrics,
                evidence_hash,
            );
        }
    }

    fn evidence_hash(&self, bundle: &EvidenceBundle10) -> [u8; 32] {
        crate::crypto::hash_evidence_bundle(bundle)
    }
}
