// File: crates/biospatial-atlas/tests/kani_trajectory.rs
// edition: 2024, rust-version: 1.85

#![cfg(kani)]
#![forbid(unsafe_code)]

use biospatial_atlas::coords::{HostAabb, HostCoord, NanoSample, TissueClass};
use biospatial_atlas::BiospatialAtlas;
use kani::any;

#[kani::proof]
fn nanoswarm_cannot_leave_allowed_brain_cortex_without_detection() {
    let host_did = String::from("didaln-organic-cpuhost");
    let bostrom_address = String::from("bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7");

    let mut atlas = BiospatialAtlas::new(host_did, bostrom_address);

    let allowed = HostAabb {
        min: HostCoord {
            x_mm: 0.0,
            y_mm: 0.0,
            z_mm: 0.0,
        },
        max: HostCoord {
            x_mm: 10.0,
            y_mm: 10.0,
            z_mm: 10.0,
        },
    };
    atlas.add_allowed_region(TissueClass::BrainCortex, allowed);

    const N: usize = 4;
    let mut samples = [NanoSample {
        t_ms: 0,
        pos: HostCoord {
            x_mm: 0.0,
            y_mm: 0.0,
            z_mm: 0.0,
        },
    }; N];

    for i in 0..N {
        let x: f32 = any();
        let y: f32 = any();
        let z: f32 = any();
        samples[i] = NanoSample {
            t_ms: i as u64,
            pos: HostCoord { x_mm: x, y_mm: y, z_mm: z },
        };
    }

    let stays = atlas.trajectory_stays_in_allowed(&samples, TissueClass::BrainCortex);

    if stays {
        for s in &samples {
            assert!(allowed.contains(s.pos));
        }
    }
}
