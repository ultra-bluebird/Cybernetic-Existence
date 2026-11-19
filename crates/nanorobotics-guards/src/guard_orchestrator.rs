use serde::{Deserialize, Serialize};
use nanorobotics_core::{HostBudget, SafetyEnvelope};
use nanorobotics_scheduler::{SwarmScheduler, ScheduleRequest, ScheduleDecision, TemperatureReading};
use crate::{NeurorightsEnforcer, PainFearClamp, InvariantChecker, NociceptiveIndex, ViolationReport};

/// GuardDecision: Unified decision output from the guard orchestrator.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum GuardDecision {
    /// All guards passed; operation may proceed.
    Allow,
    /// Operation deferred; retry after specified conditions.
    Defer { reason: String, retry_hint: Option<String> },
    /// Operation denied; safety constraint violated.
    Deny { reason: String, violations: Vec<ViolationReport> },
}

/// GuardContext: Aggregated state for guard evaluation.
#[derive(Debug, Clone)]
pub struct GuardContext {
    /// Current host budget state.
    pub host_budget: HostBudget,
    /// Current safety envelope.
    pub safety_envelope: SafetyEnvelope,
    /// Current temperature readings.
    pub temperature: TemperatureReading,
    /// Current nociceptive indices.
    pub nociceptive: NociceptiveIndex,
    /// Previous residual risk for non-increase invariant.
    pub previous_residual: Option<nanorobotics_core::ResidualRisk>,
}

/// GuardOrchestrator: Coordinates all guard layers for nanoswarm operations.
pub struct GuardOrchestrator {
    neurorights: NeurorightsEnforcer,
    pain_fear_clamp: PainFearClamp,
    invariant_checker: InvariantChecker,
    scheduler: SwarmScheduler,
}

impl GuardOrchestrator {
    /// Create a new orchestrator with all guard components.
    pub fn new(
        neurorights: NeurorightsEnforcer,
        pain_fear_clamp: PainFearClamp,
        invariant_checker: InvariantChecker,
        scheduler: SwarmScheduler,
    ) -> Self {
        Self {
            neurorights,
            pain_fear_clamp,
            invariant_checker,
            scheduler,
        }
    }

    /// Evaluate a schedule request through all guard layers.
    pub fn evaluate(&self, request: &ScheduleRequest, context: &GuardContext) -> GuardDecision {
        // Layer 1: Neurorights enforcement
        if let Err(e) = self.neurorights.validate(
            &request.operation_name,
            context.nociceptive.pain,
            context.nociceptive.fear,
            false, // exports_raw_neural_data
            false, // is_coercive
            false, // disrupts_identity
        ) {
            return GuardDecision::Deny {
                reason: format!("neurorights violation: {}", e),
                violations: Vec::new(),
            };
        }

        // Layer 2: Pain/fear clamp (hardware pre-guard)
        let clamp = self.pain_fear_clamp.compute(context.nociceptive);
        if clamp.value() < 0.1 {
            // Near-zero clamp indicates severe nociceptive state
            return GuardDecision::Deny {
                reason: "pain/fear clamp factor too low for safe operation".to_string(),
                violations: Vec::new(),
            };
        }

        // Layer 3: Safety invariant checking
        let risk = self.compute_risk_coordinates(context, request);
        let residual = self.compute_residual_risk(&risk);
        let violations = self.invariant_checker.check(
            &risk,
            &residual,
            context.previous_residual.as_ref(),
        );
        if !violations.is_empty() {
            let fatal = violations.iter().any(|v| {
                self.invariant_checker.invariants()
                    .iter()
                    .find(|inv| inv.id == v.invariant_id)
                    .map_or(false, |inv| inv.is_fatal)
            });
            if fatal {
                return GuardDecision::Deny {
                    reason: "fatal safety invariant violation".to_string(),
                    violations,
                };
            }
        }

        // Layer 4: Scheduler constraints (duty, thermal, energy)
        match self.scheduler.evaluate(request, &context.temperature) {
            ScheduleDecision::Allow => GuardDecision::Allow,
            ScheduleDecision::Defer { retry_after_seconds } => GuardDecision::Defer {
                reason: format!("scheduler defer: retry after {} seconds", retry_after_seconds),
                retry_hint: Some(format!("wait_{}_seconds", retry_after_seconds)),
            },
            ScheduleDecision::Deny { reason } => GuardDecision::Deny {
                reason: format!("scheduler denial: {}", reason),
                violations,
            },
        }
    }

    /// Compute risk coordinates from guard context and request.
    fn compute_risk_coordinates(
        &self,
        context: &GuardContext,
        request: &ScheduleRequest,
    ) -> nanorobotics_core::RiskCoordinates {
        // Simplified risk computation; in production, use full HostBudget logic
        let duty_risk = request.estimated_duration_sec as f32 / 3600.0; // fraction of hour
        let energy_risk = request.estimated_energy_joules / context.host_budget.max_energy_joules;
        nanorobotics_core::RiskCoordinates {
            r_energy: energy_risk.clamp(0.0, 1.0),
            r_protein: 0.0, // Simplified
            r_brain_temp: (context.temperature.brain_delta_c / context.safety_envelope.thermal.max_brain_delta_c).clamp(0.0, 1.0),
            r_core_temp: (context.temperature.core_delta_c / context.safety_envelope.thermal.max_core_delta_c).clamp(0.0, 1.0),
            r_duty: duty_risk.clamp(0.0, 1.0),
        }
    }

    /// Compute residual risk from risk coordinates.
    fn compute_residual_risk(&self, risk: &nanorobotics_core::RiskCoordinates) -> nanorobotics_core::ResidualRisk {
        // Equal weights for simplicity
        nanorobotics_core::ResidualRisk {
            v_t: (risk.r_energy.powi(2)
                + risk.r_protein.powi(2)
                + risk.r_brain_temp.powi(2)
                + risk.r_core_temp.powi(2)
                + risk.r_duty.powi(2)) / 5.0,
        }
    }

    /// Commit an allowed operation, updating internal state.
    pub fn commit(&mut self, request: &ScheduleRequest) -> bool {
        self.scheduler.commit(request)
    }

    /// Complete an operation, freeing resources.
    pub fn complete(&mut self, request_id: &str) {
        self.scheduler.complete(request_id);
    }

    /// Update nociceptive indices and return the current clamp factor.
    pub fn update_nociceptive(&mut self, indices: NociceptiveIndex) -> f32 {
        self.pain_fear_clamp.compute(indices).value()
    }

    /// Update temperature readings and check thermal constraints.
    pub fn update_temperature(&mut self, reading: TemperatureReading) -> Result<(), nanorobotics_scheduler::ThermalGuardError> {
        self.scheduler.update_thermal(reading)
    }
}
