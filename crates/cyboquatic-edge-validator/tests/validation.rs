use cyboquatic_edge_validator::{
    validate_and_aggregate,
    AggregatePolicy,
    PreviousTelemetry,
    RawTelemetry,
    SensorLimits,
    ValidationError,
};

fn limits() -> SensorLimits {
    SensorLimits {
        air_temperature_min_c: -30.0,
        air_temperature_max_c: 70.0,
        relative_humidity_min_percent: 0.0,
        relative_humidity_max_percent: 100.0,
        wbgt_min_c: -10.0,
        wbgt_max_c: 65.0,
        water_flow_min_m3_per_s: 0.0,
        water_flow_max_m3_per_s: 10.0,
        max_sample_age_seconds: 180,
        max_clock_skew_seconds: 60,
        max_temperature_rate_c_per_minute: 8.0,
        max_humidity_rate_percent_per_minute: 30.0,
        max_flow_rate_change_m3_per_s_per_minute: 2.0,
    }
}

fn policy() -> AggregatePolicy {
    AggregatePolicy {
        minimum_aggregate_count: 20,
        location_precision_meters: 250,
    }
}

fn sample() -> RawTelemetry {
    RawTelemetry {
        observed_at_unix_seconds: 1_700_000_000,
        received_at_unix_seconds: 1_700_000_030,
        h3_cell: "aggregate-area".to_string(),
        sample_count: 24,
        air_temperature_c: Some(42.0),
        relative_humidity_percent: Some(18.0),
        wbgt_c: Some(31.0),
        water_flow_m3_per_s: Some(0.25),
        calibration_version: "calibration-v1".to_string(),
        firmware_version: "firmware-v1".to_string(),
    }
}

#[test]
fn accepts_valid_aggregate_environmental_telemetry() {
    let result = validate_and_aggregate(&sample(), None, &limits(), &policy());

    assert!(result.is_ok());
}

#[test]
fn rejects_undersized_aggregate_for_privacy_protection() {
    let mut value = sample();
    value.sample_count = 19;

    let result = validate_and_aggregate(&value, None, &limits(), &policy);

    assert!(matches!(
        result,
        Err(ValidationError::AggregateTooSmall)
    ));
}

#[test]
fn rejects_out_of_range_environmental_data() {
    let mut value = sample();
    value.air_temperature_c = Some(100.0);

    let result = validate_and_aggregate(&value, None, &limits(), &policy());

    assert!(matches!(
        result,
        Err(ValidationError::OutOfRange("air_temperature_c"))
    ));
}

#[test]
fn rejects_non_finite_data() {
    let mut value = sample();
    value.water_flow_m3_per_s = Some(f64::NAN);

    let result = validate_and_aggregate(&value, None, &limits(), &policy());

    assert!(matches!(
        result,
        Err(ValidationError::NonFiniteValue("water_flow_m3_per_s"))
    ));
}

#[test]
fn rejects_unphysical_rate_change() {
    let mut value = sample();
    value.observed_at_unix_seconds += 60;
    value.received_at_unix_seconds += 60;
    value.air_temperature_c = Some(60.0);

    let previous = PreviousTelemetry {
        observed_at_unix_seconds: 1_700_000_000,
        air_temperature_c: Some(42.0),
        relative_humidity_percent: Some(18.0),
        water_flow_m3_per_s: Some(0.25),
    };

    let result = validate_and_aggregate(
        &value,
        Some(&previous),
        &limits(),
        &policy(),
    );

    assert!(matches!(
        result,
        Err(ValidationError::RateExceeded("air_temperature_c"))
    ));
}
