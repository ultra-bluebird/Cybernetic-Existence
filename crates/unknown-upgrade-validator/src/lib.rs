// file: nanorobotics/crates/unknown-upgrade-validator/src/lib.rs

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]
#![no_std]

extern crate alloc;

use alloc::vec::Vec;
use alloc::string::String;

use multi_organ_ssm_ph_core::{UnknownRegionEvidenceV1, UpgradeThresholds};
use biospatial_unknown_upgrade_governance::{UpgradeApprovalVcV1, is_quorum_satisfied, is_tightening_only};

#[derive(Clone, Debug)]
pub struct UnknownRegionUpgradeProposalV1 {
    pub proposal_id: String,
    pub evidence_id: String,
    pub roh_ceiling_new: f32,
    pub roh_ceiling_old: f32,
}

fn proposal_respects_roh_monotonicity(p: &UnknownRegionUpgradeProposalV1) -> bool {
    p.roh_ceiling_new <= p.roh_ceiling_old && p.roh_ceiling_new <= 0.30_f32
}

pub fn is_upgrade_admissible(
    proposal: &UnknownRegionUpgradeProposalV1,
    evidence: &UnknownRegionEvidenceV1,
    thresholds: &[UpgradeThresholds],
    vc: &UpgradeApprovalVcV1,
) -> bool {
    if proposal.evidence_id != evidence.evidence_id {
        return false;
    }
    if proposal.proposal_id != vc.proposal_id {
        return false;
    }
    if !proposal_respects_roh_monotonicity(proposal) {
        return false;
    }
    if !multi_organ_ssm_ph_core::validate_evidence_against_thresholds(evidence, thresholds) {
        return false;
    }
    if !is_quorum_satisfied(vc) {
        return false;
    }
    if !is_tightening_only(vc) {
        return false;
    }
    true
}
