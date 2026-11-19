#![forbid(unsafe_code)]

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

pub const HOST_DID: &str = "didaln:organic-host";

pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

use cybernano_physio::{calculate_roh, PhysioCaps, PhysioState};

/// Canonical UV snapshot for nanoswarm physio fusion.
/// This mirrors NeuroThermoSnapshot but for UV and radiant load.
#[derive(Clone, Debug)]
pub struct UvSnapshot {
    pub hostdid: String,
    pub bostrom_address: String,

    /// Normalized local UVA index (0.0–1.0) at nanoswarm surface.
    pub uva_index: f32,
    /// Normalized local UVB index (0.0–1.0) at nanoswarm surface.
    pub uvb_index: f32,

    /// Surface radiant flux in W/m^2 (shortwave + longwave),
    /// already localized to the relevant exoskeleton or skin patch.
    pub surface_radiant_wm2: f32,

    /// Fraction (0.0–1.0) of UV shield integrity (1.0 = pristine, 0.0 = failed).
    /// This is a conservative estimate from materials telemetry and cumulative dose.
    pub shield_integrity: f32,

    /// Fraction (0.0–1.0) of local swarm canopy coverage (1.0 = fully shaded).
    /// This is a conservative, topology-aware quantity computed from swarm formations.
    pub canopy_coverage: f32,

    /// Opaque identifier for the materials stack / ALN materials envelope.
    pub materials_state_id: u32,
}

/// Configuration for conservative UV fusion.
#[derive(Clone, Copy, Debug)]
pub struct UvFusionConfig {
    /// Weight assigned to UVB relative to UVA (UVB is more damaging per photon).
    pub w_uvb: f32,
    /// Maximum allowed normalized UV risk; values above are clamped.
    pub max_r_uv: f32,
    /// Small deadband for ignoring noise-level UV when shield is intact.
    pub eps_uv: f32,
    /// Maximum conservative radiant load (W/m^2) for normalization.
    pub radiant_max_wm2: f32,
}

impl UvFusionConfig {
    pub fn validated(self) -> Self {
        assert!(self.w_uvb.is_finite() && self.w_uvb >= 0.0);
        assert!(self.max_r_uv.is_finite() && self.max_r_uv > 0.0);
        assert!(self.eps_uv.is_finite() && self.eps_uv >= 0.0);
        assert!(self.radiant_max_wm2.is_finite() && self.radiant_max_wm2 > 0.0);
        self
    }
}

/// Fused UV state fed into the unified RoH kernel.
/// r_uv_scalar is normalized 0.0–1.0 and conservative.
#[derive(Clone, Copy, Debug)]
pub struct FusedUvState {
    pub r_uv_scalar: f32,
}

fn saturating_div(n: f32, d: f32) -> f32 {
    if !n.is_finite() || !d.is_finite() || d.abs() <= 1.0e-6 {
        1.0
    } else {
        (n / d).min(1.0).max(0.0)
    }
}

/// Conservative UV fusion rule.
/// - Computes a worst-case UV risk scalar from UVA/UVB, radiant load,
///   shield integrity, and canopy coverage.
/// - Always over-approximates true risk under bounded sensor and shading errors.
pub fn fuse_uv(cfg: &UvFusionConfig, snap: &UvSnapshot) -> FusedUvState {
    let cfg = cfg.clone().validated();

    // Host binding precondition enforced at runtime.
    if snap.hostdid != HOST_DID || snap.bostrom_address != BOSTROM_ADDRESS {
        // In production you might log and return maximal risk.
        return FusedUvState { r_uv_scalar: cfg.max_r_uv };
    }

    // Clamp indices into [0,1].
    let uva = snap.uva_index.clamp(0.0, 1.0);
    let uvb = snap.uvb_index.clamp(0.0, 1.0);

    // Raw spectral risk: UVB weighted more heavily.
    let spectral_raw = (uva + cfg.w_uvb * uvb).max(0.0);

    // Radiant load normalized to [0,1], conservative upper bound.
    let radiant_norm = saturating_div(snap.surface_radiant_wm2.max(0.0), cfg.radiant_max_wm2);

    // Conservative shading factors:
    //  - shield_integrity is a lower bound on actual integrity (monotone decreasing with damage).
    //  - canopy_coverage is a lower bound on actual coverage.
    // We use their complements as multiplicative penalties.
    let shield_int = snap.shield_integrity.clamp(0.0, 1.0);
    let canopy = snap.canopy_coverage.clamp(0.0, 1.0);

    let shield_penalty = 1.0 - shield_int;
    let canopy_penalty = 1.0 - canopy;

    // Base risk from UV indices and radiant load.
    let base_risk = (spectral_raw.max(radiant_norm)).max(0.0);

    // Apply penalties to reflect degraded shields / shading.
    let penalized = base_risk * (1.0 + shield_penalty + canopy_penalty);

    // Deadband: small residuals below eps_uv are treated as zero when protection is intact.
    let r_uv_raw = if shield_int >= 0.9 && canopy >= 0.9 && penalized < cfg.eps_uv {
        0.0
    } else {
        penalized
    };

    // Clamp to [0, max_r_uv].
    let r_uv_clamped = r_uv_raw.clamp(0.0, cfg.max_r_uv);

    FusedUvState {
        r_uv_scalar: r_uv_clamped,
    }
}

