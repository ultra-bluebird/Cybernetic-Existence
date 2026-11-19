// File: crates/nanoswarm-bio/src/kani/mod.rs
// Destination: mk-bluebird/nanorobotics/crates/nanoswarm-bio/src/kani/mod.rs

#![forbid(unsafe_code)]

#[cfg(test)]
mod roh_kani;

#[cfg(test)]
pub use roh_kani::*;
