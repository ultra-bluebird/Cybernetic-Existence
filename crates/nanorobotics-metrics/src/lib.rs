//! Nanorobotics Metrics: Prometheus observability for nanoswarm operations.
//!
//! This crate provides Prometheus metric definitions and registration for:
//! - Guard enforcement outcomes (allow/deny/defer counts)
//! - Safety envelope breaches (thermal, duty, energy)
//! - HostBudget utilization metrics
//! - Neurorights constraint violations
//! - CI/CD gating metrics for manifest validation

use once_cell::sync::Lazy;
use prometheus::{register_counter_vec, register_gauge_vec, CounterVec, GaugeVec, HistogramVec};

// ============================================================================
// Guard Enforcement Metrics
// ============================================================================

/// Total guard evaluations by guard layer and result.
pub static GUARD_EVALUATIONS_TOTAL: Lazy<CounterVec> = Lazy::new(|| {
    register_counter_vec!(
        "guard_evaluations_total",
        "Total guard evaluations by layer and result.",
        &["layer", "result", "host_did"]
    )
    .expect("guard_evaluations_total registered")
});

/// Guard blocks by layer, reason, and host.
pub static GUARD_BLOCKS_TOTAL: Lazy<CounterVec> = Lazy::new(|| {
    register_counter_vec!(
        "guard_blocks_total",
        "Guard blocks by layer, reason, and host.",
        &["layer", "reason", "host_did"]
    )
    .expect("guard_blocks_total registered")
});

/// Current neurorights constraint status (0=ok, 1=violated).
pub static NEURORIGHTS_VIOLATION_ACTIVE: Lazy<GaugeVec> = Lazy::new(|| {
    register_gauge_vec!(
        "neurorights_violation_active",
        "Current neurorights constraint violation status.",
        &["constraint", "host_did"]
    )
    .expect("neurorights_violation_active registered")
});

// ============================================================================
// Safety Envelope Metrics
// ============================================================================

/// Current thermal envelope utilization (brain/core/skin deltas).
pub static THERMAL_DELTA_CELSIUS: Lazy<GaugeVec> = Lazy::new(|| {
    register_gauge_vec!(
        "thermal_delta_celsius",
        "Current temperature deltas from baseline.",
        &["sensor", "host_did"]
    )
    .expect("thermal_delta_celsius registered")
});

/// Thermal envelope ceiling violations.
pub static THERMAL_CEILING_VIOLATIONS_TOTAL: Lazy<CounterVec> = Lazy::new(|| {
    register_counter_vec!(
        "thermal_ceiling_violations_total",
        "Thermal envelope ceiling violations by sensor.",
        &["sensor", "host_did"]
    )
    .expect("thermal_ceiling_violations_total registered")
});

/// Current duty-cycle utilization [0.0, 1.0].
pub static DUTY_CYCLE_UTILIZATION: Lazy<GaugeVec> = Lazy::new(|| {
    register_gauge_vec!(
        "duty_cycle_utilization",
        "Current duty-cycle utilization fraction.",
        &["host_did"]
    )
    .expect("duty_cycle_utilization registered")
});

/// Duty-cycle ceiling violations.
pub static DUTY_CEILING_VIOLATIONS_TOTAL: Lazy<CounterVec> = Lazy::new(|| {
    register_counter_vec!(
        "duty_ceiling_violations_total",
        "Duty-cycle ceiling violations.",
        &["host_did"]
    )
    .expect("duty_ceiling_violations_total registered")
});

// ============================================================================
// HostBudget Metrics
// ============================================================================

/// Current energy budget utilization [0.0, 1.0].
pub static ENERGY_BUDGET_UTILIZATION: Lazy<GaugeVec> = Lazy::new(|| {
    register_gauge_vec!(
        "energy_budget_utilization",
        "Current energy budget utilization fraction.",
        &["host_did"]
    )
    .expect("energy_budget_utilization registered")
});

/// Current protein budget utilization [0.0, 1.0].
pub static PROTEIN_BUDGET_UTILIZATION: Lazy<GaugeVec> = Lazy::new(|| {
    register_gauge_vec!(
        "protein_budget_utilization",
        "Current protein budget utilization fraction.",
        &["host_did"]
    )
    .expect("protein_budget_utilization registered")
});

