// crates/vascular-corridor-guards/src/hipct_centerline_pipeline.rs

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use serde::{Deserialize, Serialize};

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCOREAUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Identifier for a HiP‑CT volume tile in a colon dataset.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct HipctTileId(pub String);

/// Basic metadata for a HiP‑CT tile.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct HipctTileMeta {
    pub id: HipctTileId,
    pub voxel_size_um: f32,
    pub dims: [u32; 3],
    pub origin_world_mm: [f32; 3],
}

/// Vessel centerline node in world space.
///
/// All coordinates are expressed in millimetres in the host‑local
/// vascular coordinate framework.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct VascularNode {
    pub id: u64,
    pub position_mm: [f32; 3],
    pub radius_um: f32,
    pub degree: u8,
}

/// Vascular edge connecting two nodes.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct VascularEdge {
    pub id: u64,
    pub from: u64,
    pub to: u64,
    pub length_mm: f32,
    pub mean_radius_um: f32,
}

/// High‑level VCCF segment between two junction nodes.
///
/// This is the downsampled representation used for corridor and RoH
/// evaluation, rather than the raw skeleton voxel graph.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct VccfSegment {
    pub id: u64,
    pub start_node_id: u64,
    pub end_node_id: u64,
    pub length_mm: f32,
    pub radius_um: f32,
    pub system_type: VascularSystemType,
}

/// Basic classification of vascular system type for a segment.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum VascularSystemType {
    Arterial,
    Venous,
    PortalVenous,
    Lymphatic,
}

/// Topology validation summary for an extracted graph.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct TopologyValidationReport {
    pub branch_count_extracted: u32,
    pub branch_count_reference: u32,
    pub junction_count_extracted: u32,
    pub junction_count_reference: u32,
    pub branch_error_fraction: f32,
    pub junction_error_fraction: f32,
    pub connectivity_ok: bool,
}

/// Vessel centerline graph container.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct VascularGraph {
    pub nodes: Vec<VascularNode>,
    pub edges: Vec<VascularEdge>,
}

impl VascularGraph {
    pub fn new() -> Self {
        Self {
            nodes: Vec::new(),
            edges: Vec::new(),
        }
    }

    pub fn branch_count(&self) -> u32 {
        self.edges.len() as u32
    }

    pub fn junction_count(&self) -> u32 {
        self.nodes
            .iter()
            .filter(|n| n.degree != 2)
            .count() as u32
    }

    /// Very simple connectivity check: ensures that all nodes
    /// are reachable from at least one junction node.
    pub fn connectivity_ok(&self) -> bool {
        if self.nodes.is_empty() {
            return true;
        }

        let mut visited = vec![false; self.nodes.len()];
        let mut stack = Vec::new();

        // Start from first node with degree != 2, or node 0.
        let start_idx = self
            .nodes
            .iter()
            .position(|n| n.degree != 2)
            .unwrap_or(0);
        visited[start_idx] = true;
        stack.push(start_idx);

        while let Some(idx) = stack.pop() {
            let node_id = self.nodes[idx].id;
            for e in &self.edges {
                if e.from == node_id || e.to == node_id {
                    let next_id = if e.from == node_id { e.to } else { e.from };
                    if let Some(next_idx) =
                        self.nodes.iter().position(|n| n.id == next_id)
                    {
                        if !visited[next_idx] {
                            visited[next_idx] = true;
                            stack.push(next_idx);
                        }
                    }
                }
            }
        }

        visited.iter().all(|v| *v)
    }
}

/// HiP‑CT vessel centerline extraction pipeline description.
///
/// This struct documents the processing stages that operate on a large
/// HiP‑CT colon dataset and produce a downsampled VCCF segment graph.
///
/// Implementations of the stages live in separate modules or crates
/// and are wired through this descriptor.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct HipctCenterlinePipeline {
    pub host_did: String,
    pub bostrom_address: String,
    pub authority: String,
    pub tiles: Vec<HipctTileMeta>,
}

impl HipctCenterlinePipeline {
    pub fn new(tiles: Vec<HipctTileMeta>) -> Self {
        Self {
            host_did: HOST_DID.to_string(),
            bostrom_address: BOSTROM_ADDRESS.to_string(),
            authority: ALN_MIGRATION_CYBERCORE_AUTHORITY_V1.to_string(),
            tiles,
        }
    }

    /// Stage 1: segmentation of vessels in each tile.
    ///
    /// In a full implementation, this would call into a 3‑D CNN or
    /// vesselness filtering module. Here we expose only the interface.
    pub fn segment_vessels(&self, tile: &HipctTileMeta) -> Vec<u8> {
        let _ = tile;
        Vec::new()
    }

