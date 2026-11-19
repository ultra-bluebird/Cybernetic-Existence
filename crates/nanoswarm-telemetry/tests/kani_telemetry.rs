// crates/nanoswarm-telemetry/tests/kani_telemetry.rs

use nanoswarm_telemetry::row::TelemetryRow;
use nanoswarm_telemetry::table::TelemetryTable;
use afm_control::hardware::afm::AfmHeightSample;
use dna_origami::cadnano::{CadnanoBase, CadnanoDesign};

#[kani::proof]
fn telemetry_table_roundtrip_json_is_lossless() {
    let afm_sample = AfmHeightSample {
        x_nm: 1.0,
        y_nm: 2.0,
        z_nm: 3.0,
        timestamp_ns: 123,
    };

    let base = CadnanoBase {
        strand_id: 1,
        index: 0,
        x_nm: 0.0,
        y_nm: 0.0,
        z_nm: 0.0,
    };

    let design = CadnanoDesign {
        name: "test".to_string(),
        bases: vec![base],
    };

    let row = TelemetryRow::new(
        "OrganicCPU".to_string(),
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_string(),
        123,
        "robot-1".to_string(),
        7.4,
        37.0,
        1.0,
        "survey".to_string(),
        Some(afm_sample),
        None,
        Some(design),
        None,
    );

    let mut table = TelemetryTable::new();
    table.append(row);

    let json = table.to_json().unwrap();
    let decoded = TelemetryTable::from_json(&json).unwrap();

    assert_eq!(decoded.rows.len(), 1);
    assert_eq!(decoded.rows[0].robot_id, "robot-1");
    assert_eq!(decoded.rows[0].host_did, "OrganicCPU");
}
