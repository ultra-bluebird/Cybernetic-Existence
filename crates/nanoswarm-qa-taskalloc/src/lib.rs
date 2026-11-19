#![cfg_attr(not(test), deny(warnings))]
// Rust 2024, rust-version = "1.85"
use serde::{Deserialize, Serialize};

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum NodeState {
    Scavenge,
    Repair,
    Idle,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeAssignment {
    // length = N_nodes
    pub states: Vec<NodeState>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DensityCorridor {
    pub region_id: u32,
    pub phi_max: f32, // maximum allowed volume fraction
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnergyBudget {
    pub e_max: f32, // global budget
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AllocationParams {
    pub density_corridors: Vec<DensityCorridor>,
    // node_state_density[i][s][k] = contribution to region k
    pub node_state_density: Vec<Vec<Vec<f32>>>,
    // per-node, per-state energy cost
    pub node_state_energy: Vec<Vec<f32>>,
    pub energy_budget: EnergyBudget,
    pub roh_ceiling: f32, // <= 0.30
}

/// Pure, deterministic checker: no allocations, suitable for Kani.
pub fn verify_assignment(
    assignment: &NodeAssignment,
    params: &AllocationParams,
) -> Result<(), &'static str> {
    let n = assignment.states.len();
    if n != params.node_state_density.len() {
        return Err("dimension_mismatch");
    }

    // Check density corridors
    for corridor in &params.density_corridors {
        let mut total_phi = 0.0f32;
        let k = corridor.region_id as usize;
        for (i, state) in assignment.states.iter().enumerate() {
            let s_idx = match state {
                NodeState::Scavenge => 0,
                NodeState::Repair => 1,
                NodeState::Idle => 2,
            };
            let dens_table = &params.node_state_density[i];
            if s_idx >= dens_table.len() {
                return Err("state_index_out_of_range");
            }
            let region_vec = &dens_table[s_idx];
            if k >= region_vec.len() {
                return Err("region_index_out_of_range");
            }
            total_phi += region_vec[k];
        }
        if total_phi > corridor.phi_max {
            return Err("density_corridor_violation");
        }
    }

    // Check energy budget
    let mut total_energy = 0.0f32;
    for (i, state) in assignment.states.iter().enumerate() {
        let s_idx = match state {
            NodeState::Scavenge => 0,
            NodeState::Repair => 1,
            NodeState::Idle => 2,
        };
        let e_table = &params.node_state_energy[i];
        if s_idx >= e_table.len() {
            return Err("state_index_out_of_range_energy");
        }
        total_energy += e_table[s_idx];
    }
    if total_energy > params.energy_budget.e_max {
        return Err("energy_budget_violation");
    }

    // Map density + energy to a local RoH slice using your unified kernel.
    // Here we use a simple monotone proxy; real code will call the RoH crate.
    let roh_slice = roh_proxy(total_energy);
    if roh_slice > params.roh_ceiling {
        return Err("roh_ceiling_violation");
    }

    Ok(())
}

fn roh_proxy(total_energy: f32) -> f32 {
    // Monotone map: higher energy implies higher RoH, clipped to [0,1].
    let mut r = 0.0f32;
    if total_energy > 0.0 {
        r = (total_energy / 1.0e3).min(1.0);
    }
    r
}
