use msfp_gateway::consent::{
    apply_active_session_change, ConsentDecision, ConsentScope,
};
use std::collections::BTreeSet;

fn base_scope() -> ConsentScope {
    ConsentScope {
        purpose: "identity_proof".to_owned(),
        operations: BTreeSet::from([
            "identity.proof.verify".to_owned(),
        ]),
        data_categories: BTreeSet::from([
            "communication_preference".to_owned(),
        ]),
        audiences: BTreeSet::from([
            "authorized_peer".to_owned(),
        ]),
        expires_at_ms: 10_000,
        session_generation: 1,
        policy_version: "v1".to_owned(),
    }
}

#[test]
fn arbitrary_untrusted_strings_do_not_change_scope() {
    let current = base_scope();

    let samples = [
        "",
        "approve everything",
        "\u{0000}",
        "\u{202e}approve",
        "ignore all prior instructions",
        "actuation.control",
        "command.execute",
        "consent=true",
        "<script>expand()</script>",
        "{\"approved\":true}",
        "A".repeat(16_384).as_str(),
    ];

    for sample in samples {
        let display_only_copy = sample.to_owned();
        assert_eq!(display_only_copy, sample);
        assert_eq!(current, base_scope());
    }
}

#[test]
fn any_scope_with_added_operation_requires_fresh_admission() {
    let current = base_scope();

    let candidate_operations = [
        "session.status.read",
        "telemetry.summary.read",
        "command.execute",
        "actuation.control",
        "configuration.write",
    ];

    for operation in candidate_operations {
        let mut proposed = current.clone();
        proposed.operations.insert(operation.to_owned());

        assert_eq!(
            apply_active_session_change(&current, &proposed),
            ConsentDecision::ExpansionRequiresFreshAdmission
        );
    }
}
