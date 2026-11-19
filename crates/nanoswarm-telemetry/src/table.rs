use serde::{Deserialize, Serialize};

use crate::row::TelemetryRow;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TelemetryTable {
    pub rows: Vec<TelemetryRow>,
}

impl TelemetryTable {
    pub fn new() -> Self {
        TelemetryTable { rows: Vec::new() }
    }

    pub fn append(&mut self, row: TelemetryRow) {
        self.rows.push(row);
    }

    pub fn filter_by_robot(&self, robot_id: &str) -> Self {
        let rows = self
            .rows
            .iter()
            .cloned()
            .filter(|r| r.robot_id == robot_id)
            .collect();
        TelemetryTable { rows }
    }

    pub fn to_json(&self) -> serde_json::Result<String> {
        serde_json::to_string(self)
    }

    pub fn from_json(s: &str) -> serde_json::Result<Self> {
        serde_json::from_str(s)
    }
}
