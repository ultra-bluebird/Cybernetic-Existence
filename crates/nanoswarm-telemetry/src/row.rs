use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TelemetryRow {
    pub host_did: String,
    pub bostrom_address: String,
    pub timestamp_ns: u64,
    pub p_h: f32,
    pub temperature_c: f32,
    pub flow_rate_mm_s: f32,
    pub robot_id: String,
    pub x_nm: f64,
    pub y_nm: f64,
    pub z_nm: f64,
    pub mode: String,
}

impl TelemetryRow {
    pub fn new(
        host_did: String,
        bostrom_address: String,
        timestamp_ns: u64,
        p_h: f32,
        temperature_c: f32,
        flow_rate_mm_s: f32,
        robot_id: String,
        x_nm: f64,
        y_nm: f64,
        z_nm: f64,
        mode: String,
    ) -> Self {
        TelemetryRow {
            host_did,
            bostrom_address,
            timestamp_ns,
            p_h,
            temperature_c,
            flow_rate_mm_s,
            robot_id,
            x_nm,
            y_nm,
            z_nm,
            mode,
        }
    }
}
