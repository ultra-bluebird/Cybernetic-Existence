use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize)]
pub struct SensorLimits {
    pub air_temperature_min_c: f64,
    pub air_temperature_max_c: f64,
    pub relative_humidity_min_percent: f64,
    pub relative_humidity_max_percent: f64,
    pub wbgt_min_c: f64,
    pub wbgt_max_c: f64,
    pub water_flow_min_m3_per_s: f64,
    pub water_flow_max_m3_per_s: f64,
    pub max_sample_age_seconds: i64,
    pub max_clock_skew_seconds: i64,
    pub max_temperature_rate_c_per_minute: f64,
    pub max_humidity_rate_percent_per_minute: f64,
    pub max_flow_rate_change_m3_per_s_per_minute: f64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AggregatePolicy {
    pub minimum_aggregate_count: u32,
    pub location_precision_meters: u32,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RawTelemetry {
    pub observed_at_unix_seconds: i64,
    pub received_at_unix_seconds: i64,
    pub h3_cell: String,
    pub sample_count: u32,
    pub air_temperature_c: Option<f64>,
    pub relative_humidity_percent: Option<f64>,
    pub wbgt_c: Option<f64>,
    pub water_flow_m3_per_s: Option<f64>,
    pub calibration_version: String,
    pub firmware_version: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct AggregateTelemetry {
    pub interval_start_unix_seconds: i64,
    pub interval_end_unix_seconds: i64,
    pub h3_cell: String,
    pub sample_count: u32,
    pub mean_air_temperature_c: Option<f64>,
    pub mean_relative_humidity_percent: Option<f64>,
    pub mean_wbgt_c: Option<f64>,
    pub mean_water_flow_m3_per_s: Option<f64>,
    pub quality_flags: Vec<String>,
    pub calibration_version: String,
    pub firmware_version: String,
}

#[derive(Debug, Clone)]
pub struct PreviousTelemetry {
    pub observed_at_unix_seconds: i64,
    pub air_temperature_c: Option<f64>,
    pub relative_humidity_percent: Option<f64>,
    pub water_flow_m3_per_s: Option<f64>,
}

#[derive(Debug, Clone)]
pub enum ValidationError {
    MissingH3Cell,
    NonFiniteValue(&'static str),
    OutOfRange(&'static str),
    StaleSample,
    ClockSkew,
    AggregateTooSmall,
    RateExceeded(&'static str),
}

fn finite(value: f64) -> bool {
    value.is_finite()
}

fn in_range(value: f64, minimum: f64, maximum: f64) -> bool {
    finite(value) && value >= minimum && value <= maximum
}

fn validate_optional_range(
    value: Option<f64>,
    name: &'static str,
    minimum: f64,
    maximum: f64,
) -> Result<(), ValidationError> {
    if let Some(measurement) = value {
        if !finite(measurement) {
            return Err(ValidationError::NonFiniteValue(name));
        }

        if !in_range(measurement, minimum, maximum) {
            return Err(ValidationError::OutOfRange(name));
        }
    }

    Ok(())
}

fn validate_rate(
    current: Option<f64>,
    previous: Option<f64>,
    elapsed_seconds: i64,
    maximum_per_minute: f64,
    name: &'static str,
) -> Result<(), ValidationError> {
    if elapsed_seconds <= 0 {
        return Ok(());
    }

    if let (Some(current_value), Some(previous_value)) = (current, previous) {
        let elapsed_minutes = elapsed_seconds as f64 / 60.0;
        let rate = (current_value - previous_value).abs() / elapsed_minutes;

        if !finite(rate) || rate > maximum_per_minute {
            return Err(ValidationError::RateExceeded(name));
        }
    }

    Ok(())
}

pub fn validate_and_aggregate(
    current: &RawTelemetry,
    previous: Option<&PreviousTelemetry>,
    limits: &SensorLimits,
    policy: &AggregatePolicy,
) -> Result<AggregateTelemetry, ValidationError> {
    if current.h3_cell.trim().is_empty() {
        return Err(ValidationError::MissingH3Cell);
    }

    if current.sample_count < policy.minimum_aggregate_count {
        return Err(ValidationError::AggregateTooSmall);
    }

    let age_seconds = current.received_at_unix_seconds - current.observed_at_unix_seconds;

    if age_seconds > limits.max_sample_age_seconds {
        return Err(ValidationError::StaleSample);
    }

    if age_seconds.abs() > limits.max_clock_skew_seconds {
        return Err(ValidationError::ClockSkew);
    }

    validate_optional_range(
        current.air_temperature_c,
        "air_temperature_c",
        limits.air_temperature_min_c,
        limits.air_temperature_max_c,
    )?;

    validate_optional_range(
        current.relative_humidity_percent,
        "relative_humidity_percent",
        limits.relative_humidity_min_percent,
        limits.relative_humidity_max_percent,
    )?;

    validate_optional_range(
        current.wbgt_c,
        "wbgt_c",
        limits.wbgt_min_c,
        limits.wbgt_max_c,
    )?;

    validate_optional_range(
        current.water_flow_m3_per_s,
        "water_flow_m3_per_s",
        limits.water_flow_min_m3_per_s,
        limits.water_flow_max_m3_per_s,
    )?;

    if let Some(previous_value) = previous {
        let elapsed_seconds =
            current.observed_at_unix_seconds - previous_value.observed_at_unix_seconds;

        validate_rate(
            current.air_temperature_c,
            previous_value.air_temperature_c,
            elapsed_seconds,
            limits.max_temperature_rate_c_per_minute,
            "air_temperature_c",
        )?;

        validate_rate(
            current.relative_humidity_percent,
            previous_value.relative_humidity_percent,
            elapsed_seconds,
            limits.max_humidity_rate_percent_per_minute,
            "relative_humidity_percent",
        )?;

        validate_rate(
            current.water_flow_m3_per_s,
            previous_value.water_flow_m3_per_s,
            elapsed_seconds,
            limits.max_flow_rate_change_m3_per_s_per_minute,
            "water_flow_m3_per_s",
        )?;
    }

    Ok(AggregateTelemetry {
        interval_start_unix_seconds: current.observed_at_unix_seconds,
        interval_end_unix_seconds: current.observed_at_unix_seconds,
        h3_cell: current.h3_cell.clone(),
        sample_count: current.sample_count,
        mean_air_temperature_c: current.air_temperature_c,
        mean_relative_humidity_percent: current.relative_humidity_percent,
        mean_wbgt_c: current.wbgt_c,
        mean_water_flow_m3_per_s: current.water_flow_m3_per_s,
        quality_flags: Vec::new(),
        calibration_version: current.calibration_version.clone(),
        firmware_version: current.firmware_version.clone(),
    })
}
