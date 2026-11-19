use ed25519_dalek::SigningKey;
use msfp_gateway::provenance::{
    metadata_commitment, pseudonym_commitment, verify_chain_append, ArtifactHash,
    ChainHead, ProvenanceRecord, ProvenanceRecordType,
};
use rand_core::OsRng;

#[test]
fn provenance_records_form_a_signed_forward_chain() {
    let signing_key = SigningKey::generate(&mut OsRng);
    let verifying_key = signing_key.verifying_key();

    let genesis = ChainHead::genesis([1_u8; 32]);
    let author = pseudonym_commitment(b"local-author-pseudonym");

    let first = ProvenanceRecord::new_signed(
        1,
        ArtifactHash::from_bytes(b"first artifact"),
        genesis,
        author,
        ProvenanceRecordType::Created,
        "policy-v1",
        "local-retained",
        metadata_commitment(b"artifact-kind=specification"),
        None,
        &signing_key,
    )
    .expect("first record");

    verify_chain_append(None, &first, &verifying_key)
        .expect("first append valid");

    let second = ProvenanceRecord::new_signed(
        2,
        ArtifactHash::from_bytes(b"second artifact"),
        first.head().expect("first head"),
        author,
        ProvenanceRecordType::Revised,
        "policy-v1",
        "local-retained",
        metadata_commitment(b"artifact-kind=specification"),
        Some(first.artifact_hash),
        &signing_key,
    )
    .expect("second record");

    verify_chain_append(Some(&first), &second, &verifying_key)
        .expect("second append valid");
}

#[test]
fn provenance_rejects_wrong_parent_head() {
    let signing_key = SigningKey::generate(&mut OsRng);
    let verifying_key = signing_key.verifying_key();

    let first = ProvenanceRecord::new_signed(
        1,
        ArtifactHash::from_bytes(b"first artifact"),
        ChainHead::genesis([2_u8; 32]),
        pseudonym_commitment(b"local-author-pseudonym"),
        ProvenanceRecordType::Created,
        "policy-v1",
        "local-retained",
        metadata_commitment(b"artifact-kind=specification"),
        None,
        &signing_key,
    )
    .expect("first record");

    let second = ProvenanceRecord::new_signed(
        2,
        ArtifactHash::from_bytes(b"second artifact"),
        ChainHead::genesis([3_u8; 32]),
        pseudonym_commitment(b"local-author-pseudonym"),
        ProvenanceRecordType::Revised,
        "policy-v1",
        "local-retained",
        metadata_commitment(b"artifact-kind=specification"),
        Some(first.artifact_hash),
        &signing_key,
    )
    .expect("second record");

    assert!(verify_chain_append(
        Some(&first),
        &second,
        &verifying_key,
    )
    .is_err());
}
