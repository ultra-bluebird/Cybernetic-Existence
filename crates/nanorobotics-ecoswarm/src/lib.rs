//! nanorobotics-ecoswarm
//!
//! Eco-aware nanoswarm mission scheduling interfaces.
//!
//! This crate defines generic traits and data structures for eco-swarm mission
//! planning. The planner operates on abstract energy/carbon profiles and does
//! not depend on any particular upstream catalog format. Region-specific
//! adapters (e.g., Phoenix) map external catalogs into these types.

#![forbid(unsafe_code)]
#![deny(missing_docs)]

use std::time::Duration;

/// Normalized risk scale used across the ecoswarm planner.
pub type Risk = f32;

/// Represents an energy and carbon intensity profile for a region or site.
///
/// Time is represented as discrete slots of equal duration.
#[derive(Clone, Debug)]
pub struct EnergyCarbonProfile {
    /// Duration of each slot.
    pub slot_duration: Duration,
    /// Grid carbon intensity per slot, in grams CO2 per kWh.
    pub grid_ci_g_per_kwh: Vec<f32>,
    /// Available solar (or other green) power per slot, in kW.
    pub green_power_kw: Vec<f32>,
}

/// Represents a host coupling envelope for an eco-swarm mission.
///
/// This captures constraints on how much energy or environmental impact
/// can be attributed to eco missions while a host is present.
#[derive(Clone, Debug)]
pub struct VampiricHealthcareEnvelope {
    /// Maximum additional power draw (kW) attributable to eco missions
    /// during host-coupled periods.
    pub max_extra_power_kw: f32,
    /// Maximum incremental risk contribution on the host's Risk-of-Harm scale.
    pub max_extra_risk: Risk,
}

/// Describes a candidate mission segment in time.
#[derive(Clone, Debug)]
pub struct MissionSegment {
    /// Start slot index in the EnergyCarbonProfile arrays.
    pub start_slot: usize,
    /// Number of slots.
    pub length_slots: usize,
    /// Average power demand of the swarm in kW during this segment.
    pub swarm_power_kw: f32,
}

/// The result of scheduling a mission along an energy/carbon profile.
#[derive(Clone, Debug)]
pub struct MissionSchedule {
    /// Selected segments in chronological order.
    pub segments: Vec<MissionSegment>,
    /// Estimated total energy consumed (kWh).
    pub total_energy_kwh: f32,
    /// Estimated total carbon emitted (grams CO2).
    pub total_carbon_g: f32,
    /// Estimated risk contribution to the host, on normalized scale.
    pub total_risk: Risk,
}

/// Planner configuration capturing preference weights and feasibility thresholds.
#[derive(Clone, Debug)]
pub struct EcoSwarmPlannerConfig {
    /// Weight on energy consumption in the optimization objective.
    pub weight_energy: f32,
    /// Weight on carbon intensity in the optimization objective.
    pub weight_carbon: f32,
    /// Weight on risk contribution in the optimization objective.
    pub weight_risk: f32,
    /// Maximum total mission risk allowed.
    pub max_total_risk: Risk,
}

/// Trait implemented by simple mission planners.
pub trait EcoSwarmPlanner {
    /// Computes a mission schedule given an energy/carbon profile and host envelope.
    fn plan_mission(
        &self,
        profile: &EnergyCarbonProfile,
        host_envelope: Option<&VampiricHealthcareEnvelope>,
        required_energy_kwh: f32,
    ) -> Option<MissionSchedule>;
}

/// A simple greedy planner that prefers lower-carbon and lower-risk slots.
///
/// This implementation is intentionally conservative and deterministic.
/// It can be replaced or complemented by more sophisticated solvers later.
#[derive(Clone, Debug)]
pub struct GreedyEcoSwarmPlanner {
    /// Planner configuration.
    pub cfg: EcoSwarmPlannerConfig,
}

impl GreedyEcoSwarmPlanner {
    /// Creates a new greedy planner with the given configuration.
    pub fn new(cfg: EcoSwarmPlannerConfig) -> Self {
        Self { cfg }
    }
}

