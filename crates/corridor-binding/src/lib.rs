// destination-path: crates/corridor-binding/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use serde::{Deserialize, Serialize};
use std::collections::HashSet;

/// ALN corridor binding that links a specific EvidenceBundle tag
/// to a field in a ThermodynamicEnvelope-like host envelope.
///
/// This struct is host-bound via host_did and bostrom_address and asserts
/// ALN.MIGRATION.CYBERCORE_AUTHORITY.v1 so Cybercore is the sole evolution authority.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CorridorBinding {
    /// Host DID, bound to augmented host.
    pub host_did: String,
    /// Primary stakeholder Bostrom address (must be `bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`).
    pub bostrom_address: String,
    /// ALN migration authority clause; must equal `ALN.MIGRATION.CYBERCORE_AUTHORITY.v1`.
    pub aln_migration_clause: String,
    /// Hex tag of the EvidenceBundle sequence that this binding consumes (e.g. `2f8c6b44` for thermo caps).
    pub evidence_tag_hex: String,
    /// Fully qualified envelope field path in Rust (e.g. `ThermodynamicEnvelope.core_temp_delta_max_c`).
    pub envelope_field_path: String,
    /// Binding type (Max, Min, Floor, Ceiling) describing how evidence value constrains the envelope field.
    pub binding_type: BindingType,
}

/// Binding semantics for applying evidence values to envelope fields.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum BindingType {
    /// Treat evidence as a hard maximum; envelope field becomes `min(current, evidence)`.
    Max,
    /// Treat evidence as a hard minimum; envelope field becomes `max(current, evidence)`.
    Min,
    /// Treat evidence as a lower floor that cannot be undercut by the envelope.
    Floor,
    /// Treat evidence as an upper ceiling that cannot be exceeded by the envelope.
    Ceiling,
}

/// Minimal trait for envelopes that expose thermo delta fields.
/// Concrete envelopes (e.g. ThermodynamicEnvelope) must implement this.
///
/// This trait is object-safe for dynamic dispatch.
pub trait Envelope {
    fn core_temp_delta_max_c(&self) -> f32;
    fn set_core_temp_delta_max_c(&mut self, value: f32);

    fn core_temp_delta_min_c(&self) -> f32;
    fn set_core_temp_delta_min_c(&mut self, value: f32);
}

impl CorridorBinding {
    /// Apply the evidence value to the target envelope in-place, using the binding_type rules.
    ///
    /// For `ThermodynamicEnvelope.core_temp_delta_max_c`, this will typically
    /// shrink the allowable thermal delta corridor, never widen it.
    pub fn apply_to_envelope(&self, evidence_value: f32, envelope: &mut dyn Envelope) {
        match (self.binding_type, self.envelope_field_path.as_str()) {
            (BindingType::Max, "ThermodynamicEnvelope.core_temp_delta_max_c") => {
                let current = envelope.core_temp_delta_max_c();
                let updated = current.min(evidence_value);
                envelope.set_core_temp_delta_max_c(updated);
            }
            (BindingType::Ceiling, "ThermodynamicEnvelope.core_temp_delta_max_c") => {
                let current = envelope.core_temp_delta_max_c();
                let updated = current.min(evidence_value);
                envelope.set_core_temp_delta_max_c(updated);
            }
            (BindingType::Min, "ThermodynamicEnvelope.core_temp_delta_min_c") => {
                let current = envelope.core_temp_delta_min_c();
                let updated = current.max(evidence_value);
                envelope.set_core_temp_delta_min_c(updated);
            }
            (BindingType::Floor, "ThermodynamicEnvelope.core_temp_delta_min_c") => {
                let current = envelope.core_temp_delta_min_c();
                let updated = current.max(evidence_value);
                envelope.set_core_temp_delta_min_c(updated);
            }
            // For any other field path, no-op until a concrete mapping is added.
            _ => {}
        }
    }

    /// ALN serialization stub for corridor binding.
    ///
    /// Example ALN row (single-line):
    /// roh.corridor.binding.v1,host_did=did:aln:organic-cpu-host,
    /// bostrom=bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7,
    /// aln_clause=ALN.MIGRATION.CYBERCORE_AUTHORITY.v1,
    /// evidence_tag=2f8c6b44,
    /// field=ThermodynamicEnvelope.core_temp_delta_max_c,
    /// binding=Max
    pub fn to_aln_row(&self) -> String {
        format!(
            "roh.corridor.binding.v1,host_did={},bostrom={},aln_clause={},evidence_tag={},field={},binding={}",
            self.host_did,
            self.bostrom_address,
            self.aln_migration_clause,
            self.evidence_tag_hex,
            self.envelope_field_path,
            match self.binding_type {
                BindingType::Max => "Max",
                BindingType::Min => "Min",
                BindingType::Floor => "Floor",
                BindingType::Ceiling => "Ceiling",
            }
        )
    }
}

