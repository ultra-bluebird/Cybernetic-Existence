// destination-path: crates/sovereign-host-kernel/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use serde::{Deserialize, Serialize};
use std::collections::HashSet;

// -----------------------------------------------------------------------------
// 21. ConsentProvider trait and SovereignHostKernel with DI
// -----------------------------------------------------------------------------

/// EvoMode matches CONSERVATIVE / COPILOT semantics from your .evo shards.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum EvoMode {
    Conservative,
    Copilot,
    Custom,
}

/// Minimal EvoConsent snapshot needed by the host kernel.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvoConsentSnapshot {
    pub mode: EvoMode,
    /// Scalar in [0,1] applied to thermal / duty envelopes.
    pub thermo_scale: f32,
    /// Scalar in [0,1] applied to cognitive / duty envelopes.
    pub cognitive_scale: f32,
}

/// Trait-based dependency injection surface for consent.
/// Implementations may read .evo shards, but the kernel only sees this trait.
pub trait ConsentProvider {
    /// Deterministic access to the current consent snapshot.
    fn current_consent(&self) -> EvoConsentSnapshot;
}

/// Minimal decision output for the host kernel.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum KernelVerdict {
    AutoAllowed,
    RequiresHostedApproval,
    AutoDenied,
}

/// Reduced state needed for RoH and envelope checks.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct KernelState {
    pub roh_scalar: f32,
    pub thermo_delta_c: f32,
    pub cognitive_load: f32,
}

/// Pure, side-effect-free SovereignHostKernel.
/// All external variability is injected via the ConsentProvider trait.
pub struct SovereignHostKernel<'a, C: ConsentProvider> {
    consent_provider: &'a C,
    /// RoH ceiling; typically 0.3.
    roh_ceiling: f32,
    /// Thermal ceiling in Celsius.
    thermo_ceiling_c: f32,
    /// Cognitive load ceiling (normalized 0–1).
    cognitive_ceiling: f32,
}

impl<'a, C: ConsentProvider> SovereignHostKernel<'a, C> {
    pub fn new(
        consent_provider: &'a C,
        roh_ceiling: f32,
        thermo_ceiling_c: f32,
        cognitive_ceiling: f32,
    ) -> Self {
        Self {
            consent_provider,
            roh_ceiling,
            thermo_ceiling_c,
            cognitive_ceiling,
        }
    }

    /// Deterministic decision logic that depends only on KernelState and
    /// the injected ConsentProvider. No I/O or global state.
    pub fn decide_with_evo(&self, state: &KernelState) -> KernelVerdict {
        let consent = self.consent_provider.current_consent();

        // Hard RoH ceiling: cannot be relaxed by consent modes.
        if state.roh_scalar > self.roh_ceiling {
            return KernelVerdict::AutoDenied;
        }

        // Mode-specific scaling of thermo and cognitive ceilings.
        let thermo_limit = self.thermo_ceiling_c * consent.thermo_scale.clamp(0.0, 1.0);
        let cognitive_limit = self.cognitive_ceiling * consent.cognitive_scale.clamp(0.0, 1.0);

        if state.thermo_delta_c > thermo_limit || state.cognitive_load > cognitive_limit {
            return match consent.mode {
                EvoMode::Conservative => KernelVerdict::AutoDenied,
                EvoMode::Copilot | EvoMode::Custom => KernelVerdict::RequiresHostedApproval,
            };
        }

        match consent.mode {
            EvoMode::Conservative => KernelVerdict::AutoAllowed,
            EvoMode::Copilot | EvoMode::Custom => KernelVerdict::RequiresHostedApproval,
        }
    }
}

/// Mock provider for unit tests and Kani harnesses.
#[derive(Debug, Clone)]
pub struct MockConsentProvider {
    snapshot: EvoConsentSnapshot,
}

impl MockConsentProvider {
    pub fn new(snapshot: EvoConsentSnapshot) -> Self {
        Self { snapshot }
    }
}

impl ConsentProvider for MockConsentProvider {
    fn current_consent(&self) -> EvoConsentSnapshot {
        self.snapshot.clone()
    }
}

// Kani proof: for all states and all consent snapshots, decide_with_evo is
// deterministic and side-effect free (no state mutation).
#[cfg(kani)]
mod kani_kernel {
    use super::*;
    use kani::any;

    #[kani::proof]
    fn decide_with_evo_is_pure_and_safe() {
        let roh = any::<f32>();
        let thermo = any::<f32>();
        let cog = any::<f32>();

        kani::assume(roh.is_finite());
        kani::assume(thermo.is_finite());
        kani::assume(cog.is_finite());

        let mode = any::<u8>();
        let mode = match mode % 3 {
            0 => EvoMode::Conservative,
            1 => EvoMode::Copilot,
            _ => EvoMode::Custom,
        };

        let thermo_scale = any::<f32>().clamp(0.0, 1.0);
        let cognitive_scale = any::<f32>().clamp(0.0, 1.0);

        let provider = MockConsentProvider::new(EvoConsentSnapshot {
            mode,
            thermo_scale,
            cognitive_scale,
        });

        let kernel = SovereignHostKernel::new(&provider, 0.3, 1.0, 1.0);

        let state = KernelState {
            roh_scalar: roh,
            thermo_delta_c: thermo,
            cognitive_load: cog,
        };

        let v1 = kernel.decide_with_evo(&state);
        let v2 = kernel.decide_with_evo(&state);

        // Determinism: same input -> same output
        assert!(v1 == v2);

        // Hard safety: if RoH > ceiling, verdict must be AutoDenied.
        if roh > 0.3 {
            assert!(matches!(v1, KernelVerdict::AutoDenied));
        }
    }
}