impl EcoSwarmPlanner for GreedyEcoSwarmPlanner {
    fn plan_mission(
        &self,
        profile: &EnergyCarbonProfile,
        host_envelope: Option<&VampiricHealthcareEnvelope>,
        required_energy_kwh: f32,
    ) -> Option<MissionSchedule> {
        let n_slots = profile.grid_ci_g_per_kwh.len();
        if n_slots == 0 || profile.green_power_kw.len() != n_slots {
            return None;
        }

        // Simple heuristic scoring per slot: lower is better.
        let mut slot_scores: Vec<(usize, f32)> = Vec::with_capacity(n_slots);
        for i in 0..n_slots {
            let ci = profile.grid_ci_g_per_kwh[i].max(0.0);
            let green = profile.green_power_kw[i].max(0.0);
            // Prefer slots with higher green power and lower carbon intensity.
            let score = self.cfg.weight_carbon * ci - green;
            slot_scores.push((i, score));
        }

        // Sort slots by score ascending.
        slot_scores.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap_or(std::cmp::Ordering::Equal));

        let slot_hours = profile.slot_duration.as_secs_f32() / 3600.0;
        let mut accumulated_energy = 0.0_f32;
        let mut total_carbon_g = 0.0_f32;
        let mut total_risk: Risk = 0.0;
        let mut segments: Vec<MissionSegment> = Vec::new();

        for (slot_idx, _) in slot_scores {
            if accumulated_energy >= required_energy_kwh {
                break;
            }

            let ci = profile.grid_ci_g_per_kwh[slot_idx].max(0.0);
            let green = profile.green_power_kw[slot_idx].max(0.0);

            // Assume swarm uses up to available green power first.
            let swarm_power_kw = if green > 0.0 { green } else { 1.0 };
            let energy_kwh = swarm_power_kw * slot_hours;

            // Host envelope constraint: limit extra power when host is coupled.
            if let Some(env) = host_envelope {
                if swarm_power_kw > env.max_extra_power_kw {
                    continue;
                }
            }

            // Estimate risk contribution as a small function of power and carbon.
            let risk_contrib = (swarm_power_kw * ci / 1000.0).min(self.cfg.max_total_risk);
            if total_risk + risk_contrib > self.cfg.max_total_risk {
                continue;
            }

            accumulated_energy += energy_kwh;
            total_carbon_g += energy_kwh * ci;
            total_risk += risk_contrib;

            segments.push(MissionSegment {
                start_slot: slot_idx,
                length_slots: 1,
                swarm_power_kw,
            });
        }

        if accumulated_energy < required_energy_kwh {
            return None;
        }

        Some(MissionSchedule {
            segments,
            total_energy_kwh: accumulated_energy,
            total_carbon_g,
            total_risk,
        })
    }
}

/// Helper for building a Phoenix-focused energy/carbon profile.
///
/// This function is intentionally generic; upstream code should map external
/// Phoenix catalogs into the arguments here.
pub fn build_phoenix_profile(
    slot_duration: Duration,
    grid_ci_g_per_kwh: Vec<f32>,
    green_power_kw: Vec<f32>,
) -> Option<EnergyCarbonProfile> {
    if grid_ci_g_per_kwh.len() != green_power_kw.len() || grid_ci_g_per_kwh.is_empty() {
        return None;
    }
    Some(EnergyCarbonProfile {
        slot_duration,
        grid_ci_g_per_kwh,
        green_power_kw,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn simple_planner_succeeds() {
        let profile = EnergyCarbonProfile {
            slot_duration: Duration::from_secs(900),
            grid_ci_g_per_kwh: vec![400.0, 300.0, 500.0],
            green_power_kw: vec![2.0, 3.0, 0.0],
        };
        let env = VampiricHealthcareEnvelope {
            max_extra_power_kw: 3.0,
            max_extra_risk: 0.5,
        };
        let cfg = EcoSwarmPlannerConfig {
            weight_energy: 1.0,
            weight_carbon: 1.0,
            weight_risk: 1.0,
            max_total_risk: 0.5,
        };
        let planner = GreedyEcoSwarmPlanner::new(cfg);
        let schedule = planner.plan_mission(&profile, Some(&env), 1.0);
        assert!(schedule.is_some());
        let s = schedule.unwrap();
        assert!(s.total_energy_kwh >= 1.0);
        assert!(s.total_carbon_g >= 0.0);
        assert!(s.total_risk <= 0.5 + 1e-6);
    }

    #[test]
    fn phoenix_profile_helper_validates_lengths() {
        let ok = build_phoenix_profile(
            Duration::from_secs(3600),
            vec![400.0, 350.0],
            vec![1.0, 2.0],
        );
        assert!(ok.is_some());

        let bad = build_phoenix_profile(
            Duration::from_secs(3600),
            vec![400.0],
            vec![1.0, 2.0],
        );
        assert!(bad.is_none());
    }
}
