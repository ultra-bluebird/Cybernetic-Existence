// nanorobotics/dna-origami/src/cadnano.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct CadnanoBase {
    pub strand_id: u32,
    pub index: u32,
    pub x_nm: f64,
    pub y_nm: f64,
    pub z_nm: f64,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct CadnanoDesign {
    pub name: String,
    pub bases: Vec<CadnanoBase>,
}

impl CadnanoDesign {
    pub fn from_json_str(s: &str) -> anyhow::Result<Self> {
        Ok(serde_json::from_str(s)?)
    }

    pub fn center_of_mass(&self) -> (f64, f64, f64) {
        let n = self.bases.len() as f64;
        let (sx, sy, sz) = self.bases.iter().fold((0.0, 0.0, 0.0), |acc, b| {
            (acc.0 + b.x_nm, acc.1 + b.y_nm, acc.2 + b.z_nm)
        });
        (sx / n, sy / n, sz / n)
    }
}