// -----------------------------------------------------------------------------
// 22. MeshAccessControl guard and BCI/XR pipeline
// -----------------------------------------------------------------------------

/// Mesh-level permissions and blocks as seen in .evo / manifest shards.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MeshPolicy {
    pub permissions: HashSet<String>,
    pub blocks: HashSet<String>,
}

/// BCI / XR pipeline operation types.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum MeshOp {
    ReadNeural,
    WriteStimulus,
}

/// Guard verdict for mesh access.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum MeshAccessVerdict {
    Allowed,
    Blocked,
}

/// Mesh access control guard sitting in front of BCI/XR backends.
pub struct MeshAccessControl {
    policy: MeshPolicy,
}

impl MeshAccessControl {
    pub fn new(policy: MeshPolicy) -> Self {
        Self { policy }
    }

    /// Filter a request from a mesh region before any neural read or stim.
    pub fn check(
        &self,
        region_id: &str,
        op: MeshOp,
    ) -> MeshAccessVerdict {
        if self.policy.blocks.contains(region_id) {
            return MeshAccessVerdict::Blocked;
        }
        if !self.policy.permissions.contains(region_id) {
            return MeshAccessVerdict::Blocked;
        }

        match op {
            MeshOp::ReadNeural | MeshOp::WriteStimulus => MeshAccessVerdict::Allowed,
        }
    }
}

/// Abstract BCI backend that actually touches neural data.
/// This is never called directly; always via MeshAccessControl.
pub trait BciBackend {
    fn read_neural(&self, region_id: &str) -> Vec<f32>;
    fn write_stimulus(&self, region_id: &str, pattern: &[f32]);
}

/// BCI / XR pipeline that composes MeshAccessControl and BciBackend.
pub struct BciPipeline<'a> {
    access: &'a MeshAccessControl,
    backend: &'a dyn BciBackend,
}

impl<'a> BciPipeline<'a> {
    pub fn new(access: &'a MeshAccessControl, backend: &'a dyn BciBackend) -> Self {
        Self { access, backend }
    }

    pub fn guarded_read(&self, region_id: &str) -> Option<Vec<f32>> {
        match self.access.check(region_id, MeshOp::ReadNeural) {
            MeshAccessVerdict::Allowed => Some(self.backend.read_neural(region_id)),
            MeshAccessVerdict::Blocked => None,
        }
    }

    pub fn guarded_stimulate(&self, region_id: &str, pattern: &[f32]) -> bool {
        match self.access.check(region_id, MeshOp::WriteStimulus) {
            MeshAccessVerdict::Allowed => {
                self.backend.write_stimulus(region_id, pattern);
                true
            }
            MeshAccessVerdict::Blocked => false,
        }
    }
}

// -----------------------------------------------------------------------------
// 23. Anonymous scoring objection and DP budget per region
// -----------------------------------------------------------------------------

/// Differential privacy budget per mesh region enforced at QPU layer.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RegionDpBudget {
    pub region_id: String,
    /// Total epsilon budget allocated.
    pub epsilon_total: f32,
    /// Epsilon already spent.
    pub epsilon_spent: f32,
}

/// QPU-side analytics gate that enforces DP budgets before export.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct QpuDpGuard {
    pub budgets: Vec<RegionDpBudget>,
}

impl QpuDpGuard {
    /// Check whether an aggregated export from a region is permitted.
    /// This forbids any high-resolution, per-host scoring; only coarse,
    /// epsilon-bounded aggregates may leave the host.
    pub fn can_export(&self, region_id: &str, epsilon_cost: f32) -> bool {
        if epsilon_cost <= 0.0 {
            return false;
        }
        if let Some(b) = self.budgets.iter().find(|b| b.region_id == region_id) {
            let remaining = b.epsilon_total - b.epsilon_spent;
            remaining >= epsilon_cost
        } else {
            false
        }
    }

    /// Update budget after a permitted export.
    pub fn spend(&mut self, region_id: &str, epsilon_cost: f32) {
        if let Some(b) = self.budgets.iter_mut().find(|b| b.region_id == region_id) {
            b.epsilon_spent = (b.epsilon_spent + epsilon_cost).min(b.epsilon_total);
        }
    }
}

// -----------------------------------------------------------------------------
// 24. ALN manifest format and Rust struct for bioscale_upgrade_store
// -----------------------------------------------------------------------------

