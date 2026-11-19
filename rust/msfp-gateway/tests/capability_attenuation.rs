use msfp_gateway::attenuation::{
    attenuate, AttenuationResult, CapabilityScope,
};
use std::collections::BTreeSet;

fn scope(
    operations: &[&str],
    data_categories: &[&str],
    audiences: &[&str],
    expires_at_ms: u64,
) -> CapabilityScope {
    CapabilityScope {
        subject: "holder".to_owned(),
        purpose: "identity_proof".to_owned(),
        operations: operations
            .iter()
            .map(|value| (*value).to_owned())
            .collect::<BTreeSet<_>>(),
        data_categories: data_categories
            .iter()
            .map(|value| (*value).to_owned())
            .collect::<BTreeSet<_>>(),
        audiences: audiences
            .iter()
            .map(|value| (*value).to_owned())
            .collect::<BTreeSet<_>>(),
        expires_at_ms,
        session_generation: 1,
        policy_version: "v1".to_owned(),
    }
}

#[test]
fn attenuation_issues_only_intersection_of_all_scopes() {
    let request = scope(
        &["identity.proof.verify", "telemetry.summary.read"],
        &["communication_preference", "privacy_preference"],
        &["authorized_peer", "local_service"],
        10_000,
    );

    let policy = scope(
        &["identity.proof.verify"],
        &["communication_preference", "session_receipt"],
        &["authorized_peer"],
        9_000,
    );

    let consent = scope(
        &["identity.proof.verify", "audit.receipt.read"],
        &["communication_preference"],
        &["authorized_peer"],
        8_000,
    );

    let purpose = scope(
        &["identity.proof.verify"],
        &["communication_preference"],
        &["authorized_peer"],
        7_000,
    );

    let result = attenuate(
        &request,
        &policy,
        &consent,
        &purpose,
        1,
    );

    let AttenuationResult::Allowed(allowed) = result else {
        panic!("expected attenuated capability");
    };

    assert_eq!(
        allowed.operations,
        BTreeSet::from(["identity.proof.verify".to_owned()])
    );
    assert_eq!(
        allowed.data_categories,
        BTreeSet::from(["communication_preference".to_owned()])
    );
    assert_eq!(
        allowed.audiences,
        BTreeSet::from(["authorized_peer".to_owned()])
    );
    assert_eq!(allowed.expires_at_ms, 7_000);
}

#[test]
fn attenuation_denies_when_any_required_dimension_is_empty() {
    let request = scope(
        &["identity.proof.verify"],
        &["communication_preference"],
        &["authorized_peer"],
        10_000,
    );

    let policy = scope(
        &["telemetry.summary.read"],
        &["communication_preference"],
        &["authorized_peer"],
        10_000,
    );

    let consent = request.clone();
    let purpose = request.clone();

    assert_eq!(
        attenuate(
            &request,
            &policy,
            &consent,
            &purpose,
            1,
        ),
        AttenuationResult::Denied
    );
}
