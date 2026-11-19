#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

use cybercore_category::{CorridorMonoidalCorridor, CorridorPolytope7D, SovereigntyInvariants};
use crate::metrics::HazardMetrics;
use crate::AlnAuthorityMarker;

/// Stable identifier for a Sacrifice Zone, suitable for ALN registry entries.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct SacrificeZoneId {
    /// Short hex or human-readable ID, must match ALN registry.
    pub id: String,
}

/// Coarse hazard classification for a Sacrifice Zone.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum HazardClass {
    Chemical,
    Radiological,
    Nanomaterial,
    Mixed,
}

/// Geometry and metadata for a Sacrifice Zone.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct SacrificeZoneEnvelope {
    /// Sovereign identity and migration authority binding.
    pub authority: AlnAuthorityMarker,

    /// Zone identifier (mirrors ALN corridor registry entry).
    pub zone_id: SacrificeZoneId,

    /// Human-readable label, e.g. "IntegumentBurn.HandLeft.DetoxCorridor".
    pub label: String,

    /// Hazard class (chemical, radiological, etc.).
    pub hazard_class: HazardClass,

    /// Base 7D corridor polytope for this zone (A x <= b).
    pub corridor_polytope: CorridorPolytope7D,

    /// Maximum admissible RoH proxy for this zone (<= 0.30).
    pub roh_ceiling: f32,
}

impl SacrificeZoneEnvelope {
    /// Returns true if the envelope is bound to the canonical host and authority.
    pub fn is_canonical(&self) -> bool {
        self.authority.is_canonical()
    }
}

/// Snapshot of a Sacrifice Zone, combining geometry, metrics, and corridor state.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct SacrificeZoneModel {
    /// ALN and identity authority marker.
    pub authority: AlnAuthorityMarker,

    /// Base envelope (geometry + metadata).
    pub envelope: SacrificeZoneEnvelope,

    /// Hazard metrics (normalized 0–1) derived from telemetry and evidence bundles.
    pub metrics: HazardMetrics,

    /// Corridor view for this zone, embedding the 7D polytope and RoH proxy.
    ///
    /// This mirrors `CorridorMonoidalCorridor` semantics and can be fed into
    /// `nanorobotics-cbf-guards` barrier guards.
    pub corridor: CorridorMonoidalCorridor,
}

impl SacrificeZoneModel {
    /// Construct a new Sacrifice Zone model from an envelope, metrics, and corridor.
    ///
    /// Callers must ensure the corridor uses the same 7D axis ordering as the envelope polytope.
    pub fn new(
        envelope: SacrificeZoneEnvelope,
        metrics: HazardMetrics,
        corridor: CorridorMonoidalCorridor,
    ) -> Self {
        let authority = envelope.authority.clone();
        Self {
            authority,
            envelope,
            metrics,
            corridor,
        }
    }

    /// Returns true if the current corridor satisfies the envelope's RoH ceiling and geometry.
    pub fn satisfies_envelope_invariants(&self) -> bool {
        let inv = SovereigntyInvariants {
            roh_ceiling: self.envelope.roh_ceiling,
            ..Default::default()
        };
        self.corridor.satisfies_invariants(inv)
    }
}

/// Priority classes for Sacrifice Zones.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum PriorityClass {
    A,
    B,
    C,
    D,
}

/// Specification for a priority class, as derived from ALNv2 shards.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct PriorityClassSpec {
    pub class: PriorityClass,
    pub contamination_min: f32,
    pub contamination_max: f32,
    pub roh_band_min: f32,
    pub roh_band_max: f32,
    pub max_near_roh_events: f32,
    pub max_swarm_duty_fraction: f32,
    pub max_materialrisk_contribution: f32,
}

/// Priority shard binding ALN authority to class specifications.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct PriorityShard {
    pub authority: AlnAuthorityMarker,
    pub classes: Vec<PriorityClassSpec>,
}

impl PriorityShard {
    /// Assign a priority class based on contamination index, RoH proxy, and material risk.
    ///
    /// Returns the most restrictive (highest priority) class whose constraints hold.
    pub fn assign_class(
        &self,
        metrics: &HazardMetrics,
        roh_proxy: f32,
        materialrisk: f32,
    ) -> Option<PriorityClassSpec> {
        if !self.authority.is_canonical() {
            return None;
        }

        let ci = metrics.contamination_index();
        let m = metrics.clamped();

        let mut best: Option<PriorityClassSpec> = None;

        for spec in &self.classes {
            if ci < spec.contamination_min || ci > spec.contamination_max {
                continue;
            }
            if roh_proxy < spec.roh_band_min || roh_proxy > spec.roh_band_max {
                continue;
            }
            if m.near_roh_events > spec.max_near_roh_events {
                continue;
            }
            if m.swarm_duty_fraction > spec.max_swarm_duty_fraction {
                continue;
            }
            if materialrisk > spec.max_materialrisk_contribution {
                continue;
            }

            match &best {
                None => best = Some(spec.clone()),
                Some(current) => {
                    if priority_rank(&spec.class) < priority_rank(&current.class) {
                        best = Some(spec.clone());
                    }
                }
            }
        }

        best
    }
}

fn priority_rank(class: &PriorityClass) -> u8 {
    match class {
        PriorityClass::A => 0,
        PriorityClass::B => 1,
        PriorityClass::C => 2,
        PriorityClass::D => 3,
    }
}