/// Residual risk scalar V_t for KER evaluation.
pub static RESIDUAL_RISK_VT: Lazy<GaugeVec> = Lazy::new(|| {
    register_gauge_vec!(
        "residual_risk_vt",
        "Current residual risk scalar V_t.",
        &["host_did"]
    )
    .expect("residual_risk_vt registered")
});

// ============================================================================
// ALN/Manifest Validation Metrics
// ============================================================================

/// ALN compliance failures by clause and upgrade.
pub static ALN_COMPLIANCE_FAILED_TOTAL: Lazy<CounterVec> = Lazy::new(|| {
    register_counter_vec!(
        "aln_compliance_failed_total",
        "ALN compliance failures by clause and upgrade.",
        &["clause_id", "upgrade_id", "host_did"]
    )
    .expect("aln_compliance_failed_total registered")
});

/// Evidence bundle validation failures.
pub static EVIDENCE_VALIDATION_FAILED_TOTAL: Lazy<CounterVec> = Lazy::new(|| {
    register_counter_vec!(
        "evidence_validation_failed_total",
        "Evidence bundle validation failures by reason.",
        &["reason", "host_did"]
    )
    .expect("evidence_validation_failed_total registered")
});

/// Evolution audit gap count (manifest vs runtime).
pub static EVOLUTION_AUDIT_GAP_COUNT: Lazy<CounterVec> = Lazy::new(|| {
    register_counter_vec!(
        "evolution_audit_gap_count",
        "Audit gaps between manifest and runtime.",
        &["kind", "host_did"]
    )
    .expect("evolution_audit_gap_count registered")
});

// ============================================================================
// Latency and Performance Metrics
// ============================================================================

/// Guard evaluation latency histogram.
pub static GUARD_EVALUATION_LATENCY_SECONDS: Lazy<HistogramVec> = Lazy::new(|| {
    prometheus::register_histogram_vec!(
        "guard_evaluation_latency_seconds",
        "Guard evaluation latency in seconds.",
        &["layer", "host_did"],
        vec![0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0]
    )
    .expect("guard_evaluation_latency_seconds registered")
});

/// Scheduler decision latency histogram.
pub static SCHEDULER_DECISION_LATENCY_SECONDS: Lazy<HistogramVec> = Lazy::new(|| {
    prometheus::register_histogram_vec!(
        "scheduler_decision_latency_seconds",
        "Scheduler decision latency in seconds.",
        &["host_did"],
        vec![0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0]
    )
    .expect("scheduler_decision_latency_seconds registered")
});

// ============================================================================
// Helper Functions
// ============================================================================

/// Record a guard evaluation outcome.
pub fn record_guard_evaluation(layer: &str, result: &str, host_did: &str) {
    GUARD_EVALUATIONS_TOTAL
        .with_label_values(&[layer, result, host_did])
        .inc();
}

/// Record a guard block with reason.
pub fn record_guard_block(layer: &str, reason: &str, host_did: &str) {
    GUARD_BLOCKS_TOTAL
        .with_label_values(&[layer, reason, host_did])
        .inc();
}

/// Update thermal delta gauge.
pub fn update_thermal_delta(sensor: &str, delta_c: f32, host_did: &str) {
    THERMAL_DELTA_CELSIUS
        .with_label_values(&[sensor, host_did])
        .set(delta_c as f64);
}

/// Update duty-cycle utilization gauge.
pub fn update_duty_utilization(utilization: f32, host_did: &str) {
    DUTY_CYCLE_UTILIZATION
        .with_label_values(&[host_did])
        .set(utilization as f64);
}

/// Update energy budget utilization gauge.
pub fn update_energy_utilization(utilization: f32, host_did: &str) {
    ENERGY_BUDGET_UTILIZATION
        .with_label_values(&[host_did])
        .set(utilization as f64);
}

/// Update residual risk gauge.
pub fn update_residual_risk(v_t: f32, host_did: &str) {
    RESIDUAL_RISK_VT
        .with_label_values(&[host_did])
        .set(v_t as f64);
}

/// Record an ALN compliance failure.
pub fn record_aln_failure(clause_id: &str, upgrade_id: &str, host_did: &str) {
    ALN_COMPLIANCE_FAILED_TOTAL
        .with_label_values(&[clause_id, upgrade_id, host_did])
        .inc();
}

/// Record an evidence validation failure.
pub fn record_evidence_failure(reason: &str, host_did: &str) {
    EVIDENCE_VALIDATION_FAILED_TOTAL
        .with_label_values(&[reason, host_did])
        .inc();
}
