#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]
#![feature(rust_2024_preview)]

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

pub const HOST_DID: &str = "OrganicCPU";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

pub mod model;
pub mod metrics;

pub use crate::model::{
    HazardClass,
    SacrificeZoneEnvelope,
    SacrificeZoneId,
    SacrificeZoneModel,
};
pub use crate::metrics::{
    HazardMetrics,
    HazardMetricKind,
    HazardMetricSummary,
};

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Error type for Sacrifice Zone envelope operations.
#[derive(Debug, Error)]
pub enum SacrificeZoneError {
    #[error("invalid identity binding: hostdid={hostdid}, bostrom_address={bostrom_address}")]
    InvalidIdentity {
        hostdid: String,
        bostrom_address: String,
    },

    #[error("invalid corridor polytope: expected {expected} facets, found {found}")]
    InvalidPolytope { expected: usize, found: usize },

    #[error("inconsistent hazard metrics: {message}")]
    InvalidMetrics { message: String },
}

/// Lightweight ALN authority marker for this crate.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct AlnAuthorityMarker {
    pub clause: String,
    pub hostdid: String,
    pub bostrom_address: String,
}

impl AlnAuthorityMarker {
    pub fn canonical() -> Self {
        Self {
            clause: ALN_MIGRATION_CYBERCORE_AUTHORITY_V1.to_string(),
            hostdid: HOST_DID.to_string(),
            bostrom_address: BOSTROM_ADDRESS.to_string(),
        }
    }

    pub fn is_canonical(&self) -> bool {
        self.clause == ALN_MIGRATION_CYBERCORE_AUTHORITY_V1
            && self.hostdid == HOST_DID
            && self.bostrom_address == BOSTROM_ADDRESS
    }
}

/// High-level helper to validate a Sacrifice Zone model and return a concise JSON summary.
pub fn summarize_zone_model(model: &SacrificeZoneModel) -> Result<String, SacrificeZoneError> {
    if !model.authority.is_canonical() {
        return Err(SacrificeZoneError::InvalidIdentity {
            hostdid: model.authority.hostdid.clone(),
            bostrom_address: model.authority.bostrom_address.clone(),
        });
    }

    let summary = HazardMetricSummary::from_metrics(&model.metrics);
    serde_json::to_string_pretty(&summary)
        .map_err(|e| SacrificeZoneError::InvalidMetrics { message: e.to_string() })
}
