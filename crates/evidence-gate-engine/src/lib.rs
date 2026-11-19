#![forbid(unsafe_code)]

//! Deterministic advancement checks for evidence-gated research stages.
//!
//! This crate evaluates supplied gate records. It does not certify safety,
//! legal compliance, scientific truth, or authorization to deploy a system.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GateStatus {
    NotStarted,
    EvidenceIncomplete,
    Satisfied,
    Disputed,
    Rejected,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DisputeStatus {
    Open,
    ReplicationRequested,
    ResolvedSupports,
    ResolvedDoesNotSupport,
}

#[derive(Debug, Clone)]
pub struct EvidenceItem {
    pub kind: String,
    pub locator: String,
    pub integrity_reference: String,
    pub validated: bool,
}

#[derive(Debug, Clone)]
pub struct Dispute {
    pub evidence_id: String,
    pub status: DisputeStatus,
}

#[derive(Debug, Clone)]
pub struct Gate {
    pub stage: u32,
    pub status: GateStatus,
    pub required_evidence_kinds: Vec<String>,
    pub evidence: Vec<EvidenceItem>,
    pub disputes: Vec<Dispute>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AdvancementDecision {
    AdvanceAllowed,
    BlockedByIncompleteEvidence,
    BlockedByDispute,
    BlockedByRejectedGate,
}

pub fn evaluate_advancement(gates: &[Gate], target_stage: u32) -> AdvancementDecision {
    for gate in gates.iter().filter(|gate| gate.stage <= target_stage) {
        if gate.status == GateStatus::Rejected {
            return AdvancementDecision::BlockedByRejectedGate;
        }

        if gate.disputes.iter().any(|dispute| {
            matches!(
                dispute.status,
                DisputeStatus::Open | DisputeStatus::ReplicationRequested
            )
        }) {
            return AdvancementDecision::BlockedByDispute;
        }

        if gate.status != GateStatus::Satisfied || !has_validated_required_evidence(gate) {
            return AdvancementDecision::BlockedByIncompleteEvidence;
        }
    }

    AdvancementDecision::AdvanceAllowed
}

fn has_validated_required_evidence(gate: &Gate) -> bool {
    gate.required_evidence_kinds.iter().all(|required_kind| {
        gate.evidence.iter().any(|item| {
            item.validated
                && item.kind == *required_kind
                && !item.locator.trim().is_empty()
                && !item.integrity_reference.trim().is_empty()
        })
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn open_dispute_blocks_advancement() {
        let gates = vec![Gate {
            stage: 0,
            status: GateStatus::Satisfied,
            required_evidence_kinds: vec!["specification".to_owned()],
            evidence: vec![EvidenceItem {
                kind: "specification".to_owned(),
                locator: "specs/example.md".to_owned(),
                integrity_reference: "urn:integrity:example".to_owned(),
                validated: true,
            }],
            disputes: vec![Dispute {
                evidence_id: "evidence-001".to_owned(),
                status: DisputeStatus::Open,
            }],
        }];

        assert_eq!(
            evaluate_advancement(&gates, 0),
            AdvancementDecision::BlockedByDispute
        );
    }

    #[test]
    fn complete_undisputed_gate_allows_advancement() {
        let gates = vec![Gate {
            stage: 0,
            status: GateStatus::Satisfied,
            required_evidence_kinds: vec![
                "specification".to_owned(),
                "test".to_owned(),
            ],
            evidence: vec![
                EvidenceItem {
                    kind: "specification".to_owned(),
                    locator: "specs/example.md".to_owned(),
                    integrity_reference: "urn:integrity:spec-001".to_owned(),
                    validated: true,
                },
                EvidenceItem {
                    kind: "test".to_owned(),
                    locator: "tests/example.rs".to_owned(),
                    integrity_reference: "urn:integrity:test-001".to_owned(),
                    validated: true,
                },
            ],
            disputes: vec![],
        }];

        assert_eq!(
            evaluate_advancement(&gates, 0),
            AdvancementDecision::AdvanceAllowed
        );
    }
}
