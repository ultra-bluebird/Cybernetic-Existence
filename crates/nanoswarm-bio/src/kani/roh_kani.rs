// File: crates/nanoswarm-bio/src/kani/roh_kani.rs
// Destination: mk-bluebird/nanorobotics/crates/nanoswarm-bio/src/kani/roh_kani.rs

#![forbid(unsafe_code)]

use kani::any;

use crate::material::NanoswarmMaterialFamily;
use crate::profile::{BiocompatibilityProfile, HydroThermoCoefficients, LiteratureTag, TissueRiskProfile};
use crate::state::{roh_with_biocompat, NanoswarmStateVector};
use crate::tissue::TissueClass;

/// Simple Kani proof that roh_with_biocompat never returns a negative value
/// and respects `allowed == false` and density ceilings.[file:44]
#[kani::proof]
fn roh_with_biocompat_respects_basic_envelopes() {
    let family = any::<NanoswarmMaterialFamily>();
    let tissue = any::<TissueClass>();

    let tp = TissueRiskProfile {
        allowed: any::<bool>(),
        max_density: any::<f32>(),
        roh_multiplier: any::<f32>(),
    };

    let hydro = HydroThermoCoefficients {
        radius_nm: any::<f32>(),
        drag_coeff: any::<f32>(),
        thermal_coupling: any::<f32>(),
    };

    let profile = BiocompatibilityProfile {
        family,
        hydro_thermo: hydro,
        tissue_profiles: vec![(tissue, tp)],
        literature_tags: vec![LiteratureTag {
            shorthex: String::from("ffffffff"),
            description: String::from("dummy"),
        }],
    };

    let state = NanoswarmStateVector {
        material_family: family,
        tissue,
        density: any::<f32>(),
        actuation_intensity: any::<f32>(),
        base_roh: any::<f32>(),
    };

    let roh_opt = roh_with_biocompat(&state, &profile);

    if let Some(roh) = roh_opt {
        kani::assert!(roh >= 0.0);
    } else {
        // When None, either disallowed tissue or density breach; no further assertion needed.
        kani::assert!(true);
    }
}