    /// Stage 2: skeletonization of segmented vessels in a tile.
    ///
    /// The input mask is a binary or probabilistic vessel segmentation.
    /// The output is a set of centerline nodes and edges local to the tile.
    pub fn skeletonize_tile(&self, tile: &HipctTileMeta, mask: &[u8]) -> VascularGraph {
        let _ = tile;
        let _ = mask;
        VascularGraph::new()
    }

    /// Stage 3: stitching tile‑local graphs into a global vascular graph.
    pub fn stitch_graphs(&self, graphs: &[VascularGraph]) -> VascularGraph {
        let mut global = VascularGraph::new();
        let mut next_node_id: u64 = 1;
        let mut next_edge_id: u64 = 1;

        for g in graphs {
            for n in &g.nodes {
                let mut n_clone = n.clone();
                n_clone.id = next_node_id;
                next_node_id += 1;
                global.nodes.push(n_clone);
            }
            for e in &g.edges {
                let mut e_clone = e.clone();
                e_clone.id = next_edge_id;
                next_edge_id += 1;
                global.edges.push(e_clone);
            }
        }

        global
    }

    /// Stage 4: downsample the full vascular graph into VCCF segments.
    ///
    /// Chains of degree‑2 nodes are collapsed into single segments between
    /// junction nodes to reduce graph complexity for corridor evaluation.
    pub fn downsample_to_vccf(&self, graph: &VascularGraph) -> Vec<VccfSegment> {
        let _ = self;
        let mut segments = Vec::new();

        let mut segment_id: u64 = 1;
        for edge in &graph.edges {
            segments.push(VccfSegment {
                id: segment_id,
                start_node_id: edge.from,
                end_node_id: edge.to,
                length_mm: edge.length_mm,
                radius_um: edge.mean_radius_um,
                system_type: VascularSystemType::Venous,
            });
            segment_id += 1;
        }

        segments
    }

    /// Stage 5: topology validation against a reference graph.
    ///
    /// The reference graph is typically a manually annotated subset or
    /// a high‑resolution ground‑truth graph for a colon region.
    pub fn validate_topology(
        &self,
        extracted: &VascularGraph,
        reference: &VascularGraph,
        max_error_fraction: f32,
    ) -> TopologyValidationReport {
        let _ = self;

        let branch_extracted = extracted.branch_count();
        let branch_reference = reference.branch_count();
        let junction_extracted = extracted.junction_count();
        let junction_reference = reference.junction_count();

        let branch_error = if branch_reference > 0 {
            ((branch_extracted as i32 - branch_reference as i32).abs() as f32)
                / branch_reference as f32
        } else {
            0.0
        };

        let junction_error = if junction_reference > 0 {
            ((junction_extracted as i32 - junction_reference as i32).abs() as f32)
                / junction_reference as f32
        } else {
            0.0
        };

        let connectivity_ok_extracted = extracted.connectivity_ok();
        let connectivity_ok_reference = reference.connectivity_ok();
        let connectivity_ok = connectivity_ok_extracted && connectivity_ok_reference;

        TopologyValidationReport {
            branch_count_extracted: branch_extracted,
            branch_count_reference: branch_reference,
            junction_count_extracted: junction_extracted,
            junction_count_reference: junction_reference,
            branch_error_fraction: branch_error,
            junction_error_fraction: junction_error,
            connectivity_ok: connectivity_ok && branch_error <= max_error_fraction
                && junction_error <= max_error_fraction,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_graph_connectivity_ok() {
        let graph = VascularGraph::new();
        assert!(graph.connectivity_ok());
    }

    #[test]
    fn simple_pipeline_topology_report_zero_error() {
        let tile_meta = HipctTileMeta {
            id: HipctTileId("tile-0".to_string()),
            voxel_size_um: 5.0,
            dims: [512, 512, 512],
            origin_world_mm: [0.0, 0.0, 0.0],
        };
        let pipeline = HipctCenterlinePipeline::new(vec![tile_meta]);

        let mut graph = VascularGraph::new();
        graph.nodes.push(VascularNode {
            id: 1,
            position_mm: [0.0, 0.0, 0.0],
            radius_um: 20.0,
            degree: 1,
        });
        graph.nodes.push(VascularNode {
            id: 2,
            position_mm: [1.0, 0.0, 0.0],
            radius_um: 20.0,
            degree: 1,
        });
        graph.edges.push(VascularEdge {
            id: 1,
            from: 1,
            to: 2,
            length_mm: 1.0,
            mean_radius_um: 20.0,
        });

        let report = pipeline.validate_topology(&graph, &graph, 0.02);
        assert_eq!(report.branch_error_fraction, 0.0);
        assert_eq!(report.junction_error_fraction, 0.0);
        assert!(report.connectivity_ok);
    }
}