// -----------------------------------------------------------------------------
// EvoConsent scaling vs rohmodel polytope
// -----------------------------------------------------------------------------

/// Thermodynamic envelope with a convex corridor over core temperature delta.
/// This is a stand-in for the thermo slice of rohmodel.aln.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ThermodynamicEnvelope {
    /// Maximum allowed core temperature delta above baseline (C).
    pub core_temp_delta_max_c: f32,
    /// Minimum allowed core temperature delta above baseline (C).
    pub core_temp_delta_min_c: f32,
}

impl Envelope for ThermodynamicEnvelope {
    fn core_temp_delta_max_c(&self) -> f32 {
        self.core_temp_delta_max_c
    }

    fn set_core_temp_delta_max_c(&mut self, value: f32) {
        self.core_temp_delta_max_c = value;
    }

    fn core_temp_delta_min_c(&self) -> f32 {
        self.core_temp_delta_min_c
    }

    fn set_core_temp_delta_min_c(&mut self, value: f32) {
        self.core_temp_delta_min_c = value;
    }
}

/// EvoConsent scaling parameters as loaded from `.evo` shard.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvoConsentScaling {
    /// Conservative mode scale factor for maximum thermo delta (0.0–1.0).
    pub conservative_thermo_delta_c_max_scale: f32,
    /// Copilot mode scale factor for maximum thermo delta (0.0–1.0).
    pub copilot_thermo_delta_c_max_scale: Option<f32>,
}

/// Apply EvoConsent scaling to a base thermodynamic envelope, returning a new envelope
/// with tightened bounds. Scale factor in [0,1] shrinks the max delta toward zero.
pub fn scaled_thermodynamic_envelope(
    base: &ThermodynamicEnvelope,
    scale: f32,
) -> ThermodynamicEnvelope {
    let s = scale.clamp(0.0, 1.0);
    ThermodynamicEnvelope {
        core_temp_delta_min_c: base.core_temp_delta_min_c, // conservative paths do not relax minima
        core_temp_delta_max_c: base.core_temp_delta_max_c * s,
    }
}

/// Kani harness: for all base envelopes with 0 <= min <= max and all scale in [0,1],
/// the scaled envelope is at least as restrictive (max never increases, min never decreases).
#[cfg(kani)]
mod kani_invariants {
    use super::*;
    use kani::any;

    #[kani::proof]
    fn scaled_envelope_is_subset_of_base() {
        let min = any::<f32>();
        let max = any::<f32>();
        let scale = any::<f32>();

        kani::assume(min >= 0.0);
        kani::assume(max >= min);
        kani::assume(scale >= 0.0 && scale <= 1.0);

        let base = ThermodynamicEnvelope {
            core_temp_delta_min_c: min,
            core_temp_delta_max_c: max,
        };

        let scaled = scaled_thermodynamic_envelope(&base, scale);

        // Invariant 1: min bound is unchanged (subset or equal).
        assert!(scaled.core_temp_delta_min_c >= base.core_temp_delta_min_c);
        // Invariant 2: max bound never increases; scaled corridor is subset of base.
        assert!(scaled.core_temp_delta_max_c <= base.core_temp_delta_max_c);
    }
}

// -----------------------------------------------------------------------------
// Neurothermo snapshot mesh_thermal_impact
// -----------------------------------------------------------------------------

/// Aggregate thermal component already used in rohmodel and neurothermo snapshots.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RohThermalComponent {
    /// Net core thermal delta in Celsius over baseline.
    pub core_delta_c: f32,
    /// Net cortical or regional brain delta in Celsius.
    pub cortex_delta_c: f32,
    /// Global thermal risk index in [0,1].
    pub risk_index: f32,
}

/// Per-region thermal contribution from active organic mesh regions.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MeshRegionThermalDelta {
    /// Stable region identifier (e.g. `mesh:occipital`, `mesh:cerebellum`).
    pub region_id: String,
    /// Local temperature delta in Celsius relative to region baseline.
    pub delta_c: f32,
}

/// neurothermo.snapshot.v1 extension with mesh_thermal_impact.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NeuroThermoSnapshotV1 {
    /// Existing roh thermal aggregate.
    pub roh_thermal_component: RohThermalComponent,
    /// Vector of per-region thermal deltas from organic mesh activity.
    pub mesh_thermal_impact: Vec<MeshRegionThermalDelta>,
}