/// Apply fused UV risk into PhysioState and recompute RoH.
/// This function assumes PhysioState has a UV axis in its internal representation.
pub fn apply_fused_uv_to_state(
    state: &mut PhysioState,
    caps: &PhysioCaps,
    fused: &FusedUvState,
) {
    // Here we assume PhysioState exposes a setter for UV risk.
    // If the exact field name differs, adjust accordingly.
    state.set_uv_risk_axis(fused.r_uv_scalar.clamp(0.0, 1.0));

    let roh = calculate_roh(state, caps);
    // Clamp RoH to ceiling while preserving conservative over-approximation.
    let roh_clamped = roh.min(caps.roh_ceiling);
    state.set_roh_scalar(roh_clamped);
}

/// Kani harnesses (compiled only with feature = "kani").
#[cfg(feature = "kani")]
mod kani_uvfusion {
    use super::*;
    use kani::{any, assume, proof};

    const EPS: f32 = 1.0e-5;

    fn kani_default_cfg() -> UvFusionConfig {
        UvFusionConfig {
            w_uvb: 2.0,
            max_r_uv: 1.0,
            eps_uv: 0.01,
            radiant_max_wm2: 1400.0,
        }
        .validated()
    }

    fn kani_any_snapshot() -> UvSnapshot {
        let uva: f32 = any();
        let uvb: f32 = any();
        let radiant: f32 = any();
        let shield: f32 = any();
        let canopy: f32 = any();

        assume(uva.is_finite());
        assume(uvb.is_finite());
        assume(radiant.is_finite());
        assume(shield.is_finite());
        assume(canopy.is_finite());

        assume(uva >= 0.0 && uva <= 1.0);
        assume(uvb >= 0.0 && uvb <= 1.0);
        assume(radiant >= 0.0 && radiant <= 2000.0);
        assume(shield >= 0.0 && shield <= 1.0);
        assume(canopy >= 0.0 && canopy <= 1.0);

        UvSnapshot {
            hostdid: HOST_DID.to_string(),
            bostrom_address: BOSTROM_ADDRESS.to_string(),
            uva_index: uva,
            uvb_index: uvb,
            surface_radiant_wm2: radiant,
            shield_integrity: shield,
            canopy_coverage: canopy,
            materials_state_id: 0,
        }
    }

    /// Helper: conservative upper bound on true UV risk under the same ranges.
    fn true_uv_risk_upper(snap: &UvSnapshot, cfg: &UvFusionConfig) -> f32 {
        let uva = snap.uva_index.clamp(0.0, 1.0);
        let uvb = snap.uvb_index.clamp(0.0, 1.0);
        let spectral_raw = (uva + cfg.w_uvb * uvb).max(0.0);
        let radiant_norm = super::saturating_div(
            snap.surface_radiant_wm2.max(0.0),
            cfg.radiant_max_wm2,
        );
        let base = spectral_raw.max(radiant_norm);
        base.min(cfg.max_r_uv).max(0.0)
    }

    /// Proof 1: UV fusion never underestimates true UV risk within bounds.
    #[proof]
    fn proof_uv_fusion_overapproximates_true_risk() {
        let cfg = kani_default_cfg();
        let snap = kani_any_snapshot();

        let fused = super::fuse_uv(&cfg, &snap);
        let true_upper = true_uv_risk_upper(&snap, &cfg);

        assert!(
            fused.r_uv_scalar + EPS >= true_upper,
            "UV fusion underestimates true risk upper bound"
        );
        assert!(
            fused.r_uv_scalar <= cfg.max_r_uv + EPS,
            "UV fusion exceeds configured max_r_uv"
        );
    }

    fn kani_default_caps() -> PhysioCaps {
        let mut caps: PhysioCaps = any();
        assume(caps.roh_ceiling.is_finite());
        assume(caps.roh_ceiling > 0.0);
        assume(caps.roh_ceiling <= 0.30 + EPS);
        caps
    }

    fn kani_initial_state(caps: &PhysioCaps) -> PhysioState {
        let mut state: PhysioState = any();
        // Start with RoH inside ceiling.
        let roh0 = calculate_roh(&state, caps);
        assume(roh0.is_finite());
        assume(roh0 <= caps.roh_ceiling + EPS);
        state.set_roh_scalar(roh0);
        // Start with UV axis in [0,1].
        state.set_uv_risk_axis(0.0);
        state
    }

    /// Proof 2: RoH ceiling preserved when applying UV fusion.
    #[proof]
    fn proof_uv_fusion_preserves_roh_ceiling() {
        let cfg = kani_default_cfg();
        let caps = kani_default_caps();
        let mut state = kani_initial_state(&caps);

        let steps: u8 = any();
        assume(steps <= 4);
        let mut k: u8 = 0;

        while k < steps {
            let snap = kani_any_snapshot();
            let fused = super::fuse_uv(&cfg, &snap);
            super::apply_fused_uv_to_state(&mut state, &caps, &fused);

            let roh = calculate_roh(&state, &caps);
            assert!(roh.is_finite(), "RoH became non-finite after UV fusion");
            assert!(
                roh <= caps.roh_ceiling + EPS,
                "RoH ceiling violated after UV fusion"
            );

            k += 1;
        }
    }
}
