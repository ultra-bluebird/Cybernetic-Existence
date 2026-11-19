#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NodeContribution {
    pub node_id: String,
    pub proposal_hash: String,
    pub policy_permitted: bool,
    pub consent_permitted: bool,
    pub valid_signature: bool,
    pub trust_score_micros: u32,
    pub contribution_score_micros: u32,
    pub validity_expires_at_utc: String,
    pub resource_scope: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CoordinationOutcome {
    pub included_node_ids: Vec<String>,
    pub declined_node_ids: Vec<String>,
    pub coordination_score_micros: u32,
    pub consensus_reached: bool,
    pub human_review_required: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CoordinationError {
    EmptyNodeId,
    EmptyProposalHash,
    EmptyValidityWindow,
    EmptyResourceScope,
    InvalidScore,
    DuplicateNodeId,
}

const SCORE_SCALE: u64 = 1_000_000;

pub fn coordinate(
    contributions: &[NodeContribution],
    minimum_consensus_score_micros: u32,
) -> Result<CoordinationOutcome, CoordinationError> {
    let mut included = Vec::new();
    let mut declined = Vec::new();
    let mut total_weighted_score: u64 = 0;
    let mut seen_node_ids = std::collections::BTreeSet::new();

    for contribution in contributions {
        validate_contribution(contribution)?;

        if !seen_node_ids.insert(contribution.node_id.clone()) {
            return Err(CoordinationError::DuplicateNodeId);
        }

        if contribution.policy_permitted
            && contribution.consent_permitted
            && contribution.valid_signature
        {
            let weighted = u64::from(contribution.trust_score_micros)
                * u64::from(contribution.contribution_score_micros)
                / SCORE_SCALE;

            total_weighted_score += weighted;
            included.push(contribution.node_id.clone());
        } else {
            declined.push(contribution.node_id.clone());
        }
    }

    let denominator = u64::try_from(contributions.len()).unwrap_or(u64::MAX);
    let average = if denominator == 0 {
        0
    } else {
        total_weighted_score / denominator
    };

    let coordination_score_micros =
        u32::try_from(average).map_err(|_| CoordinationError::InvalidScore)?;

    Ok(CoordinationOutcome {
        included_node_ids: included,
        declined_node_ids: declined,
        coordination_score_micros,
        consensus_reached: coordination_score_micros >= minimum_consensus_score_micros,
        human_review_required: coordination_score_micros < minimum_consensus_score_micros,
    })
}

fn validate_contribution(
    contribution: &NodeContribution,
) -> Result<(), CoordinationError> {
    if contribution.node_id.trim().is_empty() {
        return Err(CoordinationError::EmptyNodeId);
    }

    if contribution.proposal_hash.trim().is_empty() {
        return Err(CoordinationError::EmptyProposalHash);
    }

    if contribution.validity_expires_at_utc.trim().is_empty() {
        return Err(CoordinationError::EmptyValidityWindow);
    }

    if contribution.resource_scope.trim().is_empty() {
        return Err(CoordinationError::EmptyResourceScope);
    }

    if contribution.trust_score_micros > SCORE_SCALE as u32
        || contribution.contribution_score_micros > SCORE_SCALE as u32
    {
        return Err(CoordinationError::InvalidScore);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn node(
        id: &str,
        policy_permitted: bool,
        consent_permitted: bool,
        valid_signature: bool,
        trust_score_micros: u32,
        contribution_score_micros: u32,
    ) -> NodeContribution {
        NodeContribution {
            node_id: id.to_owned(),
            proposal_hash: "a".repeat(64),
            policy_permitted,
            consent_permitted,
            valid_signature,
            trust_score_micros,
            contribution_score_micros,
            validity_expires_at_utc: "2026-09-04T00:00:00Z".to_owned(),
            resource_scope: "aggregate_only".to_owned(),
        }
    }

    #[test]
    fn excludes_nodes_that_do_not_locally_authorize_participation() {
        let outcome = coordinate(
            &[
                node("node-a", true, true, true, 900_000, 800_000),
                node("node-b", true, false, true, 900_000, 900_000),
            ],
            300_000,
        )
        .expect("valid contributions");

        assert_eq!(outcome.included_node_ids, vec!["node-a"]);
        assert_eq!(outcome.declined_node_ids, vec!["node-b"]);
        assert!(!outcome.consensus_reached);
        assert!(outcome.human_review_required);
    }

    #[test]
    fn reaches_consensus_when_verified_local_contributions_are_sufficient() {
        let outcome = coordinate(
            &[
                node("node-a", true, true, true, 900_000, 900_000),
                node("node-b", true, true, true, 800_000, 900_000),
            ],
            700_000,
        )
        .expect("valid contributions");

        assert!(outcome.consensus_reached);
        assert!(!outcome.human_review_required);
    }

    #[test]
    fn rejects_duplicate_node_ids() {
        let contribution = node("node-a", true, true, true, 900_000, 900_000);

        let result = coordinate(&[contribution.clone(), contribution], 1);

        assert_eq!(result, Err(CoordinationError::DuplicateNodeId));
    }
}
