use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize)]
pub struct Observation {
    pub interval_start_unix_seconds: i64,
    pub interval_end_unix_seconds: i64,
    pub h3_cell: String,
    pub sample_count: u32,
    pub air_temperature_sum_c: f64,
    pub relative_humidity_sum_percent: f64,
    pub soil_moisture_sum_fraction: f64,
    pub water_flow_sum_m3_per_s: f64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Policy {
    pub minimum_aggregate_count: u32,
    pub maximum_interval_seconds: i64,
    pub air_temperature_min_c: f64,
    pub air_temperature_max_c: f64,
    pub humidity_min_percent: f64,
    pub humidity_max_percent: f64,
    pub soil_moisture_min_fraction: f64,
    pub soil_moisture_max_fraction: f64,
    pub water_flow_min_m3_per_s: f64,
    pub water_flow_max_m3_per_s: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct SignedAggregatePayload {
    pub interval_start_unix_seconds: i64,
    pub interval_end_unix_seconds: i64,
    pub h3_cell: String,
    pub sample_count: u32,
    pub mean_air_temperature_c: f64,
    pub mean_relative_humidity_percent: f64,
    pub mean_soil_moisture_fraction: f64,
    pub mean_water_flow_m3_per_s: f64,
    pub firmware_measurement_digest: String,
    pub policy_digest: String,
    pub quality_flags: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ValidationFailure {
    pub reason: String,
}

fn finite(value: f64) -> bool {
    value.is_finite()
}

fn mean(sum: f64, count: u32) -> Result<f64, ValidationFailure> {
    if count == 0 || !finite(sum) {
        return Err(ValidationFailure {
            reason: "aggregate is empty or non-finite".to_string(),
        });
    }

    let result = sum / count as f64;

    if !finite(result) {
        return Err(ValidationFailure {
            reason: "aggregate mean is non-finite".to_string(),
        });
    }

    Ok(result)
}

fn check_range(
    name: &str,
    value: f64,
    minimum: f64,
    maximum: f64,
) -> Result<(), ValidationFailure> {
    if !finite(value) || value < minimum || value > maximum {
        return Err(ValidationFailure {
            reason: format!("{name} violates configured corridor"),
        });
    }

    Ok(())
}

pub fn validate_and_prepare(
    observation: &Observation,
    policy: &Policy,
    firmware_measurement_digest: String,
    policy_digest: String,
) -> Result<SignedAggregatePayload, ValidationFailure> {
    if observation.h3_cell.trim().is_empty() {
        return Err(ValidationFailure {
            reason: "aggregate area is required".to_string(),
        });
    }

    if observation.sample_count < policy.minimum_aggregate_count {
        return Err(ValidationFailure {
            reason: "aggregate count does not meet privacy threshold".to_string(),
        });
    }

    let interval_seconds =
        observation.interval_end_unix_seconds - observation.interval_start_unix_seconds;

    if interval_seconds <= 0 || interval_seconds > policy.maximum_interval_seconds {
        return Err(ValidationFailure {
            reason: "interval violates timing corridor".to_string(),
        });
    }

    let air_temperature = mean(observation.air_temperature_sum_c, observation.sample_count)?;
    let humidity = mean(
        observation.relative_humidity_sum_percent,
        observation.sample_count,
    )?;
    let soil_moisture = mean(
        observation.soil_moisture_sum_fraction,
        observation.sample_count,
    )?;
    let water_flow = mean(observation.water_flow_sum_m3_per_s, observation.sample_count)?;

    check_range(
        "air temperature",
        air_temperature,
        policy.air_temperature_min_c,
        policy.air_temperature_max_c,
    )?;
    check_range(
        "relative humidity",
        humidity,
        policy.humidity_min_percent,
        policy.humidity_max_percent,
    )?;
    check_range(
        "soil moisture",
        soil_moisture,
        policy.soil_moisture_min_fraction,
        policy.soil_moisture_max_fraction,
    )?;
    check_range(
        "water flow",
        water_flow,
        policy.water_flow_min_m3_per_s,
        policy.water_flow_max_m3_per_s,
    )?;

    Ok(SignedAggregatePayload {
        interval_start_unix_seconds: observation.interval_start_unix_seconds,
        interval_end_unix_seconds: observation.interval_end_unix_seconds,
        h3_cell: observation.h3_cell.clone(),
        sample_count: observation.sample_count,
        mean_air_temperature_c: air_temperature,
        mean_relative_humidity_percent: humidity,
        mean_soil_moisture_fraction: soil_moisture,
        mean_water_flow_m3_per_s: water_flow,
        firmware_measurement_digest,
        policy_digest,
        quality_flags: Vec::new(),
    })
}
