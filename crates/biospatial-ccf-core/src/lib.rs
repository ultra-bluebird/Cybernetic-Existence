//! Core biospatial CCF and organ registration types.
//! Rust 2024, rust-version = "1.85", dual MIT/Apache-2.0.
//! This crate is pure and Kani-friendly.

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

use core::fmt;
use serde::{Deserialize, Serialize};

/// Canonical 3D point in Common Coordinate Framework (CCF) host space (meters).
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct CcfPoint3 {
    pub x_m: f32,
    pub y_m: f32,
    pub z_m: f32,
}

impl CcfPoint3 {
    pub fn new(x_m: f32, y_m: f32, z_m: f32) -> Self {
        Self { x_m, y_m, z_m }
    }

    pub fn zero() -> Self {
        Self {
            x_m: 0.0,
            y_m: 0.0,
            z_m: 0.0,
        }
    }
}

/// Homogeneous 4x4 transform (row-major) mapping from template to host space.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct HomogeneousTransform4 {
    /// Row-major 4x4 matrix. Last row must be [0, 0, 0, 1].
    pub m: [[f32; 4]; 4],
}

impl HomogeneousTransform4 {
    pub fn identity() -> Self {
        Self {
            m: [
                [1.0, 0.0, 0.0, 0.0],
                [0.0, 1.0, 0.0, 0.0],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0],
            ],
        }
    }

    pub fn from_rows(rows: [[f32; 4]; 4]) -> Self {
        Self { m: rows }
    }

    pub fn apply_point(&self, p: CcfPoint3) -> CcfPoint3 {
        let v = [p.x_m, p.y_m, p.z_m, 1.0_f32];
        let mut out = [0.0_f32; 4];
        for i in 0..4 {
            let mut acc = 0.0_f32;
            for j in 0..4 {
                acc += self.m[i][j] * v[j];
            }
            out[i] = acc;
        }
        CcfPoint3 {
            x_m: out[0],
            y_m: out[1],
            z_m: out[2],
        }
    }

    pub fn last_row_is_homogeneous(&self) -> bool {
        let r = &self.m[3];
        (r[0].abs() <= 1.0e-5_f32)
            && (r[1].abs() <= 1.0e-5_f32)
            && (r[2].abs() <= 1.0e-5_f32)
            && ((r[3] - 1.0_f32).abs() <= 1.0e-5_f32)
    }

    pub fn validate(&self) -> bool {
        self.last_row_is_homogeneous()
    }
}

/// Stable organ identifier aligned with ALN atlas and HRA organ IDs.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct OrganId(pub u32);

impl OrganId {
    pub fn new(raw: u32) -> Self {
        Self(raw)
    }

    pub fn raw(&self) -> u32 {
        self.0
    }
}

/// High-level organ system grouping tuned for biospatial corridors.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum OrganSystem {
    Cns,
    Cardiac,
    Hepatic,
    Renal,
    Pulmonary,
    Gastrointestinal,
    Hematologic,
    Immune,
    Endocrine,
    Musculoskeletal,
    Lymphatic,
    Integumentary,
    Reproductive,
}

/// Template-space organ metadata.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OrganTemplate {
    pub organ_id: OrganId,
    pub system: OrganSystem,
    pub mesh_index: u32,
    pub volume_m3: f32,
}

impl OrganTemplate {
    pub fn new(organ_id: OrganId, system: OrganSystem, mesh_index: u32, volume_m3: f32) -> Self {
        Self {
            organ_id,
            system,
            mesh_index,
            volume_m3,
        }
    }

    pub fn is_volume_valid(&self) -> bool {
        self.volume_m3.is_finite() && self.volume_m3 > 0.0_f32
    }
}

/// Host-specific registration of a single organ.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OrganRegistration {
    pub organ_id: OrganId,
    pub template_to_host: HomogeneousTransform4,
    pub quality: f32,
}

impl OrganRegistration {
    pub fn new(organ_id: OrganId, template_to_host: HomogeneousTransform4, quality: f32) -> Self {
        Self {
            organ_id,
            template_to_host,
            quality,
        }
    }

    pub fn validate(&self) -> bool {
        if !(0.0_f32..=1.0_f32).contains(&self.quality) {
            return false;
        }
        self.template_to_host.validate()
    }
}

/// Host-level atlas of all organs in CCF.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HostOrganAtlas {
    pub host_did: &'static str,
    pub bostrom_address: &'static str,
    pub registrations: Vec<OrganRegistration>,
}

impl HostOrganAtlas {
    pub fn new() -> Self {
        Self {
            host_did: HOST_DID,
            bostrom_address: BOSTROM_ADDRESS,
            registrations: Vec::new(),
        }
    }

    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            host_did: HOST_DID,
            bostrom_address: BOSTROM_ADDRESS,
            registrations: Vec::with_capacity(capacity),
        }
    }

    pub fn add_registration(&mut self, reg: OrganRegistration) -> Result<(), AtlasError> {
        if !reg.validate() {
            return Err(AtlasError::InvalidRegistration);
        }
        self.registrations.push(reg);
        Ok(())
    }

    pub fn find_registration(&self, organ_id: OrganId) -> Option<&OrganRegistration> {
        self.registrations.iter().find(|r| r.organ_id == organ_id)
    }

    pub fn registration_count(&self) -> usize {
        self.registrations.len()
    }
}

