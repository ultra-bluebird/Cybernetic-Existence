use msfp_gateway::anomaly::{
    AnomalyDecision, AnomalyPolicy, AnomalyWeights, ProtocolViolations,
};

fn policy() -> AnomalyPolicy {
    AnomalyPolicy {
        weights: AnomalyWeights {
            schema: 0.15,
            size: 0.10,
            replay: 0.20,
            version: 0.10,
            canonical: 0.10,
            duplicate_key: 0.10,
            unknown_field: 0.10,
            lease: 0.05,
            capability: 0.05,
            rate: 0.05,
        },
        abstain_threshold: 0.30,
        reject_threshold: 0.60,
    }
}

#[test]
fn replay_is_hard_fault_independent_of_weighted_score() {
    let violations = ProtocolViolations {
        schema_violation: 0.0,
        size_violation: 0.0,
        replay_violation: 1.0,
        version_violation: 0.0,
        canonical_violation: 0.0,
        duplicate_key_violation: 0.0,
        unknown_field_violation: 0.0,
        lease_violation: 0.0,
        capability_violation: 0.0,
        rate_violation: 0.0,
        authentication_failed: false,
    };

    assert_eq!(
        policy().decide(violations),
        AnomalyDecision::RejectAndTerminate
    );
}

#[test]
fn malformed_structure_can_reject_without_identity_data() {
    let violations = ProtocolViolations {
        schema_violation: 1.0,
        size_violation: 1.0,
        replay_violation: 0.0,
        version_violation: 1.0,
        canonical_violation: 1.0,
        duplicate_key_violation: 1.0,
        unknown_field_violation: 1.0,
        lease_violation: 0.0,
        capability_violation: 0.0,
        rate_violation: 0.0,
        authentication_failed: false,
    };

    assert_eq!(
        policy().decide(violations),
        AnomalyDecision::RejectFrame
    );
}
