// File: crates/biospatial-atlas/src/coords.rs
// edition: 2024, rust-version: 1.85

#![forbid(unsafe_code)]

use nalgebra::{Matrix4, Point3, Vector3};
use serde::{Deserialize, Serialize};

/// Discrete tissue classification for voxels.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum TissueClass {
    Myocardium,
    RenalCortex,
    HepaticParenchyma,
    BrainCortex,
    Microvasculature,
    Other,
}

/// Integer voxel coordinate in host atlas space.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub struct VoxelCoord {
    pub x: i32,
    pub y: i32,
    pub z: i32,
}

/// Continuous host-space coordinate in millimetres.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct HostCoord {
    pub x_mm: f32,
    pub y_mm: f32,
    pub z_mm: f32,
}

/// Coordinate transformer between host frame and organ-specific frame.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct CoordTransform {
    pub host_to_organ: Matrix4<f32>,
    pub organ_to_host: Matrix4<f32>,
}

impl CoordTransform {
    pub fn identity() -> Self {
        Self {
            host_to_organ: Matrix4::identity(),
            organ_to_host: Matrix4::identity(),
        }
    }

    pub fn host_to_organ_point(&self, host: HostCoord) -> HostCoord {
        let p = Point3::new(host.x_mm, host.y_mm, host.z_mm);
        let v = self.host_to_organ.transform_point(&p);
        HostCoord {
            x_mm: v.x,
            y_mm: v.y,
            z_mm: v.z,
        }
    }

    pub fn organ_to_host_point(&self, organ: HostCoord) -> HostCoord {
        let p = Point3::new(organ.x_mm, organ.y_mm, organ.z_mm);
        let v = self.organ_to_host.transform_point(&p);
        HostCoord {
            x_mm: v.x,
            y_mm: v.y,
            z_mm: v.z,
        }
    }
}

/// Simple voxel grid header for binary atlas files.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct VoxelGridMeta {
    pub dim_x: u32,
    pub dim_y: u32,
    pub dim_z: u32,
    pub voxel_size_mm: f32,
}

/// Nanoswarm trajectory sample in host coordinates.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct NanoSample {
    pub t_ms: u64,
    pub pos: HostCoord,
}

/// Allowed tissue region descriptor.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct AllowedRegion {
    pub tissue: TissueClass,
    pub margin_mm: f32,
}

/// Simple AABB for fast inclusion checks in host space.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct HostAabb {
    pub min: HostCoord,
    pub max: HostCoord,
}

impl HostAabb {
    pub fn contains(&self, p: HostCoord) -> bool {
        p.x_mm >= self.min.x_mm
            && p.x_mm <= self.max.x_mm
            && p.y_mm >= self.min.y_mm
            && p.y_mm <= self.max.y_mm
            && p.z_mm >= self.min.z_mm
            && p.z_mm <= self.max.z_mm
    }
}
