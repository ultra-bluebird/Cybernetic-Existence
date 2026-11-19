#![forbid(unsafe_code)]

use crypto_agility::{
    CipherSuite, CipherSuiteRegistry, CryptoOperation, CryptoPolicyError,
    NegotiationRequest, SuiteStatus, ASCON_AEAD128, ASCON_HASH256,
    REGISTRY_VERSION,
};

fn digest(character: char) -> String {
    character.to_string().repeat(64)
}

fn suite(
    suite_id: &str,
    security_rank: u16,
    status: SuiteStatus,
) -> CipherSuite {
    CipherSuite {
        suite_id: suite_id.to_owned(),
        protocol_version: 1,
        aead_algorithm: ASCON_AEAD128.to_owned(),
        hash_algorithm: ASCON_HASH256.to_owned(),
        key_bits: 128,
        nonce_bits: 128,
        tag_bits: 128,
        security_rank,
        status,
        activation_epoch: 1,
        sunset_epoch: None,
        implementation_digest_sha256: digest('a'),
        sbom_reference: "sbom:example:crypto".to_owned(),
        evidence_manifest_reference: "evidence:example:crypto".to_owned(),
    }
}

fn registry(suites: Vec<CipherSuite>) -> CipherSuiteRegistry {
    CipherSuiteRegistry {
        registry_version: REGISTRY_VERSION.to_owned(),
        policy_version: "policy-v1".to_owned(),
        policy_epoch: 3,
        minimum_security_rank: 100,
        minimum_protocol_version: 1,
        suites,
        registry_payload_hash_sha256: digest('b'),
        sbom_reference: "sbom:example:registry".to_owned(),
        evidence_manifest_reference: "evidence:example:registry".to_owned(),
    }
}

#[test]
fn active_suite_is_preferred_over_decrypt_only_suite_for_encryption() {
    let registry = registry(vec![
        suite("ASCON_AEAD128_LEGACY", 120, SuiteStatus::DecryptOnly),
        suite("ASCON_AEAD128_CURRENT", 100, SuiteStatus::Active),
    ]);

    let peer = vec![
        "ASCON_AEAD128_LEGACY".to_owned(),
        "ASCON_AEAD128_CURRENT".to_owned(),
    ];

    let result = registry
        .select_suite(&NegotiationRequest {
            peer_supported_suite_ids: &peer,
            current_epoch: 3,
            last_accepted_policy_epoch: 3,
            required_minimum_security_rank: 100,
            required_minimum_protocol_version: 1,
            operation: CryptoOperation::EncryptNewData,
        })
        .expect("an active suite should be selected");

    assert_eq!(result.suite.suite_id, "ASCON_AEAD128_CURRENT");
}

#[test]
fn expired_suite_cannot_be_selected_for_new_encryption() {
    let mut expired = suite("ASCON_AEAD128_EXPIRED", 120, SuiteStatus::Active);
    expired.sunset_epoch = Some(3);

    let registry = registry(vec![expired]);
    let peer = vec!["ASCON_AEAD128_EXPIRED".to_owned()];

    let result = registry.select_suite(&NegotiationRequest {
        peer_supported_suite_ids: &peer,
        current_epoch: 3,
        last_accepted_policy_epoch: 3,
        required_minimum_security_rank: 100,
        required_minimum_protocol_version: 1,
        operation: CryptoOperation::EncryptNewData,
    });

    assert_eq!(result, Err(CryptoPolicyError::NoMutuallyAllowedSuite));
}

#[test]
fn candidate_suite_is_not_selectable_for_production_operation() {
    let registry = registry(vec![suite(
        "ASCON_AEAD128_CANDIDATE",
        200,
        SuiteStatus::Candidate,
    )]);

    let peer = vec!["ASCON_AEAD128_CANDIDATE".to_owned()];

    let result = registry.select_suite(&NegotiationRequest {
        peer_supported_suite_ids: &peer,
        current_epoch: 3,
        last_accepted_policy_epoch: 3,
        required_minimum_security_rank: 100,
        required_minimum_protocol_version: 1,
        operation: CryptoOperation::EncryptNewData,
    });

    assert_eq!(result, Err(CryptoPolicyError::NoMutuallyAllowedSuite));
}
