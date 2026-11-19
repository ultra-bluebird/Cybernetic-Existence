// File: nanorobotics/crates/biospatial-ccf-core/src/kani_unknown_upgrade.rs

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

use crate::{
    UnknownRegionDescriptor,
    UnknownRegionKind,
    UnknownRegionPolicy,
};

/// Mirror of UnknownRegionUpgradeProposalV1 ALN semantics, restricted
/// to the fields needed for invariants.
#[derive(Clone, Debug)]
pub struct UnknownRegionUpgradeProposal {
    pub unknown_region_id: u32,
    pub target_organ_id: Option<u32>,
    pub target_sub_compartment_id: Option<u32>,
    pub new_region_id: u32,
    pub old_roh_ceiling: f32,
    pub new_roh_ceiling: f32,
    pub old_policy: UnknownRegionPolicy,
    pub new_policy: UnknownRegionPolicy,
    pub roh_slice_max_new: f32,
}

/// Partial order over UnknownRegionPolicy, encoded as an integer rank.
/// Higher rank == stricter policy.
#[inline]
pub fn policy_rank(p: UnknownRegionPolicy) -> u8 {
    match p {
        UnknownRegionPolicy::ExclusionZone => 3,
        UnknownRegionPolicy::DiagnosticsOnly => 2,
        UnknownRegionPolicy::LowRoHCorridor => 1,
    }
}

/// Check ALN invariants for a single upgrade proposal, ignoring global RoH.
pub fn check_unknown_upgrade_local_invariants(
    desc: &UnknownRegionDescriptor,
    proposal: &UnknownRegionUpgradeProposal,
) -> bool {
    // Host-safety: descriptors must already satisfy RoH <= 0.30.
    if !desc.validate() {
        return false;
    }

    // Bind to the same host identity and Bostrom address (sovereign continuity).
    if desc.host_did != HOST_DID || desc.bostrom_address != BOSTROM_ADDRESS {
        return false;
    }

    // Consistency: unknown_region_id must match.
    if desc.region_id.0 != proposal.unknown_region_id {
        return false;
    }

    // 1) RoH ceiling tightening: new <= old and <= 0.30.
    if !(proposal.new_roh_ceiling <= proposal.old_roh_ceiling) {
        return false;
    }
    if !(proposal.new_roh_ceiling <= 0.30 + 1e-6) {
        return false;
    }

    // 2) Slice max cannot exceed old ceiling.
    if !(proposal.roh_slice_max_new <= proposal.old_roh_ceiling + 1e-6) {
        return false;
    }

    // 3) Policy monotonicity: cannot become more permissive.
    let old_rank = policy_rank(proposal.old_policy);
    let new_rank = policy_rank(proposal.new_policy);
    if new_rank < old_rank {
        return false;
    }

    // 4) ExclusionZone upgrade cannot open LowRoHCorridor directly.
    if proposal.old_policy == UnknownRegionPolicy::ExclusionZone
        && proposal.new_policy == UnknownRegionPolicy::LowRoHCorridor
    {
        return false;
    }

    // 5) UnknownRegionKind::RegistrationUnstable may not be upgraded at all.
    if desc.kind == UnknownRegionKind::RegistrationUnstable {
        return false;
    }

    true
}

/// Global RoH slice constraint:
/// Given an index of regions with slice maxima, ensure that substituting
/// `roh_slice_max_new` for the old unknown region preserves
/// sum_i roh_slice_max_i <= 0.30.
///
/// This uses a simple floating-point aggregate model that Kani can
/// symbolically explore.
pub fn check_global_roh_slice_constraint(
    roh_slice_max_before: &[f32],
    unknown_region_index: usize,
    proposal: &UnknownRegionUpgradeProposal,
) -> bool {
    if roh_slice_max_before.is_empty() {
        return false;
    }
    if unknown_region_index >= roh_slice_max_before.len() {
        return false;
    }

    // Compute sum before upgrade.
    let mut sum_before = 0.0_f32;
    for v in roh_slice_max_before.iter().copied() {
        if v < 0.0 {
            return false;
        }
        sum_before += v;
    }

    // ALN shard enforces global sum <= 0.30.
    if sum_before > 0.30 + 1e-6 {
        return false;
    }

    // Compute sum after upgrade by substituting the unknown region slice.
    let mut sum_after = 0.0_f32;
    for (idx, v) in roh_slice_max_before.iter().copied().enumerate() {
        if idx == unknown_region_index {
            sum_after += proposal.roh_slice_max_new;
        } else {
            sum_after += v;
        }
    }

    // Global invariant must still hold.
    sum_after <= 0.30 + 1e-6
}

#[cfg(kani)]
mod kani_unknown_upgrade {
    use super::*;
    use crate::{UnknownRegionId, CcfAabb, CcfPoint3};

