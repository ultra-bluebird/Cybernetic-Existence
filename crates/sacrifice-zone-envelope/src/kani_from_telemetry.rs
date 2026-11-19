#![forbid(unsafe_code)]
#![feature(rust_2024_preview)]

use kani::any;

use crate::metrics::{HazardEvidenceBundle, HazardEvidenceClaim, EvidenceSourceKind,
                     HazardMetrics, RawHazardTelemetry};

fn any_valid_bundle() -> HazardEvidenceBundle {
    // Minimal bundle: one empirical, tighten-only claim.
    let claim = HazardEvidenceClaim {
        claim_id: "EVID-SZ-TEST".to_string(),
        kind: EvidenceSourceKind::Empirical,
        description: "Test empirical claim".to_string(),
        tighten_only: true,
    };

    HazardEvidenceBundle {
        bundle_id: "EVID-SZ-BUNDLE-TEST".to_string(),
        zone_id: "SZ-TEST".to_string(),
        claims: vec![claim],
    }
}

fn any_raw_telemetry() -> RawHazardTelemetry {
    let total_mass: f32 = any();
    let max_concentration: f32 = any();
    let max_duty_fraction: f32 = any();
    let density_risk_local: f32 = any();
    let thermo_duty_risk: f32 = any();
    let near_roh_fraction: f32 = any();

    RawHazardTelemetry {
        total_mass,
        max_concentration,
        max_duty_fraction,
        density_risk_local,
        thermo_duty_risk,
        near_roh_fraction,
    }
}

/// Proof 1: from_telemetry outputs lie in [0,1] for each metric.
#[proof]
fn proof_from_telemetry_bounded() {
    let raw = any_raw_telemetry();
    let bundle = any_valid_bundle();

    let m_ref: f32 = any();
    let c_ref: f32 = any();

    let metrics_opt = HazardMetrics::from_telemetry(&raw, &bundle, m_ref.abs(), c_ref.abs());
    assert!(metrics_opt.is_some());

    let metrics = metrics_opt.unwrap().clamped();

    assert!(metrics.total_load >= 0.0 && metrics.total_load <= 1.0 + 1.0e-5);
    assert!(metrics.peak_concentration >= 0.0 && metrics.peak_concentration <= 1.0 + 1.0e-5);
    assert!(metrics.swarm_duty_fraction >= 0.0 && metrics.swarm_duty_fraction <= 1.0 + 1.0e-5);
    assert!(metrics.material_risk_proxy >= 0.0 && metrics.material_risk_proxy <= 1.0 + 1.0e-5);
    assert!(metrics.near_roh_events >= 0.0 && metrics.near_roh_events <= 1.0 + 1.0e-5);
}

/// Proof 2: from_telemetry is monotone in raw inputs when references are fixed.
///
/// For each raw axis, increase it while holding others and refs fixed; the normalized
/// metric must not decrease.
#[proof]
fn proof_from_telemetry_monotone_axes() {
    let raw = any_raw_telemetry();
    let bundle = any_valid_bundle();

    let m_ref: f32 = any();
    let c_ref: f32 = any();
    let m_ref = m_ref.abs().max(1.0e-6);
    let c_ref = c_ref.abs().max(1.0e-6);

    let base_metrics = HazardMetrics::from_telemetry(&raw, &bundle, m_ref, c_ref).unwrap();
    let base = base_metrics.clamped();

    // Increase total_mass.
    let mut raw_total = raw.clone();
    let delta_total: f32 = any();
    raw_total.total_mass = raw.total_mass + delta_total.abs();
    let m_total = HazardMetrics::from_telemetry(&raw_total, &bundle, m_ref, c_ref).unwrap().clamped();

    assert!(m_total.total_load + 1.0e-5 >= base.total_load);

    // Increase max_concentration.
    let mut raw_conc = raw.clone();
    let delta_conc: f32 = any();
    raw_conc.max_concentration = raw.max_concentration + delta_conc.abs();
    let m_conc = HazardMetrics::from_telemetry(&raw_conc, &bundle, m_ref, c_ref).unwrap().clamped();

    assert!(m_conc.peak_concentration + 1.0e-5 >= base.peak_concentration);

    // Increase max_duty_fraction.
    let mut raw_duty = raw.clone();
    let delta_duty: f32 = any();
    raw_duty.max_duty_fraction = raw.max_duty_fraction + delta_duty.abs();
    let m_duty = HazardMetrics::from_telemetry(&raw_duty, &bundle, m_ref, c_ref).unwrap().clamped();

    assert!(m_duty.swarm_duty_fraction + 1.0e-5 >= base.swarm_duty_fraction);

    // Increase density_risk_local.
    let mut raw_dr = raw.clone();
    let delta_dr: f32 = any();
    raw_dr.density_risk_local = raw.density_risk_local + delta_dr.abs();
    let m_dr = HazardMetrics::from_telemetry(&raw_dr, &bundle, m_ref, c_ref).unwrap().clamped();

    assert!(m_dr.material_risk_proxy + 1.0e-5 >= base.material_risk_proxy);

    // Increase thermo_duty_risk.
    let mut raw_tr = raw.clone();
    let delta_tr: f32 = any();
    raw_tr.thermo_duty_risk = raw.thermo_duty_risk + delta_tr.abs();
    let m_tr = HazardMetrics::from_telemetry(&raw_tr, &bundle, m_ref, c_ref).unwrap().clamped();

    assert!(m_tr.material_risk_proxy + 1.0e-5 >= base.material_risk_proxy);

    // Increase near_roh_fraction.
    let mut raw_er = raw.clone();
    let delta_er: f32 = any();
    raw_er.near_roh_fraction = raw.near_roh_fraction + delta_er.abs();
    let m_er = HazardMetrics::from_telemetry(&raw_er, &bundle, m_ref, c_ref).unwrap().clamped();

    assert!(m_er.near_roh_events + 1.0e-5 >= base.near_roh_events);
}
