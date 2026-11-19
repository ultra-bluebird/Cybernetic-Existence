#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum EnclosureState {
    Nominal,
    SafeDegraded,
    AuthorityOff,
    Cold,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct EnclosureLimits {
    pub max_surface_temperature_c: f64,
    pub max_component_temperature_c: f64,
    pub max_temperature_rise_rate_c_per_s: f64,
    pub max_rail_deviation_v: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct EnclosureMeasurement {
    pub ambient_temperature_c: f64,
    pub surface_temperature_c: f64,
    pub component_temperature_c: f64,
    pub temperature_rise_rate_c_per_s: f64,
    pub rail_deviation_v: f64,
    pub emc_integrity_passed: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum EnclosureDecision {
    Continue,
    SafeDegraded,
    AuthorityOff,
}

pub fn evaluate_enclosure(
    measurement: EnclosureMeasurement,
    limits: EnclosureLimits,
) -> EnclosureDecision {
    if !measurement.emc_integrity_passed
        || measurement.rail_deviation_v.abs() > limits.max_rail_deviation_v
        || measurement.component_temperature_c > limits.max_component_temperature_c
        || measurement.temperature_rise_rate_c_per_s
            > limits.max_temperature_rise_rate_c_per_s
    {
        return EnclosureDecision::AuthorityOff;
    }

    if measurement.surface_temperature_c > limits.max_surface_temperature_c {
        return EnclosureDecision::SafeDegraded;
    }

    EnclosureDecision::Continue
}
