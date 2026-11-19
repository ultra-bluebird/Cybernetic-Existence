use msfp_gateway::quorum::{
    evaluate_local_quorum, QuorumDecision, QuorumPolicy,
};
use msfp_gateway::swarm::{
    IntegrityAttestation, SwarmNode, SwarmVote,
};
use std::collections::BTreeSet;

fn measurement() -> [u8; 32] {
    [7_u8; 32]
}

fn eligible_node(
    node_id: u64,
    vote: SwarmVote,
) -> SwarmNode {
    let mut node = SwarmNode::new(
        node_id,
        "v1",
        1,
        BTreeSet::from([measurement()]),
    );

    node.enter_read_only()
        .expect("read-only transition");
    node.begin_attestation()
        .expect("attestation transition");

    node.verify_attestation(
        &IntegrityAttestation {
            node_id,
            simulation_generation: 1,
            software_measurement: measurement(),
            policy_version: "v1".to_owned(),
            issued_at_ms: 1,
            expires_at_ms: 10_000,
            nonce: [node_id as u8; 32],
            signature_valid: true,
        },
        2,
    )
    .expect("valid attestation");

    node.vote(vote)
        .expect("eligible vote");

    node
}

#[test]
fn quorum_accepts_only_after_required_eligible_votes() {
    let nodes = vec![
        eligible_node(1, SwarmVote::Accept),
        eligible_node(2, SwarmVote::Accept),
        eligible_node(3, SwarmVote::Accept),
        eligible_node(4, SwarmVote::Abstain),
    ];

    let certificate = evaluate_local_quorum(
        &nodes,
        &QuorumPolicy {
            tolerated_byzantine_nodes: 1,
        },
    )
    .expect("quorum evaluation");

    assert_eq!(certificate.required_final_quorum, 3);
    assert_eq!(certificate.decision, QuorumDecision::Accept);
    assert_eq!(certificate.summary.accept_votes, 3);
    assert_eq!(certificate.summary.eligible_nodes, 4);
}
