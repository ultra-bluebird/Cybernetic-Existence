use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// EnergyBudget: Host-level energy constraints for nanoswarm operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnergyBudget {
    /// Maximum daily energy budget in joules.
    pub max_daily_joules: f32,
    /// Maximum instantaneous power draw in watts.
    pub max_instantaneous_watts: f32,
    /// Minimum reserve energy that must remain unused in joules.
    pub min_reserve_joules: f32,
}

/// PowerProfile: Energy consumption profile for a nanoswarm operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PowerProfile {
    /// Operation identifier.
    pub operation_id: String,
    /// Average power consumption in watts.
    pub avg_watts: f32,
    /// Peak power consumption in watts.
    pub peak_watts: f32,
    /// Estimated duration in seconds.
    pub estimated_duration_sec: u64,
    /// Priority level for scheduling (higher = more important).
    pub priority: u8,
}

/// EnergyAllocator: Manages energy budget allocation across competing operations.
pub struct EnergyAllocator {
    budget: EnergyBudget,
    allocated_joules: f32,
    active_operations: HashMap<String, PowerProfile>,
}

impl EnergyAllocator {
    /// Create a new allocator with the given energy budget.
    pub fn new(budget: EnergyBudget) -> Self {
        Self {
            budget,
            allocated_joules: 0.0,
            active_operations: HashMap::new(),
        }
    }

    /// Check if a new operation can be scheduled within the energy budget.
    pub fn can_schedule(&self, profile: &PowerProfile) -> bool {
        let estimated_energy = profile.avg_watts * profile.estimated_duration_sec as f32;
        let available = self.budget.max_daily_joules 
            - self.allocated_joules 
            - self.budget.min_reserve_joules;
        
        if estimated_energy > available {
            return false;
        }
        if profile.peak_watts > self.budget.max_instantaneous_watts {
            return false;
        }
        true
    }

    /// Allocate energy for a new operation. Returns true if allocation succeeded.
    pub fn allocate(&mut self, profile: PowerProfile) -> bool {
        if !self.can_schedule(&profile) {
            return false;
        }
        let estimated_energy = profile.avg_watts * profile.estimated_duration_sec as f32;
        self.allocated_joules += estimated_energy;
        self.active_operations.insert(profile.operation_id.clone(), profile);
        true
    }

    /// Deallocate energy for a completed operation.
    pub fn deallocate(&mut self, operation_id: &str) -> bool {
        if let Some(profile) = self.active_operations.remove(operation_id) {
            let estimated_energy = profile.avg_watts * profile.estimated_duration_sec as f32;
            self.allocated_joules = (self.allocated_joules - estimated_energy).max(0.0);
            true
        } else {
            false
        }
    }

    /// Get the remaining available energy in joules.
    pub fn available_energy(&self) -> f32 {
        (self.budget.max_daily_joules 
            - self.allocated_joules 
            - self.budget.min_reserve_joules).max(0.0)
    }

    /// Get the current energy utilization as a fraction [0.0, 1.0].
    pub fn utilization(&self) -> f32 {
        self.allocated_joules / self.budget.max_daily_joules
    }

    /// Get the list of active operations.
    pub fn active_operations(&self) -> &HashMap<String, PowerProfile> {
        &self.active_operations
    }

    /// Reset the allocator for a new day.
    pub fn reset_daily(&mut self) {
        self.allocated_joules = 0.0;
        self.active_operations.clear();
    }
}
