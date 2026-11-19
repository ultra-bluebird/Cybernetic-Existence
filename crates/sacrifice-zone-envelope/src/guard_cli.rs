#![forbid(unsafe_code)]
#![feature(rust_2024_preview)]

use std::fs::File;
use std::io::{self, Read};
use std::path::PathBuf;

use serde::Deserialize;

use sacrifice_zone_envelope::{
    AlnAuthorityMarker,
    HazardMetricSummary,
    HazardMetrics,
    HazardEvidenceBundle,
    RawHazardTelemetry,
    SacrificeZoneModel,
    summarize_zone_model,
};

use nanorobotics_cbf_guards::{
    BarrierGuard,
    ScalarBarrierGuard,
    BarrierVerdict,
};
use cybercore_category::{
    CorridorRiskBundle,
    CorridorControlProposal,
    FirstPassRisk,
    OptimalTransportRisk,
    BayesianRiskPosterior,
    SovereigntyInvariants,
};

#[derive(Deserialize)]
struct TelemetryInput {
    telemetry: RawHazardTelemetry,
    evidence_bundle: HazardEvidenceBundle,
    references: TelemetryReferences,
}

#[derive(Deserialize)]
struct TelemetryReferences {
    total_mass_ref: f32,
    conc_ref: f32,
}

fn read_to_string(path: &PathBuf) -> io::Result<String> {
    let mut s = String::new();
    File::open(path)?.read_to_string(&mut s)?;
    Ok(s)
}

fn main() -> io::Result<()> {
    let mut args = std::env::args().skip(1);
    let model_path = match args.next() {
        Some(p) => PathBuf::from(p),
        None => {
            eprintln!("usage: sacrifice-zone-guard-cli <zone-model.json> <telemetry.json>");
            std::process::exit(1);
        }
    };
    let telemetry_path = match args.next() {
        Some(p) => PathBuf::from(p),
        None => {
            eprintln!("usage: sacrifice-zone-guard-cli <zone-model.json> <telemetry.json>");
            std::process::exit(1);
        }
    };

    // Load SacrificeZoneModel.
    let model_json = read_to_string(&model_path)?;
    let mut sz_model: SacrificeZoneModel = serde_json::from_str(&model_json).map_err(|e| {
        eprintln!("failed to parse SacrificeZoneModel: {e}");
        io::Error::new(io::ErrorKind::InvalidData, "invalid model JSON")
    })?;

    // Load telemetry + evidence.
    let telemetry_json = read_to_string(&telemetry_path)?;
    let telemetry_input: TelemetryInput = serde_json::from_str(&telemetry_json).map_err(|e| {
        eprintln!("failed to parse telemetry input: {e}");
        io::Error::new(io::ErrorKind::InvalidData, "invalid telemetry JSON")
    })?;

    // Compute normalized HazardMetrics from telemetry.
    let metrics_opt = HazardMetrics::from_telemetry(
        &telemetry_input.telemetry,
        &telemetry_input.evidence_bundle,
        telemetry_input.references.total_mass_ref,
        telemetry_input.references.conc_ref,
    );

    let metrics = match metrics_opt {
        Some(m) => m,
        None => {
            eprintln!("evidence bundle fails tighten-only policy; refusing to proceed");
            std::process::exit(2);
        }
    };

    // Update model metrics.
    sz_model.metrics = metrics;

    // Compute summary and print.
    let summary_json = summarize_zone_model(&sz_model).map_err(|e| {
        eprintln!("failed to summarize SacrificeZoneModel: {e}");
        io::Error::new(io::ErrorKind::Other, "summary error")
    })?;
    println!("Hazard metric summary:\n{summary_json}");

    // Inject Sacrifice Zone materialrisk into corridor axes.
    let sz_risk = sz_model.metrics.materialrisk_contribution();
    let mut corridor = sz_model.corridor.clone();
    {
        let axes = corridor.axes7();
        let mut axes_new = axes;
        axes_new[6] = axes_new[6].max(sz_risk);
        // assumes unified.state.safety_axes.materialrisk exists
        corridor.unified.state.safety_axes.materialrisk = axes_new[6];
    }

    // Build a dummy risk bundle and guard parameters for a read-only check.
    let proposal = CorridorControlProposal {
        ubci: vec![0.0_f32; 7],
        unano: vec![0.0_f32; 7],
    };
    let fp = FirstPassRisk {
        roh_fp: corridor.rohproxy,
        axes_fp: corridor.axes7(),
    };
    let ot = OptimalTransportRisk {
        cost: 0.0,
        axes_ot: fp.axes_fp,
    };
    let bayes = BayesianRiskPosterior {
        psafe: 1.0,
        pbreach: 0.0,
    };
    let risk_bundle = CorridorRiskBundle {
        proposal,
        fp,
        ot,
        bayes,
    };

    let guard = ScalarBarrierGuard {
        kappa: 1.0,
        psafe_min: 0.9,
        otcostmax: 1.0,
    };

    let inv = SovereigntyInvariants {
        roh_ceiling: sz_model.envelope.roh_ceiling,
        ..Default::default()
    };

    let verdict = guard.evaluate_step(inv, corridor, risk_bundle);

    println!("BarrierGuard verdict: {verdict:?}");

    Ok(())
}
