// Filename: mk-bluebird/nanorobotics/crates/nanorobotics-guards/src/hierarchical_composer.rs
// Destination: github.com/mk-bluebird/nanorobotics
#![forbid(unsafe_code)]

use crate::{
    corridor_traits::GuardState,
    guards_impl::{DensityGuard, ImmuneGuard, ThermalGuard, WssGuard},
    verdict::Verdict,
};

pub struct HierarchicalGuardComposer {
    pub wss_guard: WssGuard,
    pub density_guard: DensityGuard,
    pub thermal_guard: ThermalGuard,
    pub immune_guard: ImmuneGuard,
}

impl HierarchicalGuardComposer {
    pub fn evaluate(&self, state: &GuardState) -> Verdict {
        // Lexical priority: WSS -> Immune -> Thermal -> Density.
        let wss_v = self.wss_guard.evaluate(state);
        if wss_v == Verdict::Deny {
            return Verdict::Deny;
        }

        let immune_v = self.immune_guard.evaluate(state);
        if immune_v == Verdict::Deny {
            return Verdict::Deny;
        }

        let thermal_v = self.thermal_guard.evaluate(state);
        if thermal_v == Verdict::Deny {
            return Verdict::Deny;
        }

        let density_v = self.density_guard.evaluate(state);
        wss_v
            .combine(immune_v)
            .combine(thermal_v)
            .combine(density_v)
    }
}
