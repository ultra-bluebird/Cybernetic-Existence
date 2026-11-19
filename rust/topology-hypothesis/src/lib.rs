#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TopologyMode {
    SimulationOnly,
    ResearchPlanningOnly,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NodeClass {
    SensingHypothesis,
    ProcessingHypothesis,
    ArbitrationHypothesis,
    EvidenceLedger,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PermittedEffect {
    Observe,
    Derive,
    Simulate,
    Summarize,
    Propose,
    Log,
    RequestReview,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResourceBudget {
    pub max_compute_joules: u64,
    pub max_storage_bytes: u64,
    pub max_communications_bytes: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TopologyNode {
    pub node_id: String,
    pub node_class: NodeClass,
    pub authority: String,
    pub permitted_effects: BTreeSet<PermittedEffect>,
    pub input_data_class: String,
    pub output_data_class: String,
    pub output_disclosure_class: String,
    pub resource_budget: ResourceBudget,
    pub status: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TopologyEdge {
    pub edge_id: String,
    pub from_node_id: String,
    pub to_node_id: String,
    pub data_class: String,
    pub purpose: String,
    pub disclosure_class: String,
    pub permitted_effect: PermittedEffect,
    pub consent_scope_required: bool,
    pub max_latency_millis: u64,
    pub max_communications_bytes: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TopologyHypothesis {
    pub schema_version: String,
    pub topology_id: String,
    pub mode: TopologyMode,
    pub non_actuation_required: bool,
    pub nodes: Vec<TopologyNode>,
    pub edges: Vec<TopologyEdge>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TopologyValidationError {
    UnsupportedSchemaVersion,
    EmptyTopologyId,
    ActuationNotProhibited,
    DuplicateNodeId,
    DuplicateEdgeId,
    UnknownEdgeNode,
    EdgeEffectNotPermittedBySource,
    NonSimulationModeNotAllowed,
    EmptyRequiredField,
}

impl TopologyHypothesis {
    pub fn validate(&self) -> Result<(), TopologyValidationError> {
        if self.schema_version != "TopologyHypothesis.v1" {
            return Err(TopologyValidationError::UnsupportedSchemaVersion);
        }

        if self.topology_id.trim().is_empty() {
            return Err(TopologyValidationError::EmptyTopologyId);
        }

        if self.mode != TopologyMode::SimulationOnly {
            return Err(TopologyValidationError::NonSimulationModeNotAllowed);
        }

        if !self.non_actuation_required {
            return Err(TopologyValidationError::ActuationNotProhibited);
        }

        let mut node_map = BTreeMap::new();

        for node in &self.nodes {
            require_non_empty(&node.node_id)?;
            require_non_empty(&node.authority)?;
            require_non_empty(&node.input_data_class)?;
            require_non_empty(&node.output_data_class)?;
            require_non_empty(&node.output_disclosure_class)?;
            require_non_empty(&node.status)?;

            if node_map.insert(node.node_id.clone(), node).is_some() {
                return Err(TopologyValidationError::DuplicateNodeId);
            }
        }

        let mut edge_ids = BTreeSet::new();

        for edge in &self.edges {
            require_non_empty(&edge.edge_id)?;
            require_non_empty(&edge.from_node_id)?;
            require_non_empty(&edge.to_node_id)?;
            require_non_empty(&edge.data_class)?;
            require_non_empty(&edge.purpose)?;
            require_non_empty(&edge.disclosure_class)?;

            if !edge_ids.insert(edge.edge_id.clone()) {
                return Err(TopologyValidationError::DuplicateEdgeId);
            }

            let source = node_map
                .get(&edge.from_node_id)
                .ok_or(TopologyValidationError::UnknownEdgeNode)?;

            if !node_map.contains_key(&edge.to_node_id) {
                return Err(TopologyValidationError::UnknownEdgeNode);
            }

            if !source.permitted_effects.contains(&edge.permitted_effect) {
                return Err(TopologyValidationError::EdgeEffectNotPermittedBySource);
            }
        }

        Ok(())
    }
}

fn require_non_empty(value: &str) -> Result<(), TopologyValidationError> {
    if value.trim().is_empty() {
        Err(TopologyValidationError::EmptyRequiredField)
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn node(id: &str, effects: &[PermittedEffect]) -> TopologyNode {
        TopologyNode {
            node_id: id.to_owned(),
            node_class: NodeClass::SensingHypothesis,
            authority: "local_observe_and_derive".to_owned(),
            permitted_effects: effects.iter().cloned().collect(),
            input_data_class: "authorized_local_signal_summary".to_owned(),
            output_data_class: "minimized_derived_feature".to_owned(),
            output_disclosure_class: "local_or_aggregate_only".to_owned(),
            resource_budget: ResourceBudget {
                max_compute_joules: 1_000,
                max_storage_bytes: 1_000_000,
                max_communications_bytes: 100_000,
            },
            status: "proposed".to_owned(),
        }
    }

    #[test]
    fn accepts_a_non_actuating_simulation_topology() {
        let topology = TopologyHypothesis {
            schema_version: "TopologyHypothesis.v1".to_owned(),
            topology_id: "simulation-topology".to_owned(),
            mode: TopologyMode::SimulationOnly,
            non_actuation_required: true,
            nodes: vec![
                node("node-a", &[PermittedEffect::Observe, PermittedEffect::Summarize]),
                node("hub-a", &[PermittedEffect::Summarize, PermittedEffect::RequestReview]),
            ],
            edges: vec![TopologyEdge {
                edge_id: "edge-a-to-hub".to_owned(),
                from_node_id: "node-a".to_owned(),
                to_node_id: "hub-a".to_owned(),
                data_class: "minimized_derived_feature".to_owned(),
                purpose: "authorized_research_topology_analysis".to_owned(),
                disclosure_class: "aggregate_or_hash_only".to_owned(),
                permitted_effect: PermittedEffect::Summarize,
                consent_scope_required: true,
                max_latency_millis: 1_000,
                max_communications_bytes: 100_000,
            }],
        };

        assert_eq!(topology.validate(), Ok(()));
    }

    #[test]
    fn rejects_topology_without_non_actuation_requirement() {
        let topology = TopologyHypothesis {
            schema_version: "TopologyHypothesis.v1".to_owned(),
            topology_id: "invalid-topology".to_owned(),
            mode: TopologyMode::SimulationOnly,
            non_actuation_required: false,
            nodes: vec![],
            edges: vec![],
        };

        assert_eq!(
            topology.validate(),
            Err(TopologyValidationError::ActuationNotProhibited)
        );
    }
}