    /// Generate an arbitrary but valid UnknownRegionDescriptor
    /// for symbolic exploration.
    fn arb_unknown_region_descriptor() -> UnknownRegionDescriptor {
        // Symbolic fields via kani::any().
        let roh = kani::any::<f32>();
        let kind = kani::any::<UnknownRegionKind>();
        let policy = kani::any::<UnknownRegionPolicy>();
        let id_val = kani::any::<u32>();

        // Clamp roh into [0, 0.30].
        let roh_clamped = if roh.is_finite() {
            if roh < 0.0 {
                0.0
            } else if roh > 0.30 {
                0.30
            } else {
                roh
            }
        } else {
            0.0
        };

        let bbox = CcfAabb {
            min: CcfPoint3 { x_m: 0.0, y_m: 0.0, z_m: 0.0 },
            max: CcfPoint3 { x_m: 0.01, y_m: 0.01, z_m: 0.01 },
        };

        UnknownRegionDescriptor {
            region_id: UnknownRegionId(id_val),
            host_did: HOST_DID,
            bostrom_address: BOSTROM_ADDRESS,
            organ_id: None,
            kind,
            policy,
            bbox_ccf: bbox,
            roh_ceiling: roh_clamped,
        }
    }

    /// Generate an arbitrary UnknownRegionUpgradeProposal that respects minimal
    /// ALN constraints (e.g., non-negative RoH).
    fn arb_upgrade_proposal(region_id: u32, old_roh_ceiling: f32) -> UnknownRegionUpgradeProposal {
        let new_roh = kani::any::<f32>();
        let new_slice = kani::any::<f32>();
        let old_policy = kani::any::<UnknownRegionPolicy>();
        let new_policy = kani::any::<UnknownRegionPolicy>();

        let new_roh_clamped = if new_roh.is_finite() {
            if new_roh < 0.0 {
                0.0
            } else if new_roh > old_roh_ceiling {
                old_roh_ceiling
            } else {
                new_roh
            }
        } else {
            old_roh_ceiling
        };

        let new_slice_clamped = if new_slice.is_finite() {
            if new_slice < 0.0 {
                0.0
            } else if new_slice > old_roh_ceiling {
                old_roh_ceiling
            } else {
                new_slice
            }
        } else {
            0.0
        };

        UnknownRegionUpgradeProposal {
            unknown_region_id: region_id,
            target_organ_id: None,
            target_sub_compartment_id: None,
            new_region_id: region_id + 1,
            old_roh_ceiling,
            new_roh_ceiling: new_roh_clamped,
            old_policy,
            new_policy,
            roh_slice_max_new: new_slice_clamped,
        }
    }

    /// Harness 1: Local invariants always hold for upgrades that pass the checker.
    #[kani::proof]
    fn kani_unknown_upgrade_local_invariants() {
        let desc = arb_unknown_region_descriptor();
        let proposal = arb_upgrade_proposal(desc.region_id.0, desc.roh_ceiling);

        if check_unknown_upgrade_local_invariants(&desc, &proposal) {
            // 1) new_roh_ceiling <= old_roh_ceiling <= 0.30.
            assert!(proposal.new_roh_ceiling <= proposal.old_roh_ceiling + 1e-6);
            assert!(proposal.new_roh_ceiling <= 0.30 + 1e-6);

            // 2) roh_slice_max_new <= old_roh_ceiling.
            assert!(proposal.roh_slice_max_new <= proposal.old_roh_ceiling + 1e-6);

            // 3) Policy monotonicity rank(new) >= rank(old).
            let old_rank = policy_rank(proposal.old_policy);
            let new_rank = policy_rank(proposal.new_policy);
            assert!(new_rank >= old_rank);

            // 4) If old ExclusionZone, new cannot be LowRoHCorridor.
            if proposal.old_policy == UnknownRegionPolicy::ExclusionZone {
                assert!(proposal.new_policy != UnknownRegionPolicy::LowRoHCorridor);
            }

            // 5) RegistrationUnstable descriptor cannot be upgraded.
            assert!(desc.kind != UnknownRegionKind::RegistrationUnstable);
        }
    }

    /// Harness 2: Global RoH slice sum remains <= 0.30 after any permitted upgrade.
    #[kani::proof]
    fn kani_unknown_upgrade_global_roh_preserved() {
        // Build a small symbolic biospatial index slice max array.
        let len = 4usize;
        let mut roh_slice_max_before = [0.0_f32; 4];

        for i in 0..len {
            let v = kani::any::<f32>();
            roh_slice_max_before[i] = if v.is_finite() {
                if v < 0.0 {
                    0.0
                } else if v > 0.30 {
                    0.30
                } else {
                    v
                }
            } else {
                0.0
            };
        }

        let unknown_index = kani::any::<usize>() % len;
        let desc = arb_unknown_region_descriptor();
        let proposal = arb_upgrade_proposal(desc.region_id.0, desc.roh_ceiling);

        // Assume the descriptor and proposal are locally valid.
        kani::assume(check_unknown_upgrade_local_invariants(&desc, &proposal));

        if check_global_roh_slice_constraint(&roh_slice_max_before, unknown_index, &proposal) {
            // Compute sum after upgrade and assert <= 0.30.
            let mut sum_after = 0.0_f32;
            for (idx, v) in roh_slice_max_before.iter().copied().enumerate() {
                if idx == unknown_index {
                    sum_after += proposal.roh_slice_max_new;
                } else {
                    sum_after += v;
                }
            }
            assert!(sum_after <= 0.30 + 1e-6);
        }
    }
}
