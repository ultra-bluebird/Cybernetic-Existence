#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

use crate::model::SacrificeZoneModel;

/// Kinds of hazard metrics relevant for Sacrifice Zones.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum HazardMetricKind {
    TotalLoad,
    PeakConcentration,
    SwarmDutyFraction,
    MaterialRiskProxy,
    NearRohEvents,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum EvidenceSourceKind {
    Empirical,
    SyntheticConservative,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct HazardEvidenceClaim {
    pub claim_id: String,
    pub kind: EvidenceSourceKind,
    pub description: String,
    pub tighten_only: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct HazardEvidenceBundle {
    pub bundle_id: String,
    pub zone_id: String,
    pub claims: Vec<HazardEvidenceClaim>,
}

impl HazardEvidenceBundle {
    pub fn satisfies_tighten_only_policy(&self) -> bool {
        let has_empirical = self
            .claims
            .iter()
            .any(|c| matches!(c.kind, EvidenceSourceKind::Empirical));
        let all_tighten_only = self.claims.iter().all(|c| c.tighten_only);
        has_empirical && all_tighten_only
    }
}

#[derive(Clone, Debug)]
pub struct RawHazardTelemetry {
    pub total_mass: f32,
    pub max_concentration: f32,
    pub max_duty_fraction: f32,
    pub density_risk_local: f32,
    pub thermo_duty_risk: f32,
    pub near_roh_fraction: f32,
}

/// Aggregate hazardous-material metrics for a Sacrifice Zone.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct HazardMetrics {
    pub total_load: f32,
    pub peak_concentration: f32,
    pub swarm_duty_fraction: f32,
    pub material_risk_proxy: f32,
    pub near_roh_events: f32,
}

impl HazardMetrics {
    pub fn clamped(&self) -> Self {
        fn c(x: f32) -> f32 {
            x.clamp(0.0, 1.0)
        }
        Self {
            total_load: c(self.total_load),
            peak_concentration: c(self.peak_concentration),
            swarm_duty_fraction: c(self.swarm_duty_fraction),
            material_risk_proxy: c(self.material_risk_proxy),
            near_roh_events: c(self.near_roh_events),
        }
    }

    pub fn materialrisk_contribution(&self) -> f32 {
        let c = self.clamped();

        let w_total = 0.30_f32;
        let w_peak = 0.25_f32;
        let w_duty = 0.20_f32;
        let w_mrisk = 0.15_f32;
        let w_roh_events = 0.10_f32;

        let linear = w_total * c.total_load
            + w_peak * c.peak_concentration
            + w_duty * c.swarm_duty_fraction
            + w_mrisk * c.material_risk_proxy
            + w_roh_events * c.near_roh_events;

        let max_axis = c
            .total_load
            .max(c.peak_concentration)
            .max(c.swarm_duty_fraction)
            .max(c.material_risk_proxy)
            .max(c.near_roh_events);

        linear.max(max_axis).clamp(0.0, 1.0)
    }

    pub fn from_telemetry(
        raw: &RawHazardTelemetry,
        bundle: &HazardEvidenceBundle,
        total_mass_ref: f32,
        conc_ref: f32,
    ) -> Option<Self> {
        if !bundle.satisfies_tighten_only_policy() {
            return None;
        }

        fn norm(x: f32, ref_val: f32) -> f32 {
            if ref_val <= 0.0 {
                1.0
            } else {
                (x / ref_val).clamp(0.0, 1.0)
            }
        }

        let total_load = norm(raw.total_mass, total_mass_ref);
        let peak_concentration = norm(raw.max_concentration, conc_ref);

        let swarm_duty_fraction = raw.max_duty_fraction.clamp(0.0, 1.0);

        let material_risk_proxy = raw
            .density_risk_local
            .max(raw.thermo_duty_risk)
            .clamp(0.0, 1.0);

        let near_roh_events = raw.near_roh_fraction.clamp(0.0, 1.0);

        Some(HazardMetrics {
            total_load,
            peak_concentration,
            swarm_duty_fraction,
            material_risk_proxy,
            near_roh_events,
        })
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct HazardMetricSummary {
    pub total_load: f32,
    pub peak_concentration: f32,
    pub swarm_duty_fraction: f32,
    pub material_risk_proxy: f32,
    pub near_roh_events: f32,
    pub materialrisk_contribution: f32,
}

impl HazardMetricSummary {
    pub fn from_metrics(metrics: &HazardMetrics) -> Self {
        let c = metrics.clamped();
        let contribution = metrics.materialrisk_contribution();
        Self {
            total_load: c.total_load,
            peak_concentration: c.peak_concentration,
            swarm_duty_fraction: c.swarm_duty_fraction,
            material_risk_proxy: c.material_risk_proxy,
            near_roh_events: c.near_roh_events,
            materialrisk_contribution: contribution,
        }
    }
}

pub fn render_zone_doc(model: &SacrificeZoneModel) -> String {
    let summary = HazardMetricSummary::from_metrics(&model.metrics);
    format!(
        "Sacrifice Zone {label} ({id})\n\
         hazard_class: {class}\n\
         total_load: {tl:.3}\n\
         peak_concentration: {pc:.3}\n\
         swarm_duty_fraction: {sd:.3}\n\
         material_risk_proxy: {mr:.3}\n\
         near_roh_events: {er:.3}\n\
         materialrisk_contribution: {mc:.3}",
        label = model.envelope.label,
        id = model.envelope.zone_id.id,
        class = format!("{:?}", model.envelope.hazard_class),
        tl = summary.total_load,
        pc = summary.peak_concentration,
        sd = summary.swarm_duty_fraction,
        mr = summary.material_risk_proxy,
        er = summary.near_roh_events,
        mc = summary.materialrisk_contribution,
    )
}
