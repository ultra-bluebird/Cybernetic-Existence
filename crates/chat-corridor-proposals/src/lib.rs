//! Corridor proposal lane for AI-chat and human authors.
//!
//! Proposals are constrained to monotone-tightening changes only and must
//! carry EvidenceBundle10 and host bindings.

use corridor_loader::CorridorPop;
use evidence_bundle::EvidenceBundle10;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AuthorKind {
    HumanClinician,
    HostCitizen,
    AiChatAssistant,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProposalState {
    Draft,
    Simulated,
    Proven,
    HumanApproved,
    Activated,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CorridorChangeKind {
    DecreaseRohCeiling,
    IncreaseFloor { axis: String },
    AddPolyConstraint,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorridorProposal {
    pub proposal_id: Uuid,
    pub author_kind: AuthorKind,
    pub target_corridor_id: String,
    pub change_kind: CorridorChangeKind,
    pub delta: f32,
    pub rationale: String,
    pub evidence_bundle: EvidenceBundle10,
    pub state: ProposalState,
    pub has_kani_proof: bool,
    pub host_did: String,
    pub bostrom_addr: String,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

#[derive(Debug)]
pub enum ProposalError {
    NotMonotoneTightening,
    InvalidTransition,
    MissingSignatures,
    MissingProof,
}

impl CorridorProposal {
    pub fn is_monotone_tightening(&self, baseline: &CorridorPop) -> bool {
        match self.change_kind {
            CorridorChangeKind::DecreaseRohCeiling => {
                self.delta <= 0.0 && (baseline.roh_max + self.delta) <= baseline.roh_max
            }
            CorridorChangeKind::IncreaseFloor { .. } => self.delta >= 0.0,
            CorridorChangeKind::AddPolyConstraint => true,
        }
    }

    pub fn promote_to_simulated(
        mut self,
        baseline: &CorridorPop,
        now_ms: i64,
    ) -> Result<Self, ProposalError> {
        if self.state != ProposalState::Draft {
            return Err(ProposalError::InvalidTransition);
        }
        if !self.is_monotone_tightening(baseline) {
            return Err(ProposalError::NotMonotoneTightening);
        }
        self.state = ProposalState::Simulated;
        self.updated_at_ms = now_ms;
        Ok(self)
    }

    pub fn promote_to_proven(
        mut self,
        baseline: &CorridorPop,
        now_ms: i64,
    ) -> Result<Self, ProposalError> {
        if self.state != ProposalState::Simulated {
            return Err(ProposalError::InvalidTransition);
        }
        if !self.is_monotone_tightening(baseline) {
            return Err(ProposalError::NotMonotoneTightening);
        }
        self.state = ProposalState::Proven;
        self.updated_at_ms = now_ms;
        Ok(self)
    }

    pub fn promote_to_human_approved(
        mut self,
        clinician_sig: u8,
        host_sig: u8,
        now_ms: i64,
    ) -> Result<Self, ProposalError> {
        if self.state != ProposalState::Proven {
            return Err(ProposalError::InvalidTransition);
        }
        if clinician_sig == 0 || host_sig == 0 {
            return Err(ProposalError::MissingSignatures);
        }
        self.state = ProposalState::HumanApproved;
        self.updated_at_ms = now_ms;
        Ok(self)
    }

    pub fn promote_to_activated(mut self, now_ms: i64) -> Result<Self, ProposalError> {
        if self.state != ProposalState::HumanApproved {
            return Err(ProposalError::InvalidTransition);
        }
        if !self.has_kani_proof {
            return Err(ProposalError::MissingProof);
        }
        self.state = ProposalState::Activated;
        self.updated_at_ms = now_ms;
        Ok(self)
    }
}
