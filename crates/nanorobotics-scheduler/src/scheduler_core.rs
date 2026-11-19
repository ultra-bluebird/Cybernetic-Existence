use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use nanorobotics_core::{HostBudget, SafetyEnvelope};
use crate::{DutyScheduler, ThermalGuard, EnergyAllocator, PowerProfile};

/// ScheduleRequest: A request to schedule a nanoswarm operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScheduleRequest {
    /// Unique identifier for the request.
    pub request_id: String,
    /// Operation name or type.
    pub operation_name: String,
    /// Required safety envelope for the operation.
    pub required_envelope: SafetyEnvelope,
    /// Estimated energy consumption in joules.
    pub estimated_energy_joules: f32,
    /// Estimated duration in seconds.
    pub estimated_duration_sec: u64,
    /// Priority level for scheduling (higher = more urgent).
    pub priority: u8,
    /// Optional deadline timestamp for completion.
    pub deadline: Option<DateTime<Utc>>,
}

/// ScheduleDecision: The result of evaluating a schedule request.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum ScheduleDecision {
    /// Operation can proceed immediately.
    Allow,
    /// Operation must wait; retry after specified seconds.
    Defer { retry_after_seconds: u64 },
    /// Operation cannot be scheduled; violates constraints.
    Deny { reason: String },
}

/// SwarmScheduler: Core scheduler that coordinates duty, thermal, and energy constraints.
pub struct SwarmScheduler {
    host_budget: HostBudget,
    duty_scheduler: DutyScheduler,
    thermal_guard: ThermalGuard,
    energy_allocator: EnergyAllocator,
}

impl SwarmScheduler {
    /// Create a new scheduler with the given host budget and component configurations.
    pub fn new(
        host_budget: HostBudget,
        duty_config: crate::DutyCycleConfig,
        thermal_envelope: crate::ThermalEnvelope,
        energy_budget: crate::EnergyBudget,
    ) -> Self {
        Self {
            host_budget,
            duty_scheduler: DutyScheduler::new(
                duty_config,
                crate::DutyCycleState {
                    last_updated: Utc::now(),
                    is_active: false,
                    continuous_active_seconds: 0,
                    continuous_cooldown_seconds: duty_config.min_cooldown_seconds,
                    rolling_duty_fraction: 0.0,
                    duty_seconds_in_window: 0,
                },
            ),
            thermal_guard: ThermalGuard::new(thermal_envelope),
            energy_allocator: EnergyAllocator::new(energy_budget),
        }
    }

    /// Evaluate a schedule request and return a decision.
    pub fn evaluate(&self, request: &ScheduleRequest, current_temp: &crate::TemperatureReading) -> ScheduleDecision {
        // Check duty-cycle constraints
        if !self.duty_scheduler.can_start_duty() {
            return ScheduleDecision::Defer {
                retry_after_seconds: self.duty_scheduler.config().min_cooldown_seconds,
            };
        }

        // Check thermal constraints
        if let Err(e) = self.thermal_guard.validate(current_temp) {
            return ScheduleDecision::Deny {
                reason: format!("thermal constraint violated: {}", e),
            };
        }

        // Check energy constraints
        let power_profile = PowerProfile {
            operation_id: request.request_id.clone(),
            avg_watts: request.estimated_energy_joules / request.estimated_duration_sec as f32,
            peak_watts: request.estimated_energy_joules / (request.estimated_duration_sec as f32 * 0.5),
            estimated_duration_sec: request.estimated_duration_sec,
            priority: request.priority,
        };
        
        if !self.energy_allocator.can_schedule(&power_profile) {
            return ScheduleDecision::Deny {
                reason: "insufficient energy budget".to_string(),
            };
        }

        // Check safety envelope compatibility
        if !self.is_envelope_compatible(&request.required_envelope) {
            return ScheduleDecision::Deny {
                reason: "required safety envelope incompatible with host constraints".to_string(),
            };
        }

        ScheduleDecision::Allow
    }

    /// Check if a required safety envelope is compatible with host constraints.
    fn is_envelope_compatible(&self, required: &SafetyEnvelope) -> bool {
        required.thermal.max_brain_delta_c <= self.thermal_guard.envelope().max_brain_delta_c
            && required.thermal.max_core_delta_c <= self.thermal_guard.envelope().max_core_delta_c
            && required.actuation.max_duty_fraction <= self.duty_scheduler.config().max_duty_fraction
    }

    /// Commit a scheduled operation, updating internal state.
    pub fn commit(&mut self, request: &ScheduleRequest) -> bool {
        let power_profile = PowerProfile {
            operation_id: request.request_id.clone(),
            avg_watts: request.estimated_energy_joules / request.estimated_duration_sec as f32,
            peak_watts: request.estimated_energy_joules / (request.estimated_duration_sec as f32 * 0.5),
            estimated_duration_sec: request.estimated_duration_sec,
            priority: request.priority,
        };
        
        if !self.energy_allocator.allocate(power_profile) {
            return false;
        }
        
        // Update duty scheduler state
        let now = Utc::now();
        self.duty_scheduler.update(now, true);
        
        true
    }

    /// Complete a scheduled operation, freeing allocated resources.
    pub fn complete(&mut self, request_id: &str) {
        self.energy_allocator.deallocate(request_id);
        let now = Utc::now();
        self.duty_scheduler.update(now, false);
    }

    /// Update thermal readings and check for constraint violations.
    pub fn update_thermal(&mut self, reading: crate::TemperatureReading) -> Result<(), crate::ThermalGuardError> {
        self.thermal_guard.update(reading)
    }

    /// Get the current scheduler state summary.
    pub fn state_summary(&self) -> SchedulerStateSummary {
        SchedulerStateSummary {
            duty_utilization: self.duty_scheduler.state().rolling_duty_fraction,
            thermal_margin: self.thermal_margin(),
            energy_utilization: self.energy_allocator.utilization(),
            available_energy: self.energy_allocator.available_energy(),
        }
    }

    /// Calculate the thermal margin as a fraction of remaining headroom.
    fn thermal_margin(&self) -> f32 {
        if let Some(reading) = self.thermal_guard.last_reading() {
            let brain_margin = (self.thermal_guard.envelope().max_brain_delta_c - reading.brain_delta_c)
                / self.thermal_guard.envelope().max_brain_delta_c;
            let core_margin = (self.thermal_guard.envelope().max_core_delta_c - reading.core_delta_c)
                / self.thermal_guard.envelope().max_core_delta_c;
            brain_margin.min(core_margin).max(0.0)
        } else {
            1.0
        }
    }
}

/// SchedulerStateSummary: A snapshot of the scheduler's current state.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SchedulerStateSummary {
    /// Current duty-cycle utilization [0.0, 1.0].
    pub duty_utilization: f32,
    /// Thermal margin as fraction of remaining headroom [0.0, 1.0].
    pub thermal_margin: f32,
    /// Energy budget utilization [0.0, 1.0].
    pub energy_utilization: f32,
    /// Available energy in joules.
    pub available_energy: f32,
}
