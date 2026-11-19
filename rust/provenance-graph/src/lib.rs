#![forbid(unsafe_code)]

use std::collections::{BTreeMap, BTreeSet, VecDeque};

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum AccessClass {
    Public,
    AggregateOnly,
    HashOnly,
    AuthorizedControlledAccess,
    RestrictedReference,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProvenanceNode {
    pub node_id: String,
    pub node_type: String,
    pub access_class: AccessClass,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProvenanceEdge {
    pub from_node_id: String,
    pub to_node_id: String,
    pub relation: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProvenanceGraph {
    pub graph_id: String,
    pub nodes: Vec<ProvenanceNode>,
    pub edges: Vec<ProvenanceEdge>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProvenanceError {
    EmptyGraphId,
    EmptyNodeId,
    DuplicateNodeId(String),
    UnknownEdgeNode(String),
    EmptyRelation,
    MissingNodeType(String),
    ClaimMissingEvidence(String),
    ClaimMissingResult(String),
    ResultMissingPredecessor {
        result_id: String,
        node_type: String,
    },
}

impl ProvenanceGraph {
    pub fn validate_required_paths(&self) -> Result<(), ProvenanceError> {
        if self.graph_id.trim().is_empty() {
            return Err(ProvenanceError::EmptyGraphId);
        }

        let nodes = self.node_map()?;
        let forward = adjacency(&self.edges, true)?;
        let reverse = adjacency(&self.edges, false)?;

        for required in [
            "manifest",
            "research_object",
            "claim",
            "evidence_manifest",
            "authorization_scope",
            "dataset_version",
            "feature_set",
            "software_asset",
            "sbom",
            "method_configuration",
            "execution_environment",
            "result_artifact",
            "result_record",
            "limitation",
            "review_event",
            "governance_decision",
        ] {
            if !nodes.values().any(|node| node.node_type == required) {
                return Err(ProvenanceError::MissingNodeType(required.to_owned()));
            }
        }

        for claim in nodes.values().filter(|node| node.node_type == "claim") {
            let reachable = reachable(&claim.node_id, &forward);

            if !reachable.iter().any(|node_id| {
                nodes
                    .get(node_id)
                    .is_some_and(|node| node.node_type == "evidence_manifest")
            }) {
                return Err(ProvenanceError::ClaimMissingEvidence(
                    claim.node_id.clone(),
                ));
            }

            if !reachable.iter().any(|node_id| {
                nodes
                    .get(node_id)
                    .is_some_and(|node| node.node_type == "result_record")
            }) {
                return Err(ProvenanceError::ClaimMissingResult(
                    claim.node_id.clone(),
                ));
            }
        }

        for result in nodes.values().filter(|node| node.node_type == "result_record") {
            let predecessors = reachable(&result.node_id, &reverse);

            for required in [
                "dataset_version",
                "method_configuration",
                "software_asset",
                "sbom",
                "execution_environment",
                "limitation",
                "review_event",
                "governance_decision",
            ] {
                if !predecessors.iter().any(|node_id| {
                    nodes
                        .get(node_id)
                        .is_some_and(|node| node.node_type == required)
                }) {
                    return Err(ProvenanceError::ResultMissingPredecessor {
                        result_id: result.node_id.clone(),
                        node_type: required.to_owned(),
                    });
                }
            }
        }

        Ok(())
    }

    fn node_map(&self) -> Result<BTreeMap<String, &ProvenanceNode>, ProvenanceError> {
        let mut nodes = BTreeMap::new();

        for node in &self.nodes {
            if node.node_id.trim().is_empty() {
                return Err(ProvenanceError::EmptyNodeId);
            }

            if nodes.insert(node.node_id.clone(), node).is_some() {
                return Err(ProvenanceError::DuplicateNodeId(node.node_id.clone()));
            }
        }

        for edge in &self.edges {
            if edge.relation.trim().is_empty() {
                return Err(ProvenanceError::EmptyRelation);
            }

            if !nodes.contains_key(&edge.from_node_id) {
                return Err(ProvenanceError::UnknownEdgeNode(
                    edge.from_node_id.clone(),
                ));
            }

            if !nodes.contains_key(&edge.to_node_id) {
                return Err(ProvenanceError::UnknownEdgeNode(
                    edge.to_node_id.clone(),
                ));
            }
        }

        Ok(nodes)
    }
}

fn adjacency(
    edges: &[ProvenanceEdge],
    forward: bool,
) -> Result<BTreeMap<String, BTreeSet<String>>, ProvenanceError> {
    let mut result = BTreeMap::new();

    for edge in edges {
        if edge.relation.trim().is_empty() {
            return Err(ProvenanceError::EmptyRelation);
        }

        let (from, to) = if forward {
            (&edge.from_node_id, &edge.to_node_id)
        } else {
            (&edge.to_node_id, &edge.from_node_id)
        };

        result.entry(from.clone()).or_insert_with(BTreeSet::new).insert(to.clone());
    }

    Ok(result)
}

fn reachable(
    start: &str,
    graph: &BTreeMap<String, BTreeSet<String>>,
) -> BTreeSet<String> {
    let mut seen = BTreeSet::new();
    let mut queue = VecDeque::from([start.to_owned()]);

    while let Some(current) = queue.pop_front() {
        if !seen.insert(current.clone()) {
            continue;
        }

        if let Some(next) = graph.get(&current) {
            queue.extend(next.iter().cloned());
        }
    }

    seen.remove(start);
    seen
}
