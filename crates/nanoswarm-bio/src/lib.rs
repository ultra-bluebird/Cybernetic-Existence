// File: crates/nanoswarm-bio/src/lib.rs
// Destination: mk-bluebird/nanorobotics/crates/nanoswarm-bio/src/lib.rs

#![forbid(unsafe_code)]

pub mod material;
pub mod tissue;
pub mod profile;
pub mod state;

pub use material::NanoswarmMaterialFamily;
pub use tissue::TissueClass;
pub use profile::{BiocompatibilityProfile, HydroThermoCoefficients, LiteratureTag, TissueRiskProfile};
pub use state::{NanoswarmStateVector, roh_with_biocompat};
