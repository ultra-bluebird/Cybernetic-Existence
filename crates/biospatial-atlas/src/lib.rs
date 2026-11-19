// File: crates/biospatial-atlas/src/lib.rs
// edition: 2024, rust-version: 1.85

#![forbid(unsafe_code)]

pub mod coords;

use crate::coords::{AllowedRegion, HostAabb, HostCoord, NanoSample, TissueClass, VoxelGridMeta};
use bincode;
use serde::{Deserialize, Serialize};
use std::fs::File;
use std::io::{Read, Result as IoResult};
use std::path::Path;

/// Binary voxel atlas per organ.
/// Layout in each `data/<organ>.vox`:
/// - VoxelGridMeta via bincode.
/// - dim_x * dim_y * dim_z bytes, each encoding a TissueClass as u8.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OrganAtlas {
    pub name: String,
    pub meta: VoxelGridMeta,
    pub tissues: Vec<TissueClass>,
}

impl OrganAtlas {
    pub fn load<P: AsRef<Path>>(name: &str, path: P) -> IoResult<Self> {
        let mut f = File::open(path)?;
        let mut meta_buf = Vec::new();
        meta_buf.resize(std::mem::size_of::<VoxelGridMeta>(), 0);
        f.read_exact(&mut meta_buf)?;
        let meta: VoxelGridMeta =
            bincode::deserialize(&meta_buf).expect("Failed to decode VoxelGridMeta");
        let voxel_count = (meta.dim_x * meta.dim_y * meta.dim_z) as usize;
        let mut tissue_bytes = vec![0u8; voxel_count];
        f.read_exact(&mut tissue_bytes)?;
        let tissues = tissue_bytes
            .into_iter()
            .map(|b| match b {
                0 => TissueClass::Myocardium,
                1 => TissueClass::RenalCortex,
                2 => TissueClass::HepaticParenchyma,
                3 => TissueClass::BrainCortex,
                4 => TissueClass::Microvasculature,
                _ => TissueClass::Other,
            })
            .collect();

        Ok(Self {
            name: name.to_string(),
            meta,
            tissues,
        })
    }

    pub fn voxel_index(&self, coord: (u32, u32, u32)) -> Option<usize> {
        let (x, y, z) = coord;
        if x >= self.meta.dim_x || y >= self.meta.dim_y || z >= self.meta.dim_z {
            return None;
        }
        let idx =
            (z * self.meta.dim_x * self.meta.dim_y + y * self.meta.dim_x + x) as usize;
        Some(idx)
    }

    pub fn tissue_at(&self, coord: (u32, u32, u32)) -> Option<TissueClass> {
        self.voxel_index(coord).map(|i| self.tissues[i])
    }
}

/// Biospatial atlas over multiple organs.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BiospatialAtlas {
    pub host_did: String,
    pub bostrom_address: String,
    pub organs: Vec<OrganAtlas>,
    pub allowed_regions: Vec<(TissueClass, HostAabb)>,
}

impl BiospatialAtlas {
    pub fn new(host_did: String, bostrom_address: String) -> Self {
        Self {
            host_did,
            bostrom_address,
            organs: Vec::new(),
            allowed_regions: Vec::new(),
        }
    }

    pub fn add_organ(&mut self, atlas: OrganAtlas) {
        self.organs.push(atlas);
    }

    pub fn add_allowed_region(&mut self, tissue: TissueClass, aabb: HostAabb) {
        self.allowed_regions.push((tissue, aabb));
    }

    /// Check if a nanoswarm trajectory remains in allowed regions.
    /// If any sample leaves the allowed tissue class AABBs, returns false.
    pub fn trajectory_stays_in_allowed(
        &self,
        samples: &[NanoSample],
        expected_tissue: TissueClass,
    ) -> bool {
        for s in samples {
            let mut inside_any = false;
            for (tissue, aabb) in &self.allowed_regions {
                if *tissue == expected_tissue && aabb.contains(s.pos) {
                    inside_any = true;
                    break;
                }
            }
            if !inside_any {
                return false;
            }
        }
        true
    }
}