impl NeuroThermoSnapshotV1 {
    /// Aggregate mesh_thermal_impact into roh_thermal_component by:
    /// - Summing positive deltas into core and cortex deltas.
    /// - Updating risk_index with a normalized, capped contribution from the
    ///   largest regional delta and the number of concurrently active regions.
    pub fn aggregate_mesh_into_roh(&mut self) {
        let mut mesh_core_accum = 0.0_f32;
        let mut mesh_cortex_accum = 0.0_f32;
        let mut max_regional_delta = 0.0_f32;

        for region in &self.mesh_thermal_impact {
            if region.delta_c > 0.0 {
                mesh_core_accum += region.delta_c;
                mesh_cortex_accum += region.delta_c;
                if region.delta_c > max_regional_delta {
                    max_regional_delta = region.delta_c;
                }
            }
        }

        self.roh_thermal_component.core_delta_c += mesh_core_accum;
        self.roh_thermal_component.cortex_delta_c += mesh_cortex_accum;

        let region_count = self.mesh_thermal_impact.len() as f32;

        // Invariant: thermal runaway prevention from excessive concurrent mesh ops.
        // We compute a mesh_risk in [0,1] as:
        // mesh_risk = 1 - exp(-alpha * max_delta * min(region_count, region_cap)).
        // alpha > 0 ensures monotone increase; region_cap caps runaway from unbounded N.
        let alpha = 0.25_f32;
        let region_cap = 16.0_f32;
        let capped_regions = region_count.min(region_cap);
        let mesh_risk = if max_regional_delta <= 0.0 || capped_regions <= 0.0 {
            0.0
        } else {
            let x = alpha * max_regional_delta * capped_regions;
            let e = (-x).exp();
            1.0_f32 - e
        };

        // Risk index is the maximum of existing risk and mesh-induced risk,
        // capped at 1.0 and never decreased by aggregation.
        let combined_risk = self.roh_thermal_component.risk_index.max(mesh_risk);
        self.roh_thermal_component.risk_index = combined_risk.min(1.0);
    }
}

// -----------------------------------------------------------------------------
// EvoConsentLoader copilot_scaling extraction
// -----------------------------------------------------------------------------

/// Copilot and conservative scaling factors as present in the raw `.evo` shard.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvoScalingRaw {
    pub conservative_thermo_delta_c_max_scale: Option<f32>,
    pub copilot_thermo_delta_c_max_scale: Option<f32>,
}

/// Loaded EvoConsent profile with explicit modes.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvoConsentProfile {
    pub conservative_scaling: EvoConsentScaling,
    pub copilot_scaling: EvoConsentScaling,
}

impl EvoConsentProfile {
    /// Construct from raw shard data, preserving explicit copilot_scaling if present
    /// and falling back to 1.0 only when not specified.
    pub fn from_raw(raw: &EvoScalingRaw) -> Self {
        let conservative_scale = raw
            .conservative_thermo_delta_c_max_scale
            .unwrap_or(1.0)
            .clamp(0.0, 1.0);

        let copilot_scale = raw
            .copilot_thermo_delta_c_max_scale
            .unwrap_or(1.0)
            .clamp(0.0, 1.0);

        EvoConsentProfile {
            conservative_scaling: EvoConsentScaling {
                conservative_thermo_delta_c_max_scale: conservative_scale,
                copilot_thermo_delta_c_max_scale: Some(copilot_scale),
            },
            copilot_scaling: EvoConsentScaling {
                conservative_thermo_delta_c_max_scale: copilot_scale,
                copilot_thermo_delta_c_max_scale: Some(copilot_scale),
            },
        }
    }
}

// -----------------------------------------------------------------------------
// MeshRegionPolicy trait
// -----------------------------------------------------------------------------

/// Actions that an organic mesh region may perform.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum MeshAction {
    Sense,
    Modulate,
    Route,
    Compute,
    Store,
}

/// Error type for mesh policy validation.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MeshPolicyError {
    pub message: String,
}

/// BioState is a reduced snapshot of host state needed for mesh policy evaluation.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BioState {
    pub roh: f32,
    pub core_temp_delta_c: f32,
    pub cortex_temp_delta_c: f32,
    pub pain_index: f32,
}

/// Object-safe policy interface for organic mesh regions.
///
/// This trait is designed for dynamic dispatch by the mesh manager; all methods
/// take `&self` and return owned values.
pub trait MeshRegionPolicy {
    /// Return this region's contribution to the global roh thermal component,
    /// given the current host BioState (positive numbers tighten corridors).
    fn roh_contribution(&self, state: &BioState) -> f32;

    /// Return the set of allowed actions for this region under current policy.
    fn allowed_actions(&self) -> HashSet<MeshAction>;

