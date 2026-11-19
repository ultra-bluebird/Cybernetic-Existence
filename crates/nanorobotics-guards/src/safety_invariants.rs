use serde::{Deserialize, Serialize};
use nanorobotics_core::{HostBudget, SafetyEnvelope, RiskCoordinates, ResidualRisk};

/// SafetyInvariant: A named safety constraint with evaluation logic.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SafetyInvariant {
    /// Unique identifier for the invariant.
    pub id: String,
    /// Human-readable description.
    pub description: String,
    /// Whether violation of this invariant is fatal (blocks all actuation).
    pub is_fatal: bool,
    /// Optional reference to evidence bundle ID supporting this invariant.
    pub evidence_bundle_id: Option<String>,
}

/// ViolationReport: Details of a safety invariant violation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ViolationReport {
    /// Invariant that was violated.
    pub invariant_id: String,
    /// Current value that caused the violation.
    pub current_value: f32,
    /// Threshold that was exceeded.
    pub threshold: f32,
    /// Timestamp of violation.
    pub timestamp: i64,
    /// Optional remediation suggestion.
    pub remediation: Option<String>,
}

/// InvariantChecker: Evaluates safety invariants against current host state.
pub struct InvariantChecker {
    invariants: Vec<SafetyInvariant>,
    host_budget: HostBudget,
    safety_envelope: SafetyEnvelope,
}

impl InvariantChecker {
    /// Create a new checker with the given invariants and constraints.
    pub fn new(
        invariants: Vec<SafetyInvariant>,
        host_budget: HostBudget,
        safety_envelope: SafetyEnvelope,
    ) -> Self {
        Self {
            invariants,
            host_budget,
            safety_envelope,
        }
    }

    /// Check all invariants against current risk coordinates and residual risk.
    pub fn check(
        &self,
        risk: &RiskCoordinates,
        residual: &ResidualRisk,
        previous_residual: Option<&ResidualRisk>,
    ) -> Vec<ViolationReport> {
        let mut violations = Vec::new();
        let now = chrono::Utc::now().timestamp();

        for invariant in &self.invariants {
            if let Some(violation) = self.evaluate_invariant(invariant, risk, residual, previous_residual, now) {
                violations.push(violation);
                // Fatal violations short-circuit further checking
                if invariant.is_fatal {
                    break;
                }
            }
        }
        violations
    }

    /// Evaluate a single invariant and return a violation report if violated.
    fn evaluate_invariant(
        &self,
        invariant: &SafetyInvariant,
        risk: &RiskCoordinates,
        residual: &ResidualRisk,
        previous_residual: Option<&ResidualRisk>,
        timestamp: i64,
    ) -> Option<ViolationReport> {
        match invariant.id.as_str() {
            "roh_ceiling" => {
                let roh = self.compute_roh(risk);
                if roh > 0.30 {
                    Some(ViolationReport {
                        invariant_id: invariant.id.clone(),
                        current_value: roh,
                        threshold: 0.30,
                        timestamp,
                        remediation: Some("reduce nanoswarm duty or energy consumption".to_string()),
                    })
                } else {
                    None
                }
            }
            "residual_non_increase" => {
                if let Some(prev) = previous_residual {
                    if residual.v_t > prev.v_t {
                        Some(ViolationReport {
                            invariant_id: invariant.id.clone(),
                            current_value: residual.v_t,
                            threshold: prev.v_t,
                            timestamp,
                            remediation: Some("revert to previous safe configuration".to_string()),
                        })
                    } else {
                        None
                    }
                } else {
                    None
                }
            }
            "thermal_envelope" => {
                // Thermal checks are handled by ThermalGuard; this is a backup invariant
                if risk.r_brain_temp > 1.0 || risk.r_core_temp > 1.0 {
                    Some(ViolationReport {
                        invariant_id: invariant.id.clone(),
                        current_value: risk.r_brain_temp.max(risk.r_core_temp),
                        threshold: 1.0,
                        timestamp,
                        remediation: Some("pause nanoswarm operations to allow thermal recovery".to_string()),
                    })
                } else {
                    None
                }
            }
            "duty_fraction_limit" => {
                if risk.r_duty > 1.0 {
                    Some(ViolationReport {
                        invariant_id: invariant.id.clone(),
                        current_value: risk.r_duty,
                        threshold: 1.0,
                        timestamp,
                        remediation: Some("reduce nanoswarm actuation duty cycle".to_string()),
                    })
                } else {
                    None
                }
            }
            _ => None, // Unknown invariant; could log warning in production
        }
    }

    /// Compute Risk-of-Harm from risk coordinates using weighted sum.
    fn compute_roh(&self, risk: &RiskCoordinates) -> f32 {
        // Equal weights for simplicity; could be configurable
        (risk.r_energy + risk.r_protein + risk.r_brain_temp + risk.r_core_temp + risk.r_duty) / 5.0
    }

    /// Add a new invariant to the checker.
    pub fn add_invariant(&mut self, invariant: SafetyInvariant) {
        self.invariants.push(invariant);
    }

    /// Get the list of configured invariants.
    pub fn invariants(&self) -> &[SafetyInvariant] {
        &self.invariants
    }
}
