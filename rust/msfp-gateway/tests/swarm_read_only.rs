use msfp_gateway::swarm::{
    IntegrityAttestation, SwarmNode, SwarmNodeState, SwarmVote,
};
use std::collections::BTreeSet;

fn measurement(
    value: u8,
) -> [u8; 32] {
    [value; 32]
}

#[test]
fn read_only_node_cannot_vote_or_mutate_authority() {
    let mut node = SwarmNode::new(
        1,
        "v1",
        1,
        BTreeSet::from([measurement(7)]),
    );

    node.enter_read_only()
        .expect("read-only transition");

    assert_eq!(node.state, SwarmNodeState::ReadOnly);
    assert!(node.is_read_only());
    assert!(!node.may_vote());
    assert!(!node.may_mutate_policy());
    assert!(!node.may_issue_capability());
    assert!(!node.may_dispatch_action());
    assert!(node.vote(SwarmVote::Accept).is_err());
}

#[test]
fn valid_independent_attestation_enables_voting_only() {
    let mut node = SwarmNode::new(
        1,
        "v1",
        1,
        BTreeSet::from([measurement(7)]),
    );

    node.enter_read_only()
        .expect("read-only transition");
    node.begin_attestation()
        .expect("attestation transition");

    let attestation = IntegrityAttestation {
        node_id: 1,
        simulation_generation: 1,
        software_measurement: measurement(7),
        policy_version: "v1".to_owned(),
        issued_at_ms: 1,
        expires_at_ms: 10_000,
        nonce: [9_u8; 32],
        signature_valid: true,
    };

    node.verify_attestation(&attestation, 2)
        .expect("valid attestation");

    assert_eq!(node.state, SwarmNodeState::Eligible);
    assert!(node.may_vote());
    assert!(!node.may_mutate_policy());
    assert!(!node.may_issue_capability());
    assert!(!node.may_dispatch_action());

    node.vote(SwarmVote::Accept)
        .expect("eligible node may vote");
}
