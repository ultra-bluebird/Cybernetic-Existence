// Filename: mk-bluebird/nanorobotics/crates/biocompatibility-latent-core/src/lib.rs
// Destination: github.com/mk-bluebird/nanorobotics
#![forbid(unsafe_code)]

#[derive(Clone, Copy, Debug)]
pub struct BiocompatibilityIndex(pub f32);

#[derive(Clone, Copy, Debug)]
pub enum BiocompatibilityVerdict {
    Safe,
    Caution,
    Danger,
}

impl BiocompatibilityIndex {
    pub fn verdict(self) -> BiocompatibilityVerdict {
        let x = self.0;
        if x <= 0.3 {
            BiocompatibilityVerdict::Safe
        } else if x <= 0.6 {
            BiocompatibilityVerdict::Caution
        } else {
            BiocompatibilityVerdict::Danger
        }
    }
}
