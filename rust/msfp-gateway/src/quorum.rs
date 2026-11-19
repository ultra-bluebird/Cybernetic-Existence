use crate::swarm::{SwarmNode, SwarmNodeState, SwarmVote};
use std::collections::BTreeMap;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum QuorumDecision {
    Accept,
    Reject,
    Abstain,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct QuorumPolicy {
    pub tolerated_byzantine_nodes: usize,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TelemetrySummary {
    pub simulation_generation: u64,
    pub policy_version: String,
    pub eligible_nodes: usize,
    pub accept_votes: usize,
    pub reject_votes: usize,
    pub abstain_votes: usize,
    pub quarantined_nodes: usize,
    pub revoked_nodes: usize,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct QuorumCertificate {
    pub decision: QuorumDecision,
    pub summary: TelemetrySummary,
    pub required_final_quorum: usize,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum QuorumError {
    InvalidFaultTolerance,
    InconsistentGeneration,
    InconsistentPolicyVersion,
}

pub fn evaluate_local_quorum(
    nodes: &[SwarmNode],
    policy: &QuorumPolicy,
) -> Result<QuorumCertificate, QuorumError> {
    let required_node_count = policy
        .tolerated_byzantine_nodes
        .saturating_mul(3)
        .saturating_add(1);

    if nodes.len() < required_node_count {
        return Err(QuorumError::InvalidFaultTolerance);
    }

    let Some(first) = nodes.first() else {
        return Err(QuorumError::InvalidFaultTolerance);
    };

    if nodes.iter().any(|node| {
        node.simulation_generation != first.simulation_generation
    }) {
        return Err(QuorumError::InconsistentGeneration);
    }

    if nodes.iter().any(|node| {
        node.policy_version != first.policy_version
    }) {
        return Err(QuorumError::InconsistentPolicyVersion);
    }

    let mut vote_counts = BTreeMap::new();
    vote_counts.insert(SwarmVote::Accept, 0_usize);
    vote_counts.insert(SwarmVote::Reject, 0_usize);
    vote_counts.insert(SwarmVote::Abstain, 0_usize);

    let mut eligible_nodes = 0_usize;
    let mut quarantined_nodes = 0_usize;
    let mut revoked_nodes = 0_usize;

    for node in nodes {
        match node.state {
            SwarmNodeState::Eligible => {
                eligible_nodes += 1;

                if let Some(vote) = node.last_vote {
                    let count = vote_counts
                        .get_mut(&vote)
                        .expect("all vote variants initialized");
                    *count += 1;
                }
            }
            SwarmNodeState::Quarantined => {
                quarantined_nodes += 1;
            }
            SwarmNodeState::Revoked => {
                revoked_nodes += 1;
            }
            SwarmNodeState::Cold
            | SwarmNodeState::ReadOnly
            | SwarmNodeState::Attesting => {}
        }
    }

    let accept_votes = *vote_counts
        .get(&SwarmVote::Accept)
        .expect("accept initialized");
    let reject_votes = *vote_counts
        .get(&SwarmVote::Reject)
        .expect("reject initialized");
    let abstain_votes = *vote_counts
        .get(&SwarmVote::Abstain)
        .expect("abstain initialized");

    let required_final_quorum = policy
        .tolerated_byzantine_nodes
        .saturating_mul(2)
        .saturating_add(1);

    let decision = if accept_votes >= required_final_quorum
        && reject_votes < required_final_quorum
    {
        QuorumDecision::Accept
    } else if reject_votes >= required_final_quorum {
        QuorumDecision::Reject
    } else {
        QuorumDecision::Abstain
    };

    Ok(QuorumCertificate {
        decision,
        summary: TelemetrySummary {
            simulation_generation: first.simulation_generation,
            policy_version: first.policy_version.clone(),
            eligible_nodes,
            accept_votes,
            reject_votes,
            abstain_votes,
            quarantined_nodes,
            revoked_nodes,
        },
        required_final_quorum,
    })
}
