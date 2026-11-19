use msfp_gateway::trust::{
    AuthorizationState, TrustDecayPolicy,
};

#[test]
fn trust_decays_monotonically_while_session_is_active() {
    let policy = TrustDecayPolicy {
        initial_confidence: 1.0,
        decay_rate_per_ms: 0.001,
        continue_threshold: 0.2,
    };

    let early = policy.confidence_at(
        100,
        10_000,
        100,
        AuthorizationState::Active,
    );

    let later = policy.confidence_at(
        1_000,
        10_000,
        1_000,
        AuthorizationState::Active,
    );

    assert!(early > later);
    assert!(later > 0.0);
}

#[test]
fn revocation_immediately_sets_confidence_to_zero() {
    let policy = TrustDecayPolicy {
        initial_confidence: 1.0,
        decay_rate_per_ms: 0.0001,
        continue_threshold: 0.5,
    };

    let confidence = policy.confidence_at(
        100,
        10_000,
        100,
        AuthorizationState::Revoked,
    );

    assert_eq!(confidence, 0.0);
    assert!(!policy.session_may_continue(
        100,
        10_000,
        100,
        AuthorizationState::Revoked,
    ));
}

#[test]
fn expiry_immediately_sets_confidence_to_zero() {
    let policy = TrustDecayPolicy {
        initial_confidence: 1.0,
        decay_rate_per_ms: 0.0001,
        continue_threshold: 0.5,
    };

    let confidence = policy.confidence_at(
        10_000,
        10_000,
        10_000,
        AuthorizationState::Active,
    );

    assert_eq!(confidence, 0.0);
}
