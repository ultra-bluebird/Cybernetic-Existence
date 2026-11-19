#![forbid(unsafe_code)]

mod corridor_calibration_node;

pub use corridor_calibration_node::{
    BiasEstimate,
    CalibrationError,
    CalibrationState,
    CalibratedReading,
    ConsensusSummary,
};

#[cfg(test)]
mod tests {
    use super::{
        BiasEstimate,
        CalibrationError,
        CalibrationState,
    };

    fn state() -> CalibrationState {
        CalibrationState::new(
            25.0,
            40.0,
            0.0,
            0.0,
            1.0,
            1.0,
            1,
        )
        .expect("valid state")
    }

    #[test]
    fn local_update_produces_finite_calibrated_values() {
        let mut calibration = state();

        calibration
            .update_local(26.0, 42.0, 0.25, 1.0)
            .expect("valid measurement");

        assert!(calibration.true_temperature_c.is_finite());
        assert!(calibration.true_humidity_percent.is_finite());
        assert!(calibration.bias_temperature_c.is_finite());
        assert!(calibration.bias_humidity_percent.is_finite());
        assert!(calibration.bias_temperature_variance > 0.0);
        assert!(calibration.bias_humidity_variance > 0.0);
    }

    #[test]
    fn consensus_moves_bias_toward_reliable_neighbor_estimates() {
        let mut calibration = state();
        calibration.bias_temperature_c = 1.0;
        calibration.bias_humidity_percent = 2.0;

        let neighbors = [
            BiasEstimate {
                temperature_c: 0.0,
                humidity_percent: 0.0,
                temperature_variance: 0.1,
                humidity_variance: 0.1,
                link_confidence: 1.0,
                fresh: true,
                gradient_model_version: 1,
            },
            BiasEstimate {
                temperature_c: 0.1,
                humidity_percent: 0.2,
                temperature_variance: 0.2,
                humidity_variance: 0.2,
                link_confidence: 0.8,
                fresh: true,
                gradient_model_version: 1,
            },
        ];

        let summary = calibration
            .consensus_bias(&neighbors, 0.5)
            .expect("valid consensus");

        assert_eq!(summary.accepted_neighbors, 2);
        assert!(calibration.bias_temperature_c < 1.0);
        assert!(calibration.bias_humidity_percent < 2.0);
    }

    #[test]
    fn mismatched_gradient_version_is_ignored() {
        let mut calibration = state();
        calibration.bias_temperature_c = 0.5;

        let neighbors = [BiasEstimate {
            temperature_c: -10.0,
            humidity_percent: 90.0,
            temperature_variance: 0.1,
            humidity_variance: 0.1,
            link_confidence: 1.0,
            fresh: true,
            gradient_model_version: 2,
        }];

        let summary = calibration
            .consensus_bias(&neighbors, 0.5)
            .expect("consensus processing succeeds");

        assert_eq!(summary.accepted_neighbors, 0);
        assert_eq!(calibration.bias_temperature_c, 0.5);
    }

    #[test]
    fn invalid_measurement_is_rejected() {
        let mut calibration = state();

        let result = calibration.update_local(24.0, 50.0, 0.0, 1.0);

        assert_eq!(result, Err(CalibrationError::InvalidLocalMeasurement));
    }

    #[test]
    fn calibrated_values_remove_estimated_bias() {
        let mut calibration = state();
        calibration.bias_temperature_c = 0.8;
        calibration.bias_humidity_percent = -2.0;

        let calibrated_temperature = calibration.calibrated_temperature_c(30.0);
        let calibrated_humidity = calibration.calibrated_humidity_percent(45.0);

        assert!((calibrated_temperature - 29.2).abs() < 0.0001);
        assert!((calibrated_humidity - 47.0).abs() < 0.0001);
    }
}
