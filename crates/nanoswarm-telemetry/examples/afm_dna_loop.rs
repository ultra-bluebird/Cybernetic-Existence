// crates/nanoswarm-telemetry/examples/afm_dna_loop.rs

use std::time::{SystemTime, UNIX_EPOCH};

use afm_control::hardware::afm::{AfmController, AfmMode, AfmScanParams};
use afm_control::hardware::dummy_impl::{DummyAfm, DummyStage};
use afm_control::hardware::motion_stage::{AxisConfig, MotionStage, MotionTarget};

use dna_origami::cadnano::CadnanoDesign;
use dna_origami::geometry::NanoLattice;

use nanoswarm_telemetry::row::TelemetryRow;
use nanoswarm_telemetry::table::TelemetryTable;
use nanoswarm_telemetry::governance::{
    CYBERCORE_AUTHORITY_MIGRATION,
    default_cybermode,
    default_nanoswarm_compliance,
};

fn main() -> anyhow::Result<()> {
    // 1. Host and identity bindings.
    let host_did = "OrganicCPU".to_string();
    let bostrom_address = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_string();
    let robot_id = "nano-scout-1".to_string();

    // 2. Set up dummy motion stage and AFM controller.
    let mut stage = DummyStage::default();
    let axis_cfg = AxisConfig {
        id: 1,
        max_velocity_mm_s: 1.0,
        max_acc_mm_s2: 1.0,
    };
    stage.configure_axis(axis_cfg)?;

    let move_target = MotionTarget {
        axis_id: 1,
        position_mm: 0.1,
        velocity_mm_s: 0.01,
    };
    stage.move_to(move_target)?;

    let mut afm = DummyAfm::default();
    let scan_params = AfmScanParams {
        mode: AfmMode::Contact,
        size_nm: 500.0,
        resolution_px: 64,
        line_rate_hz: 1.0,
        setpoint_n: 1e-9,
    };
    afm.configure_scan(scan_params)?;
    afm.start_scan()?;

    // 3. Load a simple Cadnano-style JSON design (inline for now).
    // In practice, this would come from a .json file exported by caDNAno/scadnano.[web:66][web:76][web:86][web:70]
    let cadnano_json = r#"
    {
        "name": "afm_dna_fiducial",
        "bases": [
            { "strand_id": 1, "index": 0, "x_nm": 0.0,  "y_nm": 0.0,  "z_nm": 0.0 },
            { "strand_id": 1, "index": 1, "x_nm": 5.0,  "y_nm": 0.0,  "z_nm": 0.0 },
            { "strand_id": 1, "index": 2, "x_nm": 10.0, "y_nm": 0.0,  "z_nm": 0.0 },
            { "strand_id": 2, "index": 0, "x_nm": 0.0,  "y_nm": 5.0,  "z_nm": 0.0 },
            { "strand_id": 2, "index": 1, "x_nm": 5.0,  "y_nm": 5.0,  "z_nm": 0.0 },
            { "strand_id": 2, "index": 2, "x_nm": 10.0, "y_nm": 5.0,  "z_nm": 0.0 }
        ]
    }
    "#;

    let design = CadnanoDesign::from_json_str(cadnano_json)?;
    let lattice = NanoLattice::graphene_sheet(20.0, 20.0, 5.0);

    // 4. Build a telemetry table and stream a small number of AFM samples with structural context.
    let mut table = TelemetryTable::new();

    for _ in 0..10 {
        let now_ns = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos() as u64;

        let afm_sample = afm.next_height_sample()?;

        let row = TelemetryRow::new(
            host_did.clone(),
            bostrom_address.clone(),
            now_ns,
            robot_id.clone(),
            7.4,        // pH, example physiological.
            37.0,       // temperature in °C, example body temp.
            1.0,        // flow rate mm/s, example microfluidic.
            "survey".to_string(),
            afm_sample,
            Some(move_target.clone()),
            Some(design.clone()),
            Some(lattice.clone()),
        );

        table.append(row);
    }

    // 5. Wrap table into a JSON envelope tagged with Cybercore authority and nanoswarm compliance.
    let envelope_json = build_governed_envelope_json(
        table,
        host_did,
        bostrom_address,
        default_cybermode().to_string(),
        default_nanoswarm_compliance().to_string(),
    )?;

    println!("Nanoswarm telemetry envelope:\n{}", envelope_json);
    println!("Authority marker: {}", CYBERCORE_AUTHORITY_MIGRATION);

    Ok(())
}

/// Build a top-level governed envelope JSON string, ready for Cybercore/Data_Lake ingestion.
fn build_governed_envelope_json(
    table: TelemetryTable,
    host_did: String,
    bostrom_address: String,
    cybermode: String,
    nanoswarm_compliance: String,
) -> serde_json::Result<String> {
    #[derive(Debug, serde::Serialize)]
    struct GovernedEnvelope {
        host_did: String,
        bostrom_address: String,
        cybermode: String,
        nanoswarm_compliance: String,
        authority: String,
        telemetry: TelemetryTable,
    }

    let envelope = GovernedEnvelope {
        host_did,
        bostrom_address,
        cybermode,
        nanoswarm_compliance,
        authority: CYBERCORE_AUTHORITY_MIGRATION.to_string(),
        telemetry: table,
    };

    serde_json::to_string_pretty(&envelope)
}
