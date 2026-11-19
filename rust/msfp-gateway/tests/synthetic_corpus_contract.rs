use std::collections::BTreeSet;

const ALLOWED_OPERATIONS: [&str; 3] = [
    "identity.proof.verify",
    "session.status.read",
    "telemetry.summary.read",
];

const ALLOWED_DATA_CATEGORIES: [&str; 3] = [
    "communication_preference",
    "privacy_preference",
    "session_receipt",
];

#[test]
fn synthetic_corpus_labels_never_include_privileged_operations() {
    let operations = BTreeSet::from(ALLOWED_OPERATIONS);

    assert!(!operations.contains("command.execute"));
    assert!(!operations.contains("actuation.control"));
    assert!(!operations.contains("configuration.write"));
    assert!(!operations.contains("firmware.update"));
    assert!(!operations.contains("raw.memory.read"));
}

#[test]
fn synthetic_corpus_uses_only_non_sensitive_category_labels() {
    let categories = BTreeSet::from(ALLOWED_DATA_CATEGORIES);

    assert!(!categories.contains("biometric_data"));
    assert!(!categories.contains("neural_data"));
    assert!(!categories.contains("medical_data"));
    assert!(!categories.contains("technical_inventory"));
    assert!(!categories.contains("identity_record"));
}
