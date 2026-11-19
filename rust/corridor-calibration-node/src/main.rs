use corridor_calibration_node::{
    BiasEstimate,
    CalibrationState,
};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut node = CalibrationState::new(
        28.0,
        30.0,
        0.0,
        0.0,
        1.0,
        1.0,
        1,
    )?;

    node.update_local(28.7, 31.5, 0.09, 0.64)?;

    let neighbors = [
        BiasEstimate {
            temperature_c: 0.15,
            humidity_percent: -0.35,
            temperature_variance: 0.12,
            humidity_variance: 0.50,
            link_confidence: 0.95,
            fresh: true,
            gradient_model_version: 1,
        },
        BiasEstimate {
            temperature_c: 0.10,
            humidity_percent: -0.20,
            temperature_variance: 0.20,
            humidity_variance: 0.80,
            link_confidence: 0.85,
            fresh: true,
            gradient_model_version: 1,
        },
    ];

    let consensus = node.consensus_bias(&neighbors, 0.20)?;
    let reading = node.calibrated_reading(28.7, 31.5);

    println!(
        concat!(
            "{{",
            "\"accepted_neighbors\":{},",
            "\"ignored_neighbors\":{},",
            "\"calibrated_temperature_c\":{:.3},",
            "\"calibrated_humidity_percent\":{:.3},",
            "\"calibration_confidence\":{:.3}",
            "}}"
        ),
        consensus.accepted_neighbors,
        consensus.ignored_neighbors,
        reading.temperature_c,
        reading.humidity_percent,
        reading.calibration_confidence,
    );

    Ok(())
}
