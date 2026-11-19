// File: crates/nanoswarm-bio/src/tissue.rs
// Destination: mk-bluebird/nanorobotics/crates/nanoswarm-bio/src/tissue.rs

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

/// Organ / tissue bins used by nanoswarm medical guards and state vectors.[file:44]
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum TissueClass {
    CortexGray,
    CortexWhite,
    Hippocampus,
    Brainstem,
    PeripheralNerve,
    Myocardium,
    Pulmonary,
    Hepatic,
    Renal,
    Splenic,
    BoneMarrow,
    Muscle,
    Subcutaneous,
}