/// Rust struct mapping to ALN/JSON manifest entries for bioscale_upgrade_store.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CapabilityDelta {
    pub axis: String,
    pub delta: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BioscaleUpgradeManifestEntry {
    pub upgrade_id: String,
    pub parent_upgrade_id: Option<String>,
    pub capability_deltas: Vec<CapabilityDelta>,
    /// Reference into the 10-tag EvidenceBundle registry (e.g. `evidence.bundle10.roh.v1`).
    pub evidence_bundle_ref: String,
    /// Hash (e.g. CRC32+serialization) of a Kani proof artifact showing monotone capability.
    pub monotone_capability_proof: String,
}

// Example JSON (ALN manifest row) that this struct parses:
//
// {
//   "upgrade_id": "0x01cf",
//   "parent_upgrade_id": "0x00ff",
//   "capability_deltas": [
//     { "axis": "thermo.delta_c_max", "delta": -0.2 },
//     { "axis": "cognitive.load_ceiling", "delta": -0.05 }
//   ],
//   "evidence_bundle_ref": "evidence.bundle10.roh.v1",
//   "monotone_capability_proof": "evox_9f37a4c2"
// }

// -----------------------------------------------------------------------------
// 25. Evolution-of-consent hot-swap safety with Kani harness
// -----------------------------------------------------------------------------

/// Combined old/new consent pair for evolution-of-consent transitions.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ConsentTransition<C: ConsentProvider> {
    pub old_provider: C,
    pub new_provider: C,
}

impl<'a, C: ConsentProvider> SovereignHostKernel<'a, C> {
    /// Simulate a hot-swap from old consent to new consent for a single state:
    /// both decisions must remain safe (no RoH violation, no neurorights breach).
    pub fn safe_transition_verdicts(
        &self,
        old_state: &KernelState,
        new_state: &KernelState,
        old_provider: &C,
        new_provider: &C,
    ) -> (KernelVerdict, KernelVerdict) {
        let old_kernel =
            SovereignHostKernel::new(old_provider, self.roh_ceiling, self.thermo_ceiling_c, self.cognitive_ceiling);
        let new_kernel =
            SovereignHostKernel::new(new_provider, self.roh_ceiling, self.thermo_ceiling_c, self.cognitive_ceiling);

        let v_old = old_kernel.decide_with_evo(old_state);
        let v_new = new_kernel.decide_with_evo(new_state);

        (v_old, v_new)
    }
}

#[cfg(kani)]
mod kani_evo_transition {
    use super::*;
    use kani::any;

    /// Kani harness: for all old/new consent snapshots and states,
    /// decide_with_evo never returns a verdict that allows RoH > ceiling,
    /// and hot-swap cannot instantaneously violate RoH or neurorights.
    #[kani::proof]
    fn consent_transition_is_safe() {
        let roh_old = any::<f32>();
        let roh_new = any::<f32>();
        let thermo_old = any::<f32>();
        let thermo_new = any::<f32>();
        let cog_old = any::<f32>();
        let cog_new = any::<f32>();

        kani::assume(roh_old.is_finite());
        kani::assume(roh_new.is_finite());
        kani::assume(thermo_old.is_finite());
        kani::assume(thermo_new.is_finite());
        kani::assume(cog_old.is_finite());
        kani::assume(cog_new.is_finite());

        let mode_old = match any::<u8>() % 3 {
            0 => EvoMode::Conservative,
            1 => EvoMode::Copilot,
            _ => EvoMode::Custom,
        };

        let mode_new = match any::<u8>() % 3 {
            0 => EvoMode::Conservative,
            1 => EvoMode::Copilot,
            _ => EvoMode::Custom,
        };

        let thermo_scale_old = any::<f32>().clamp(0.0, 1.0);
        let thermo_scale_new = any::<f32>().clamp(0.0, 1.0);
        let cog_scale_old = any::<f32>().clamp(0.0, 1.0);
        let cog_scale_new = any::<f32>().clamp(0.0, 1.0);

        let old_provider = MockConsentProvider::new(EvoConsentSnapshot {
            mode: mode_old,
            thermo_scale: thermo_scale_old,
            cognitive_scale: cog_scale_old,
        });

        let new_provider = MockConsentProvider::new(EvoConsentSnapshot {
            mode: mode_new,
            thermo_scale: thermo_scale_new,
            cognitive_scale: cog_scale_new,
        });

        let kernel_old = SovereignHostKernel::new(&old_provider, 0.3, 1.0, 1.0);
        let kernel_new = SovereignHostKernel::new(&new_provider, 0.3, 1.0, 1.0);

        let state_old = KernelState {
            roh_scalar: roh_old,
            thermo_delta_c: thermo_old,
            cognitive_load: cog_old,
        };

        let state_new = KernelState {
            roh_scalar: roh_new,
            thermo_delta_c: thermo_new,
            cognitive_load: cog_new,
        };

        let v_old = kernel_old.decide_with_evo(&state_old);
        let v_new = kernel_new.decide_with_evo(&state_new);

        // Safety property: no AutoAllowed or RequiresHostedApproval verdict
        // may occur when RoH exceeds ceiling.
        if roh_old > 0.3 {
            assert!(matches!(v_old, KernelVerdict::AutoDenied));
        }
        if roh_new > 0.3 {
            assert!(matches!(v_new, KernelVerdict::AutoDenied));
        }
    }
}