#[derive(Debug)]
pub enum AtlasError {
    InvalidRegistration,
}

impl fmt::Display for AtlasError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AtlasError::InvalidRegistration => write!(f, "Invalid organ registration"),
        }
    }
}

/// Low-dimensional principal component shape model for an organ.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OrganShapeModel {
    pub modes: u8,
    pub eigenvalues: Vec<f32>,
    pub cumulative_variance: f32,
}

/// Host-specific projection of an organ shape into PCA space.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OrganShapeInstance {
    pub organ_id: OrganId,
    pub coefficients: Vec<f32>,
}

impl OrganShapeInstance {
    pub fn validate(&self, model: &OrganShapeModel) -> bool {
        if self.coefficients.len() != model.modes as usize {
            return false;
        }
        self.coefficients.iter().all(|c| c.is_finite())
    }
}

/// Topological summary for an organ (TDA-inspired).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OrganTopologySummary {
    pub components_0d: u16,
    pub loops_1d: u16,
    pub cavities_2d: u16,
}

impl OrganTopologySummary {
    pub fn clogging_score(&self) -> f32 {
        let c0 = if self.components_0d == 0 {
            1.0_f32
        } else {
            self.components_0d as f32
        };
        let cavities = self.cavities_2d as f32;
        let loops = self.loops_1d as f32;
        (cavities + loops + 1.0_f32) / c0
    }
}

/// Classification of a region where the atlas is uncertain.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum UnknownRegionKind {
    RegistrationUnstable,
    TopologyAnomaly,
    CrossModalMismatch,
    UnderInvestigation,
}

/// RoH-aware handling policy for unknown regions.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum UnknownRegionPolicy {
    ExclusionZone,
    LowRoHCorridor,
    DiagnosticsOnly,
}

/// Compact identifier for an unknown region in CCF.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct UnknownRegionId(pub u32);

impl UnknownRegionId {
    pub fn new(raw: u32) -> Self {
        Self(raw)
    }

    pub fn raw(&self) -> u32 {
        self.0
    }
}

/// Axis-aligned CCF bounding box for an unknown region (meters).
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct CcfAabb {
    pub min: CcfPoint3,
    pub max: CcfPoint3,
}

impl CcfAabb {
    pub fn new(min: CcfPoint3, max: CcfPoint3) -> Self {
        Self { min, max }
    }

    pub fn contains(&self, p: CcfPoint3) -> bool {
        (p.x_m >= self.min.x_m)
            && (p.x_m <= self.max.x_m)
            && (p.y_m >= self.min.y_m)
            && (p.y_m <= self.max.y_m)
            && (p.z_m >= self.min.z_m)
            && (p.z_m <= self.max.z_m)
    }
}

/// Unknown region descriptor bound to host and RoH corridor policy.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct UnknownRegionDescriptor {
    pub region_id: UnknownRegionId,
    pub host_did: &'static str,
    pub bostrom_address: &'static str,
    pub organ_id: Option<OrganId>,
    pub kind: UnknownRegionKind,
    pub policy: UnknownRegionPolicy,
    pub bbox_ccf: CcfAabb,
    pub roh_ceiling: f32,
}

impl UnknownRegionDescriptor {
    pub fn new(
        region_id: UnknownRegionId,
        organ_id: Option<OrganId>,
        kind: UnknownRegionKind,
        policy: UnknownRegionPolicy,
        bbox_ccf: CcfAabb,
        roh_ceiling: f32,
    ) -> Self {
        Self {
            region_id,
            host_did: HOST_DID,
            bostrom_address: BOSTROM_ADDRESS,
            organ_id,
            kind,
            policy,
            bbox_ccf,
            roh_ceiling,
        }
    }

    pub fn validate(&self) -> bool {
        (self.roh_ceiling >= 0.0_f32) && (self.roh_ceiling <= 0.30_f32 + 1.0e-6_f32)
    }
}

/// Per-host registry of unknown / uncertain regions in CCF.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HostUnknownRegionRegistry {
    pub host_did: &'static str,
    pub bostrom_address: &'static str,
    pub regions: Vec<UnknownRegionDescriptor>,
}

impl HostUnknownRegionRegistry {
    pub fn new() -> Self {
        Self {
            host_did: HOST_DID,
            bostrom_address: BOSTROM_ADDRESS,
            regions: Vec::new(),
        }
    }

    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            host_did: HOST_DID,
            bostrom_address: BOSTROM_ADDRESS,
            regions: Vec::with_capacity(capacity),
        }
    }

    pub fn add_region(
        &mut self,
        desc: UnknownRegionDescriptor,
    ) -> Result<(), UnknownRegionError> {
        if !desc.validate() {
            return Err(UnknownRegionError::InvalidDescriptor);
        }
        self.regions.push(desc);
        Ok(())
    }

    pub fn query_point(&self, p: CcfPoint3) -> Vec<&UnknownRegionDescriptor> {
        self.regions.iter().filter(|r| r.bbox_ccf.contains(p)).collect()
    }

    pub fn region_count(&self) -> usize {
        self.regions.len()
    }
}

#[derive(Debug)]
pub enum UnknownRegionError {
    InvalidDescriptor,
}

impl fmt::Display for UnknownRegionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            UnknownRegionError::InvalidDescriptor => {
                write!(f, "Invalid unknown-region descriptor")
            }
        }
    }
}