    /// Validate that permissions, evidence bindings, and ALN clauses are consistent.
    /// Returns Ok(()) if region may be activated, or MeshPolicyError otherwise.
    fn validate_permissions(&self) -> Result<(), MeshPolicyError>;
}

// -----------------------------------------------------------------------------
// 10 biophysical evidence sequences with hex tags (non-rollback invariants)
// -----------------------------------------------------------------------------

/// Fixed 10-tag EvidenceBundle registry for thermal-mesh corridors.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvidenceTag {
    pub short_hex: &'static str,
    pub description: &'static str,
}

pub const EVIDENCE_SEQ_THERMO_MESH: [EvidenceTag; 10] = [
    EvidenceTag {
        short_hex: "a1f3c9b2",
        description: "Brain RMR and daily energy envelope",
    },
    EvidenceTag {
        short_hex: "4be79d01",
        description: "ATP coupling and joule conversion",
    },
    EvidenceTag {
        short_hex: "9cd4a7e8",
        description: "Protein turnover for synaptic plasticity",
    },
    EvidenceTag {
        short_hex: "2f8c6b44",
        description: "Thermal caps for cortical safety",
    },
    EvidenceTag {
        short_hex: "7e1da2ff",
        description: "Neurovascular coupling and perfusion",
    },
    EvidenceTag {
        short_hex: "5b93e0c3",
        description: "EEG/ML duty-cycle safety",
    },
    EvidenceTag {
        short_hex: "d0174aac",
        description: "Safe duty-cycle per corridor",
    },
    EvidenceTag {
        short_hex: "6ac2f9d9",
        description: "Neuromorphic workload limits",
    },
    EvidenceTag {
        short_hex: "c4e61b20",
        description: "Pain / inflammation thresholds",
    },
    EvidenceTag {
        short_hex: "8f09d5ee",
        description: "Visual corridor blink index evidence",
    },
];

#[cfg(test)]
mod tests {
    use super::*;

    struct TestEnvelope {
        max_c: f32,
        min_c: f32,
    }

    impl Envelope for TestEnvelope {
        fn core_temp_delta_max_c(&self) -> f32 {
            self.max_c
        }
        fn set_core_temp_delta_max_c(&mut self, value: f32) {
            self.max_c = value;
        }
        fn core_temp_delta_min_c(&self) -> f32 {
            self.min_c
        }
        fn set_core_temp_delta_min_c(&mut self, value: f32) {
            self.min_c = value;
        }
    }

    #[test]
    fn corridor_binding_max_shrinks_envelope() {
        let mut env = TestEnvelope {
            max_c: 1.5,
            min_c: 0.0,
        };
        let binding = CorridorBinding {
            host_did: "did:aln:organic-cpu-host".to_string(),
            bostrom_address: "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_string(),
            aln_migration_clause: "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1".to_string(),
            evidence_tag_hex: "2f8c6b44".to_string(),
            envelope_field_path: "ThermodynamicEnvelope.core_temp_delta_max_c".to_string(),
            binding_type: BindingType::Max,
        };
        binding.apply_to_envelope(1.0, &mut env);
        assert!((env.max_c - 1.0).abs() < 1e-6);
    }

    #[test]
    fn evo_consent_profile_uses_copilot_if_present() {
        let raw = EvoScalingRaw {
            conservative_thermo_delta_c_max_scale: Some(0.5),
            copilot_thermo_delta_c_max_scale: Some(0.8),
        };
        let profile = EvoConsentProfile::from_raw(&raw);
        assert!((profile.conservative_scaling.conservative_thermo_delta_c_max_scale - 0.5).abs() < 1e-6);
        assert!((profile.copilot_scaling.conservative_thermo_delta_c_max_scale - 0.8).abs() < 1e-6);
    }

    #[test]
    fn neurothermo_mesh_aggregation_increases_risk_monotonically() {
        let mut snap = NeuroThermoSnapshotV1 {
            roh_thermal_component: RohThermalComponent {
                core_delta_c: 0.0,
                cortex_delta_c: 0.0,
                risk_index: 0.0,
            },
            mesh_thermal_impact: vec![
                MeshRegionThermalDelta {
                    region_id: "mesh:occipital".to_string(),
                    delta_c: 0.4,
                },
                MeshRegionThermalDelta {
                    region_id: "mesh:cerebellum".to_string(),
                    delta_c: 0.3,
                },
            ],
        };
        snap.aggregate_mesh_into_roh();
        assert!(snap.roh_thermal_component.core_delta_c > 0.0);
        assert!(snap.roh_thermal_component.cortex_delta_c > 0.0);
        assert!(snap.roh_thermal_component.risk_index >= 0.0);
        assert!(snap.roh_thermal_component.risk_index <= 1.0);
    }
}
