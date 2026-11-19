use alloc::collections::{BTreeMap, BTreeSet};
use alloc::string::String;
use alloc::vec;
use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, PositiveF64, UnitInterval};
use crate::continuity::ContinuityAssessment;
use crate::error::{PopmathError, PopmathResult};
use crate::units::{DistanceM, DurationSeconds, PopulationWeight};

#[derive(Clone, Debug, Eq, PartialEq, Ord, PartialOrd, Hash)]
pub struct NetworkNode {
    name: String,
}

impl NetworkNode {
    pub fn new(name: impl Into<String>) -> PopmathResult<Self> {
        let name = name.into();

        if name.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "network_node",
            });
        }

        Ok(Self { name })
    }

    #[must_use]
    pub fn name(&self) -> &str {
        &self.name
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TravelMode {
    Walking,
    Rolling,
    Cycling,
    Transit,
    Freight,
    Emergency,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AccessibilityState {
    VerifiedAccessible,
    Inaccessible,
    Unknown,
}

#[derive(Clone, Debug, PartialEq)]
pub struct NetworkEdge {
    pub name: String,
    pub from: NetworkNode,
    pub to: NetworkNode,
    pub distance: DistanceM,
    pub travel_duration: DurationSeconds,
    pub travel_mode: TravelMode,
    pub open: bool,
    pub accessibility: AccessibilityState,
}

impl NetworkEdge {
    pub fn validate(&self) -> PopmathResult<()> {
        if self.name.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "network_edge_name",
            });
        }

        if self.from == self.to {
            return Err(PopmathError::InvalidScenario {
                field: "network_edge_endpoints",
            });
        }

        if self.travel_duration.get() == 0.0 && self.distance.get() > 0.0 {
            return Err(PopmathError::InvalidScenario {
                field: "network_edge_travel_duration",
            });
        }

        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct AccessibleRouteInput {
    pub origin: NetworkNode,
    pub destination: NetworkNode,
    pub travel_mode: TravelMode,
    pub maximum_duration: DurationSeconds,
    pub edges: Vec<NetworkEdge>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct AccessibleRouteResult {
    pub nodes: Vec<NetworkNode>,
    pub edge_names: Vec<String>,
    pub total_distance: DistanceM,
    pub total_duration: DurationSeconds,
    pub full_path_accessible: bool,
}

pub fn calculate_accessible_route(
    input: &AccessibleRouteInput,
) -> PopmathResult<AccessibleRouteResult> {
    if input.edges.is_empty() {
        return Err(PopmathError::InfeasibleConstraints {
            reason: "no network edges were supplied",
        });
    }

    if input.maximum_duration.get() <= 0.0 {
        return Err(PopmathError::InvalidScenario {
            field: "maximum_route_duration",
        });
    }

    for edge in &input.edges {
        edge.validate()?;
    }

    if input.origin == input.destination {
        return Ok(AccessibleRouteResult {
            nodes: vec![input.origin.clone()],
            edge_names: Vec::new(),
            total_distance: DistanceM::new(0.0)?,
            total_duration: DurationSeconds::new(0.0)?,
            full_path_accessible: true,
        });
    }

    let route_edges = eligible_accessible_edges(input);
    let route = shortest_duration_route(
        &route_edges,
        &input.origin,
        &input.destination,
        input.maximum_duration.get(),
    )?;

    Ok(AccessibleRouteResult {
        nodes: route.nodes,
        edge_names: route.edge_names,
        total_distance: DistanceM::new(route.total_distance_meters)?,
        total_duration: DurationSeconds::new(route.total_duration_seconds)?,
        full_path_accessible: true,
    })
}

fn eligible_accessible_edges(
    input: &AccessibleRouteInput,
) -> Vec<&NetworkEdge> {
    input
        .edges
        .iter()
        .filter(|edge| {
            edge.travel_mode == input.travel_mode
                && edge.open
                && edge.accessibility == AccessibilityState::VerifiedAccessible
        })
        .collect()
}

#[derive(Clone, Debug, PartialEq)]
struct DurationRoute {
    nodes: Vec<NetworkNode>,
    edge_names: Vec<String>,
    total_distance_meters: f64,
    total_duration_seconds: f64,
}

fn shortest_duration_route(
    edges: &[&NetworkEdge],
    origin: &NetworkNode,
    destination: &NetworkNode,
    maximum_duration_seconds: f64,
) -> PopmathResult<DurationRoute> {
    let mut node_names = BTreeSet::new();

    node_names.insert(origin.name().to_owned());
    node_names.insert(destination.name().to_owned());

    for edge in edges {
        node_names.insert(edge.from.name().to_owned());
        node_names.insert(edge.to.name().to_owned());
    }

    let mut tentative_duration = BTreeMap::<String, f64>::new();
    let mut tentative_distance = BTreeMap::<String, f64>::new();
    let mut predecessors = BTreeMap::<String, DurationPredecessor>::new();
    let mut unvisited = node_names;

    for node_name in &unvisited {
        tentative_duration.insert(node_name.clone(), f64::INFINITY);
        tentative_distance.insert(node_name.clone(), f64::INFINITY);
    }

    tentative_duration.insert(origin.name().to_owned(), 0.0);
    tentative_distance.insert(origin.name().to_owned(), 0.0);

    while !unvisited.is_empty() {
        let current_name = unvisited
            .iter()
            .min_by(|left, right| {
                let left_duration = tentative_duration
                    .get(*left)
                    .copied()
                    .unwrap_or(f64::INFINITY);

                let right_duration = tentative_duration
                    .get(*right)
                    .copied()
                    .unwrap_or(f64::INFINITY);

                let left_distance = tentative_distance
                    .get(*left)
                    .copied()
                    .unwrap_or(f64::INFINITY);

                let right_distance = tentative_distance
                    .get(*right)
                    .copied()
                    .unwrap_or(f64::INFINITY);

                left_duration
                    .total_cmp(&right_duration)
                    .then_with(|| left_distance.total_cmp(&right_distance))
                    .then_with(|| left.cmp(right))
            })
            .cloned()
            .expect("unvisited set is non-empty");

        let current_duration = tentative_duration
            .get(&current_name)
            .copied()
            .unwrap_or(f64::INFINITY);

        if !current_duration.is_finite() {
            break;
        }

        if current_name == destination.name() {
            break;
        }

        unvisited.remove(&current_name);

        let current_distance = tentative_distance
            .get(&current_name)
            .copied()
            .unwrap_or(f64::INFINITY);

        for edge in edges.iter().filter(|edge| edge.from.name() == current_name) {
            if !unvisited.contains(edge.to.name()) {
                continue;
            }

            let candidate_duration =
                current_duration + edge.travel_duration.get();

            if candidate_duration > maximum_duration_seconds {
                continue;
            }

            let candidate_distance =
                current_distance + edge.distance.get();

            let known_duration = tentative_duration
                .get(edge.to.name())
                .copied()
                .unwrap_or(f64::INFINITY);

            let known_distance = tentative_distance
                .get(edge.to.name())
                .copied()
                .unwrap_or(f64::INFINITY);

            let replaces_current = candidate_duration < known_duration
                || (candidate_duration == known_duration
                    && candidate_distance < known_distance)
                || (candidate_duration == known_duration
                    && candidate_distance == known_distance
                    && predecessor_is_lexicographically_smaller(
                        &current_name,
                        edge,
                        predecessors.get(edge.to.name()),
                    ));

            if replaces_current {
                tentative_duration.insert(edge.to.name().to_owned(), candidate_duration);
                tentative_distance.insert(edge.to.name().to_owned(), candidate_distance);
                predecessors.insert(
                    edge.to.name().to_owned(),
                    DurationPredecessor {
                        previous_node: edge.from.clone(),
                        edge_name: edge.name.clone(),
                    },
                );
            }
        }
    }

    let final_duration = tentative_duration
        .get(destination.name())
        .copied()
        .unwrap_or(f64::INFINITY);

    if !final_duration.is_finite() {
        return Err(PopmathError::InfeasibleConstraints {
            reason: "no verified accessible route connects origin to destination within the declared maximum duration",
        });
    }

    let final_distance = tentative_distance
        .get(destination.name())
        .copied()
        .unwrap_or(f64::INFINITY);

    let (nodes, edge_names) = reconstruct_duration_route(
        origin,
        destination,
        &predecessors,
    )?;

    Ok(DurationRoute {
        nodes,
        edge_names,
        total_distance_meters: final_distance,
        total_duration_seconds: final_duration,
    })
}

#[derive(Clone, Debug, PartialEq)]
struct DurationPredecessor {
    previous_node: NetworkNode,
    edge_name: String,
}

fn predecessor_is_lexicographically_smaller(
    current_name: &str,
    candidate_edge: &NetworkEdge,
    existing: Option<&DurationPredecessor>,
) -> bool {
    let Some(existing) = existing else {
        return true;
    };

    current_name < existing.previous_node.name()
        || (current_name == existing.previous_node.name()
            && candidate_edge.name < existing.edge_name)
}

fn reconstruct_duration_route(
    origin: &NetworkNode,
    destination: &NetworkNode,
    predecessors: &BTreeMap<String, DurationPredecessor>,
) -> PopmathResult<(Vec<NetworkNode>, Vec<String>)> {
    let mut reverse_nodes = vec![destination.clone()];
    let mut reverse_edges = Vec::new();
    let mut current = destination.clone();

    while current != *origin {
        let predecessor = predecessors.get(current.name()).ok_or(
            PopmathError::NumericalInstability {
                component: "accessible_route_predecessor_chain",
            },
        )?;

        reverse_edges.push(predecessor.edge_name.clone());
        current = predecessor.previous_node.clone();
        reverse_nodes.push(current.clone());
    }

    reverse_nodes.reverse();
    reverse_edges.reverse();

    Ok((reverse_nodes, reverse_edges))
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AggregateCoverageInput {
    pub total_weight: PopulationWeight,
    pub served_weight: PopulationWeight,
    pub transfer_reliability: UnitInterval,
    pub maximum_duration: DurationSeconds,
    pub modeled_duration: DurationSeconds,
    pub maximum_grade: UnitInterval,
    pub allowed_grade: UnitInterval,
    pub minimum_clear_width_m: PositiveF64,
    pub required_clear_width_m: PositiveF64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AggregateCoverageResult {
    pub coverage: UnitInterval,
    pub route_conditions_met: bool,
    pub access_gap_weight: PopulationWeight,
}

pub fn calculate_aggregate_coverage(
    input: AggregateCoverageInput,
) -> PopmathResult<AggregateCoverageResult> {
    let route_conditions_met = input.modeled_duration.get() <= input.maximum_duration.get()
        && input.maximum_grade.get() <= input.allowed_grade.get()
        && input.minimum_clear_width_m.get() >= input.required_clear_width_m.get();

    let raw_coverage = if input.total_weight.get() == 0.0 || !route_conditions_met {
        0.0
    } else {
        (input.served_weight.get() / input.total_weight.get())
            * input.transfer_reliability.get()
    };

    let coverage = UnitInterval::new(raw_coverage, "aggregate_coverage")?;
    let access_gap_weight =
        PopulationWeight::new(input.total_weight.get() * (1.0 - coverage.get()))?;

    Ok(AggregateCoverageResult {
        coverage,
        route_conditions_met,
        access_gap_weight,
    })
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WattHoursPerMeter {
    value: NonNegativeF64,
}

impl WattHoursPerMeter {
    #[must_use]
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    #[must_use]
    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WattHoursPerMeterGrade {
    value: NonNegativeF64,
}

impl WattHoursPerMeterGrade {
    #[must_use]
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    #[must_use]
    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WattHoursPerSecond {
    value: NonNegativeF64,
}

impl WattHoursPerSecond {
    #[must_use]
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    #[must_use]
    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct EnergyAwareNetworkEdge {
    pub name: String,
    pub from: NetworkNode,
    pub to: NetworkNode,
    pub distance: DistanceM,
    pub accessibility: AccessibilityState,
    pub open: bool,
    pub slope_grade: f64,
    pub surface_resistance_factor: UnitInterval,
    pub expected_recharge_seconds: NonNegativeF64,
    pub charging_continuity: Option<ContinuityAssessment>,
}

impl EnergyAwareNetworkEdge {
    pub fn validate(&self) -> PopmathResult<()> {
        if self.name.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "energy_aware_network_edge_name",
            });
        }

        if self.from == self.to {
            return Err(PopmathError::InvalidScenario {
                field: "energy_aware_network_edge_endpoints",
            });
        }

        if !self.slope_grade.is_finite() {
            return Err(PopmathError::NonFiniteValue);
        }

        Ok(())
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PoweredMobilityEnergyModel {
    pub base_energy_per_meter: WattHoursPerMeter,
    pub uphill_energy_per_meter_grade: WattHoursPerMeterGrade,
    pub surface_energy_per_meter: WattHoursPerMeter,
    pub recharge_time_penalty: WattHoursPerSecond,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ChargingContinuityRequirement {
    pub minimum_availability_ratio: UnitInterval,
    pub maximum_gap_seconds: NonNegativeF64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct EnergyAwareRouteResult {
    pub nodes: Vec<NetworkNode>,
    pub edge_names: Vec<String>,
    pub total_distance: DistanceM,
    pub total_energy_wh: NonNegativeF64,
    pub recharge_penalty_wh: NonNegativeF64,
    pub total_cost_wh: NonNegativeF64,
    pub charging_continuity_satisfied: bool,
}

pub fn calculate_power_efficient_accessible_route(
    edges: &[EnergyAwareNetworkEdge],
    origin: &NetworkNode,
    destination: &NetworkNode,
    energy_model: PoweredMobilityEnergyModel,
    charging_requirement: ChargingContinuityRequirement,
) -> PopmathResult<EnergyAwareRouteResult> {
    if edges.is_empty() {
        return Err(PopmathError::InfeasibleConstraints {
            reason: "no energy-aware network edges were supplied",
        });
    }

    for edge in edges {
        edge.validate()?;
    }

    if origin == destination {
        return Ok(EnergyAwareRouteResult {
            nodes: vec![origin.clone()],
            edge_names: Vec::new(),
            total_distance: DistanceM::new(0.0)?,
            total_energy_wh: NonNegativeF64::new(0.0)?,
            recharge_penalty_wh: NonNegativeF64::new(0.0)?,
            total_cost_wh: NonNegativeF64::new(0.0)?,
            charging_continuity_satisfied: true,
        });
    }

    let eligible_edges = edges
        .iter()
        .filter(|edge| {
            edge.open
                && edge.accessibility == AccessibilityState::VerifiedAccessible
                && edge_satisfies_charging_requirement(
                    edge,
                    charging_requirement,
                )
        })
        .collect::<Vec<_>>();

    if eligible_edges.is_empty() {
        return Err(PopmathError::InfeasibleConstraints {
            reason: "no verified accessible edges satisfy the declared charging continuity requirement",
        });
    }

    let route = shortest_energy_route(
        &eligible_edges,
        origin,
        destination,
        energy_model,
    )?;

    Ok(EnergyAwareRouteResult {
        nodes: route.nodes,
        edge_names: route.edge_names,
        total_distance: DistanceM::new(route.total_distance_meters)?,
        total_energy_wh: NonNegativeF64::new(route.total_energy_wh)?,
        recharge_penalty_wh: NonNegativeF64::new(route.total_recharge_penalty_wh)?,
        total_cost_wh: NonNegativeF64::new(route.total_cost_wh)?,
        charging_continuity_satisfied: true,
    })
}

fn edge_satisfies_charging_requirement(
    edge: &EnergyAwareNetworkEdge,
    requirement: ChargingContinuityRequirement,
) -> bool {
    let Some(continuity) = &edge.charging_continuity else {
        return false;
    };

    continuity.availability_ratio.value()
        >= requirement.minimum_availability_ratio.value()
        && continuity.longest_gap_seconds.value()
            <= requirement.maximum_gap_seconds.value()
}

#[derive(Clone, Debug, PartialEq)]
struct EnergyRoute {
    nodes: Vec<NetworkNode>,
    edge_names: Vec<String>,
    total_distance_meters: f64,
    total_energy_wh: f64,
    total_recharge_penalty_wh: f64,
    total_cost_wh: f64,
}

fn shortest_energy_route(
    edges: &[&EnergyAwareNetworkEdge],
    origin: &NetworkNode,
    destination: &NetworkNode,
    energy_model: PoweredMobilityEnergyModel,
) -> PopmathResult<EnergyRoute> {
    let mut node_names = BTreeSet::new();

    node_names.insert(origin.name().to_owned());
    node_names.insert(destination.name().to_owned());

    for edge in edges {
        node_names.insert(edge.from.name().to_owned());
        node_names.insert(edge.to.name().to_owned());
    }

    let mut tentative_cost = BTreeMap::<String, f64>::new();
    let mut tentative_energy = BTreeMap::<String, f64>::new();
    let mut tentative_recharge_penalty = BTreeMap::<String, f64>::new();
    let mut tentative_distance = BTreeMap::<String, f64>::new();
    let mut predecessors = BTreeMap::<String, EnergyPredecessor>::new();
    let mut unvisited = node_names;

    for node_name in &unvisited {
        tentative_cost.insert(node_name.clone(), f64::INFINITY);
        tentative_energy.insert(node_name.clone(), f64::INFINITY);
        tentative_recharge_penalty.insert(node_name.clone(), f64::INFINITY);
        tentative_distance.insert(node_name.clone(), f64::INFINITY);
    }

    tentative_cost.insert(origin.name().to_owned(), 0.0);
    tentative_energy.insert(origin.name().to_owned(), 0.0);
    tentative_recharge_penalty.insert(origin.name().to_owned(), 0.0);
    tentative_distance.insert(origin.name().to_owned(), 0.0);

    while !unvisited.is_empty() {
        let current_name = unvisited
            .iter()
            .min_by(|left, right| {
                let left_cost = tentative_cost
                    .get(*left)
                    .copied()
                    .unwrap_or(f64::INFINITY);

                let right_cost = tentative_cost
                    .get(*right)
                    .copied()
                    .unwrap_or(f64::INFINITY);

                let left_distance = tentative_distance
                    .get(*left)
                    .copied()
                    .unwrap_or(f64::INFINITY);

                let right_distance = tentative_distance
                    .get(*right)
                    .copied()
                    .unwrap_or(f64::INFINITY);

                left_cost
                    .total_cmp(&right_cost)
                    .then_with(|| left_distance.total_cmp(&right_distance))
                    .then_with(|| left.cmp(right))
            })
            .cloned()
            .expect("unvisited set is non-empty");

        let current_cost = tentative_cost
            .get(&current_name)
            .copied()
            .unwrap_or(f64::INFINITY);

        if !current_cost.is_finite() {
            break;
        }

        if current_name == destination.name() {
            break;
        }

        unvisited.remove(&current_name);

        let current_energy = tentative_energy
            .get(&current_name)
            .copied()
            .unwrap_or(f64::INFINITY);

        let current_recharge_penalty = tentative_recharge_penalty
            .get(&current_name)
            .copied()
            .unwrap_or(f64::INFINITY);

        let current_distance = tentative_distance
            .get(&current_name)
            .copied()
            .unwrap_or(f64::INFINITY);

        for edge in edges.iter().filter(|edge| edge.from.name() == current_name) {
            if !unvisited.contains(edge.to.name()) {
                continue;
            }

            let edge_energy = calculate_edge_energy(edge, energy_model)?;
            let edge_recharge_penalty = edge.expected_recharge_seconds.value()
                * energy_model.recharge_time_penalty.value();

            let candidate_cost =
                current_cost + edge_energy + edge_recharge_penalty;

            let candidate_energy = current_energy + edge_energy;
            let candidate_recharge_penalty =
                current_recharge_penalty + edge_recharge_penalty;
            let candidate_distance = current_distance + edge.distance.get();

            let known_cost = tentative_cost
                .get(edge.to.name())
                .copied()
                .unwrap_or(f64::INFINITY);

            let known_distance = tentative_distance
                .get(edge.to.name())
                .copied()
                .unwrap_or(f64::INFINITY);

            let replaces_current = candidate_cost < known_cost
                || (candidate_cost == known_cost
                    && candidate_distance < known_distance)
                || (candidate_cost == known_cost
                    && candidate_distance == known_distance
                    && energy_predecessor_is_lexicographically_smaller(
                        &current_name,
                        edge,
                        predecessors.get(edge.to.name()),
                    ));

            if replaces_current {
                tentative_cost.insert(edge.to.name().to_owned(), candidate_cost);
                tentative_energy.insert(edge.to.name().to_owned(), candidate_energy);
                tentative_recharge_penalty.insert(
                    edge.to.name().to_owned(),
                    candidate_recharge_penalty,
                );
                tentative_distance.insert(
                    edge.to.name().to_owned(),
                    candidate_distance,
                );
                predecessors.insert(
                    edge.to.name().to_owned(),
                    EnergyPredecessor {
                        previous_node: edge.from.clone(),
                        edge_name: edge.name.clone(),
                    },
                );
            }
        }
    }

    let total_cost_wh = tentative_cost
        .get(destination.name())
        .copied()
        .unwrap_or(f64::INFINITY);

    if !total_cost_wh.is_finite() {
        return Err(PopmathError::InfeasibleConstraints {
            reason: "no verified accessible route satisfies the declared charging continuity requirement",
        });
    }

    let (nodes, edge_names) = reconstruct_energy_route(
        origin,
        destination,
        &predecessors,
    )?;

    Ok(EnergyRoute {
        nodes,
        edge_names,
        total_distance_meters: tentative_distance
            .get(destination.name())
            .copied()
            .unwrap_or(0.0),
        total_energy_wh: tentative_energy
            .get(destination.name())
            .copied()
            .unwrap_or(0.0),
        total_recharge_penalty_wh: tentative_recharge_penalty
            .get(destination.name())
            .copied()
            .unwrap_or(0.0),
        total_cost_wh,
    })
}

#[derive(Clone, Debug, PartialEq)]
struct EnergyPredecessor {
    previous_node: NetworkNode,
    edge_name: String,
}

fn energy_predecessor_is_lexicographically_smaller(
    current_name: &str,
    candidate_edge: &EnergyAwareNetworkEdge,
    existing: Option<&EnergyPredecessor>,
) -> bool {
    let Some(existing) = existing else {
        return true;
    };

    current_name < existing.previous_node.name()
        || (current_name == existing.previous_node.name()
            && candidate_edge.name < existing.edge_name)
}

fn calculate_edge_energy(
    edge: &EnergyAwareNetworkEdge,
    model: PoweredMobilityEnergyModel,
) -> PopmathResult<f64> {
    if !edge.slope_grade.is_finite() {
        return Err(PopmathError::NonFiniteValue);
    }

    let uphill_grade = edge.slope_grade.max(0.0);

    let energy_per_meter = model.base_energy_per_meter.value()
        + (model.uphill_energy_per_meter_grade.value() * uphill_grade)
        + (model.surface_energy_per_meter.value()
            * edge.surface_resistance_factor.value());

    let energy = edge.distance.get() * energy_per_meter;

    NonNegativeF64::new(energy).map(|value| value.value())
}

fn reconstruct_energy_route(
    origin: &NetworkNode,
    destination: &NetworkNode,
    predecessors: &BTreeMap<String, EnergyPredecessor>,
) -> PopmathResult<(Vec<NetworkNode>, Vec<String>)> {
    let mut reverse_nodes = vec![destination.clone()];
    let mut reverse_edges = Vec::new();
    let mut current = destination.clone();

    while current != *origin {
        let predecessor = predecessors.get(current.name()).ok_or(
            PopmathError::NumericalInstability {
                component: "energy_aware_route_predecessor_chain",
            },
        )?;

        reverse_edges.push(predecessor.edge_name.clone());
        current = predecessor.previous_node.clone();
        reverse_nodes.push(current.clone());
    }

    reverse_nodes.reverse();
    reverse_edges.reverse();

    Ok((reverse_nodes, reverse_edges))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::continuity::ContinuityStatus;

    fn node(name: &str) -> NetworkNode {
        NetworkNode::new(name).expect("valid node")
    }

    fn continuity(
        availability_ratio: f64,
        longest_gap_seconds: f64,
    ) -> ContinuityAssessment {
        ContinuityAssessment {
            availability_ratio: UnitInterval::new(
                availability_ratio,
                "availability_ratio",
            )
            .expect("valid availability ratio"),
            verification_ratio: UnitInterval::new(
                1.0,
                "verification_ratio",
            )
            .expect("valid verification ratio"),
            unmet_seconds: NonNegativeF64::new(0.0)
                .expect("valid unmet seconds"),
            longest_gap_seconds: NonNegativeF64::new(longest_gap_seconds)
                .expect("valid maximum gap"),
            overall_status: ContinuityStatus::Met,
            explanation: String::from("Synthetic continuity fixture."),
        }
    }

    #[test]
    fn shortest_accessible_route_uses_verified_path() {
        let origin = node("origin");
        let midpoint = node("midpoint");
        let destination = node("destination");

        let result = calculate_accessible_route(&AccessibleRouteInput {
            origin: origin.clone(),
            destination: destination.clone(),
            travel_mode: TravelMode::Walking,
            maximum_duration: DurationSeconds::new(900.0)
                .expect("valid duration"),
            edges: vec![
                NetworkEdge {
                    name: String::from("inaccessible-shortcut"),
                    from: origin.clone(),
                    to: destination.clone(),
                    distance: DistanceM::new(100.0)
                        .expect("valid distance"),
                    travel_duration: DurationSeconds::new(120.0)
                        .expect("valid duration"),
                    travel_mode: TravelMode::Walking,
                    open: true,
                    accessibility: AccessibilityState::Inaccessible,
                },
                NetworkEdge {
                    name: String::from("accessible-segment-one"),
                    from: origin.clone(),
                    to: midpoint.clone(),
                    distance: DistanceM::new(180.0)
                        .expect("valid distance"),
                    travel_duration: DurationSeconds::new(300.0)
                        .expect("valid duration"),
                    travel_mode: TravelMode::Walking,
                    open: true,
                    accessibility: AccessibilityState::VerifiedAccessible,
                },
                NetworkEdge {
                    name: String::from("accessible-segment-two"),
                    from: midpoint,
                    to: destination,
                    distance: DistanceM::new(180.0)
                        .expect("valid distance"),
                    travel_duration: DurationSeconds::new(300.0)
                        .expect("valid duration"),
                    travel_mode: TravelMode::Walking,
                    open: true,
                    accessibility: AccessibilityState::VerifiedAccessible,
                },
            ],
        })
        .expect("accessible route should exist");

        assert_eq!(
            result.edge_names,
            vec![
                String::from("accessible-segment-one"),
                String::from("accessible-segment-two"),
            ]
        );
        assert_eq!(result.total_distance.get(), 360.0);
        assert_eq!(result.total_duration.get(), 600.0);
        assert!(result.full_path_accessible);
    }

    #[test]
    fn accessible_route_uses_global_shortest_path() {
        let origin = node("origin");
        let first = node("first");
        let second = node("second");
        let destination = node("destination");

        let result = calculate_accessible_route(&AccessibleRouteInput {
            origin: origin.clone(),
            destination: destination.clone(),
            travel_mode: TravelMode::Walking,
            maximum_duration: DurationSeconds::new(1_000.0)
                .expect("valid duration"),
            edges: vec![
                NetworkEdge {
                    name: String::from("greedy-first"),
                    from: origin.clone(),
                    to: first.clone(),
                    distance: DistanceM::new(10.0)
                        .expect("valid distance"),
                    travel_duration: DurationSeconds::new(10.0)
                        .expect("valid duration"),
                    travel_mode: TravelMode::Walking,
                    open: true,
                    accessibility: AccessibilityState::VerifiedAccessible,
                },
                NetworkEdge {
                    name: String::from("greedy-expensive-finish"),
                    from: first,
                    to: destination.clone(),
                    distance: DistanceM::new(1_000.0)
                        .expect("valid distance"),
                    travel_duration: DurationSeconds::new(900.0)
                        .expect("valid duration"),
                    travel_mode: TravelMode::Walking,
                    open: true,
                    accessibility: AccessibilityState::VerifiedAccessible,
                },
                NetworkEdge {
                    name: String::from("globally-shorter-first"),
                    from: origin,
                    to: second.clone(),
                    distance: DistanceM::new(20.0)
                        .expect("valid distance"),
                    travel_duration: DurationSeconds::new(100.0)
                        .expect("valid duration"),
                    travel_mode: TravelMode::Walking,
                    open: true,
                    accessibility: AccessibilityState::VerifiedAccessible,
                },
                NetworkEdge {
                    name: String::from("globally-shorter-finish"),
                    from: second,
                    to: destination,
                    distance: DistanceM::new(20.0)
                        .expect("valid distance"),
                    travel_duration: DurationSeconds::new(100.0)
                        .expect("valid duration"),
                    travel_mode: TravelMode::Walking,
                    open: true,
                    accessibility: AccessibilityState::VerifiedAccessible,
                },
            ],
        })
        .expect("global route should exist");

        assert_eq!(result.total_duration.get(), 200.0);
        assert_eq!(
            result.edge_names,
            vec![
                String::from("globally-shorter-first"),
                String::from("globally-shorter-finish"),
            ]
        );
    }

    #[test]
    fn unknown_accessibility_is_not_accepted() {
        let origin = node("origin");
        let destination = node("destination");

        let result = calculate_accessible_route(&AccessibleRouteInput {
            origin: origin.clone(),
            destination: destination.clone(),
            travel_mode: TravelMode::Walking,
            maximum_duration: DurationSeconds::new(900.0)
                .expect("valid duration"),
            edges: vec![NetworkEdge {
                name: String::from("unverified-segment"),
                from: origin,
                to: destination,
                distance: DistanceM::new(100.0)
                    .expect("valid distance"),
                travel_duration: DurationSeconds::new(120.0)
                    .expect("valid duration"),
                travel_mode: TravelMode::Walking,
                open: true,
                accessibility: AccessibilityState::Unknown,
            }],
        });

        assert!(matches!(
            result,
            Err(PopmathError::InfeasibleConstraints { .. })
        ));
    }

    #[test]
    fn aggregate_coverage_reports_access_gap() {
        let result = calculate_aggregate_coverage(AggregateCoverageInput {
            total_weight: PopulationWeight::new(100.0)
                .expect("valid total weight"),
            served_weight: PopulationWeight::new(80.0)
                .expect("valid served weight"),
            transfer_reliability: UnitInterval::new(
                0.9,
                "transfer_reliability",
            )
            .expect("valid reliability"),
            maximum_duration: DurationSeconds::new(900.0)
                .expect("valid duration"),
            modeled_duration: DurationSeconds::new(600.0)
                .expect("valid duration"),
            maximum_grade: UnitInterval::new(0.04, "maximum_grade")
                .expect("valid grade"),
            allowed_grade: UnitInterval::new(0.05, "allowed_grade")
                .expect("valid grade"),
            minimum_clear_width_m: PositiveF64::new(1.5)
                .expect("valid width"),
            required_clear_width_m: PositiveF64::new(1.2)
                .expect("valid width"),
        })
        .expect("coverage should calculate");

        assert_eq!(result.coverage.get(), 0.72);
        assert_eq!(result.access_gap_weight.get(), 28.0);
        assert!(result.route_conditions_met);
    }

    #[test]
    fn energy_aware_route_preserves_accessibility_and_charging_requirements() {
        let origin = node("origin");
        let midpoint = node("midpoint");
        let destination = node("destination");

        let result = calculate_power_efficient_accessible_route(
            &[
                EnergyAwareNetworkEdge {
                    name: String::from("accessible-segment-one"),
                    from: origin.clone(),
                    to: midpoint.clone(),
                    distance: DistanceM::new(100.0)
                        .expect("valid distance"),
                    accessibility: AccessibilityState::VerifiedAccessible,
                    open: true,
                    slope_grade: 0.01,
                    surface_resistance_factor: UnitInterval::new(
                        0.1,
                        "surface_resistance_factor",
                    )
                    .expect("valid surface factor"),
                    expected_recharge_seconds: NonNegativeF64::new(0.0)
                        .expect("valid recharge duration"),
                    charging_continuity: Some(continuity(1.0, 0.0)),
                },
                EnergyAwareNetworkEdge {
                    name: String::from("accessible-segment-two"),
                    from: midpoint,
                    to: destination.clone(),
                    distance: DistanceM::new(100.0)
                        .expect("valid distance"),
                    accessibility: AccessibilityState::VerifiedAccessible,
                    open: true,
                    slope_grade: 0.02,
                    surface_resistance_factor: UnitInterval::new(
                        0.2,
                        "surface_resistance_factor",
                    )
                    .expect("valid surface factor"),
                    expected_recharge_seconds: NonNegativeF64::new(0.0)
                        .expect("valid recharge duration"),
                    charging_continuity: Some(continuity(1.0, 0.0)),
                },
                EnergyAwareNetworkEdge {
                    name: String::from("inaccessible-shortcut"),
                    from: origin.clone(),
                    to: destination,
                    distance: DistanceM::new(10.0)
                        .expect("valid distance"),
                    accessibility: AccessibilityState::Inaccessible,
                    open: true,
                    slope_grade: 0.0,
                    surface_resistance_factor: UnitInterval::new(
                        0.0,
                        "surface_resistance_factor",
                    )
                    .expect("valid surface factor"),
                    expected_recharge_seconds: NonNegativeF64::new(0.0)
                        .expect("valid recharge duration"),
                    charging_continuity: Some(continuity(1.0, 0.0)),
                },
            ],
            &origin,
            &node("destination"),
            PoweredMobilityEnergyModel {
                base_energy_per_meter: WattHoursPerMeter::new(
                    NonNegativeF64::new(0.02).expect("valid base energy"),
                ),
                uphill_energy_per_meter_grade: WattHoursPerMeterGrade::new(
                    NonNegativeF64::new(0.1).expect("valid uphill energy"),
                ),
                surface_energy_per_meter: WattHoursPerMeter::new(
                    NonNegativeF64::new(0.02).expect("valid surface energy"),
                ),
                recharge_time_penalty: WattHoursPerSecond::new(
                    NonNegativeF64::new(0.001).expect("valid time penalty"),
                ),
            },
            ChargingContinuityRequirement {
                minimum_availability_ratio: UnitInterval::new(
                    0.99,
                    "charging_availability",
                )
                .expect("valid continuity threshold"),
                maximum_gap_seconds: NonNegativeF64::new(600.0)
                    .expect("valid maximum gap"),
            },
        )
        .expect("energy-aware route should exist");

        assert_eq!(
            result.edge_names,
            vec![
                String::from("accessible-segment-one"),
                String::from("accessible-segment-two"),
            ]
        );
        assert!(result.total_energy_wh.value() > 0.0);
        assert!(result.charging_continuity_satisfied);
    }

    #[test]
    fn energy_aware_route_rejects_missing_charging_evidence() {
        let origin = node("origin");
        let destination = node("destination");

        let result = calculate_power_efficient_accessible_route(
            &[EnergyAwareNetworkEdge {
                name: String::from("accessible-but-unverified-charging"),
                from: origin.clone(),
                to: destination.clone(),
                distance: DistanceM::new(100.0)
                    .expect("valid distance"),
                accessibility: AccessibilityState::VerifiedAccessible,
                open: true,
                slope_grade: 0.0,
                surface_resistance_factor: UnitInterval::new(
                    0.0,
                    "surface_resistance_factor",
                )
                .expect("valid surface factor"),
                expected_recharge_seconds: NonNegativeF64::new(0.0)
                    .expect("valid recharge duration"),
                charging_continuity: None,
            }],
            &origin,
            &destination,
            PoweredMobilityEnergyModel {
                base_energy_per_meter: WattHoursPerMeter::new(
                    NonNegativeF64::new(0.02).expect("valid base energy"),
                ),
                uphill_energy_per_meter_grade: WattHoursPerMeterGrade::new(
                    NonNegativeF64::new(0.1).expect("valid uphill energy"),
                ),
                surface_energy_per_meter: WattHoursPerMeter::new(
                    NonNegativeF64::new(0.02).expect("valid surface energy"),
                ),
                recharge_time_penalty: WattHoursPerSecond::new(
                    NonNegativeF64::new(0.001).expect("valid time penalty"),
                ),
            },
            ChargingContinuityRequirement {
                minimum_availability_ratio: UnitInterval::new(
                    0.99,
                    "charging_availability",
                )
                .expect("valid continuity threshold"),
                maximum_gap_seconds: NonNegativeF64::new(600.0)
                    .expect("valid maximum gap"),
            },
        );

        assert!(matches!(
            result,
            Err(PopmathError::InfeasibleConstraints { .. })
        ));
    }
}
