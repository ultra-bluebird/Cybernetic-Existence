// file: nanorobotics/crates/multi-organ-ssm-ph-core/src/lib.rs

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]
#![no_std]

extern crate alloc;

use alloc::string::String;
use alloc::vec::Vec;

/// Short host/authority constants for DID and Bostrom binding.
pub const HOST_DID: &str = "did.aln.organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Joint organ mesh placeholder; real implementations plug in concrete mesh formats.
#[derive(Clone, Debug)]
pub struct OrganMesh {
    pub organ_id: String,
    /// Flattened coordinates in CCF frame (x0,y0,z0,x1,y1,z1,...).
    pub coords_ccf_mm: Vec<f32>,
}

/// Volume segmentation placeholder for PH; references a CCF-aligned 3D label volume.
#[derive(Clone, Debug)]
pub struct VolumeSegmentation {
    pub organ_system_id: String,
    pub label_volume_id: String,
}

/// Filtration specification for PH.
#[derive(Clone, Debug)]
pub struct FiltrationSpec {
    pub max_scale_mm: f32,
    pub scale_steps: u32,
    pub min_persistence: f32,
}

/// Multiorgan SSM model (Rust side of MultiOrganSsmModelV1).
#[derive(Clone, Debug)]
pub struct MultiOrganSsmModelV1 {
    pub model_id: String,
    pub organ_system_ids: Vec<String>,
    pub donor_count: u32,
    pub vector_dim: u32,
    pub modes_k: u32,
    pub eigenvalues: Vec<f32>,
    pub cumulative_variance: f32,
    pub mean_hash: String,
    pub basis_hash: String,
}

/// Multiorgan PH signature (Rust side of MultiOrganPhSignatureV1).
#[derive(Clone, Debug)]
pub struct MultiOrganPhSignatureV1 {
    pub signature_id: String,
    pub organ_system_ids: Vec<String>,
    pub filtration_spec_hash: String,
    pub cluster_count: u32,
    pub cluster_donor_fractions: Vec<f32>,
    pub cluster_p_values: Vec<f32>,
    pub cluster_persistence_scores: Vec<f32>,
    pub topology_embedding_hash: String,
}

/// Thresholds for a single organ (Rust side of UnknownUpgradeOrganThresholdV1).
#[derive(Clone, Debug)]
pub struct UpgradeThresholds {
    pub organ_system_id: String,
    pub donor_min: u32,
    pub donor_fraction_min: f32,
    pub ph_pvalue_max: f32,
    pub ssm_variance_min: f32,
    pub max_registration_tre_mm: f32,
}

/// Evidence snapshot per organ touched by an unknown region.
#[derive(Clone, Debug)]
pub struct UnknownRegionOrganEvidence {
    pub organ_system_id: String,
    pub donor_count: u32,
    pub donor_fraction: f32,
    pub ph_pvalue: f32,
    pub ssm_cumulative_variance: f32,
    pub registration_tre_mm: f32,
}

/// Aggregated evidence for a multi-organ unknown region.
#[derive(Clone, Debug)]
pub struct UnknownRegionEvidenceV1 {
    pub evidence_id: String,
    pub organ_evidence: Vec<UnknownRegionOrganEvidence>,
    pub ssm_model_ids: Vec<String>,
    pub ph_signature_ids: Vec<String>,
    pub host_did: String,
    pub bostrom_address: String,
}

/// Build joint shape vector by concatenating CCF-registered organ meshes.
pub fn build_joint_shape_vector(meshes: &[OrganMesh]) -> Vec<f32> {
    let total_len: usize = meshes.iter().map(|m| m.coords_ccf_mm.len()).sum();
    let mut out = Vec::with_capacity(total_len);
    for m in meshes {
        out.extend_from_slice(&m.coords_ccf_mm);
    }
    out
}

/// Compute cumulative variance from eigenvalues λ_1..λ_M and chosen mode count k.
///
/// Returns V_cum(k) = sum_{i<=k} λ_i / sum_{i<=M} λ_i, or 0.0 if total variance is zero.
pub fn cumulative_variance(eigenvalues: &[f32], k: usize) -> f32 {
    if eigenvalues.is_empty() || k == 0 {
        return 0.0;
    }
    let total: f32 = eigenvalues.iter().copied().sum();
    if total <= 0.0 {
        return 0.0;
    }
    let k_clamped = core::cmp::min(k, eigenvalues.len());
    let num: f32 = eigenvalues[..k_clamped].iter().copied().sum();
    num / total
}

/// Decision predicate E_ok(o) for one organ, based on thresholds t and evidence e.
///
/// Returns true iff all donor, fraction, PH, SSM, and TRE conditions are satisfied.
pub fn evidence_ok_for_organ(e: &UnknownRegionOrganEvidence, t: &UpgradeThresholds) -> bool {
    if e.organ_system_id != t.organ_system_id {
        return false;
    }
    if e.donor_count < t.donor_min {
        return false;
    }
    if e.donor_fraction < t.donor_fraction_min {
        return false;
    }
    if e.ph_pvalue > t.ph_pvalue_max {
        return false;
    }
    if e.ssm_cumulative_variance < t.ssm_variance_min {
        return false;
    }
    if e.registration_tre_mm > t.max_registration_tre_mm {
        return false;
    }
    true
}

/// Validate evidence against a list of per-organ thresholds.
/// All organs present in `e.organ_evidence` must satisfy their thresholds.
pub fn validate_evidence_against_thresholds(
    e: &UnknownRegionEvidenceV1,
    thresholds: &[UpgradeThresholds],
) -> bool {
    if e.host_did != HOST_DID {
        return false;
    }
    if e.bostrom_address != BOSTROM_ADDRESS {
        return false;
    }
    for organ_ev in &e.organ_evidence {
        let maybe_t = thresholds
            .iter()
            .find(|t| t.organ_system_id == organ_ev.organ_system_id);
        let Some(t) = maybe_t else {
            return false;
        };
        if !evidence_ok_for_organ(organ_ev, t) {
            return false;
        }
    }
    true
}
