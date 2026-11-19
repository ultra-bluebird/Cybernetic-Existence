use std::collections::BTreeMap;
use std::fmt::Write;

const SHA256_DIGEST_LEN: usize = 32;
const GENESIS_DIGEST: [u8; SHA256_DIGEST_LEN] = [0_u8; SHA256_DIGEST_LEN];

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SnapshotStatus {
    SnapshotAccepted,
    SnapshotIntegrityConfirmed,
    SnapshotInclusionUnconfirmed,
    SnapshotHistoryInconsistent,
    SnapshotFormatInvalid,
    SnapshotReviewRequired,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ContinuityState {
    ReportedStable,
    ReportedUncertain,
    ReviewRequired,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum UncertaintyReason {
    ContextIncomplete,
    ReportedInterference,
    ReportingDelay,
    MethodChange,
    OtherNonIdentifyingReason,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AbstractStateLeaf {
    pub leaf_id: String,
    pub component_role: String,
    pub continuity_state: ContinuityState,
    pub uncertainty_flag: bool,
    pub uncertainty_reason: Option<UncertaintyReason>,
    pub non_identifying_value: u16,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SnapshotInput {
    pub snapshot_id: String,
    pub sequence: u64,
    pub created_at_utc: String,
    pub continuity_state: ContinuityState,
    pub reported_component_count: u32,
    pub uncertainty_flag: bool,
    pub uncertainty_reason: Option<UncertaintyReason>,
    pub retention_profile_revision: String,
    pub leaves: Vec<AbstractStateLeaf>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SignatureEnvelope {
    pub algorithm: String,
    pub key_reference: String,
    pub detached_signature: Vec<u8>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SnapshotCheckpoint {
    pub snapshot_id: String,
    pub sequence: u64,
    pub created_at_utc: String,
    pub continuity_state: ContinuityState,
    pub reported_component_count: u32,
    pub uncertainty_flag: bool,
    pub uncertainty_reason: Option<UncertaintyReason>,
    pub retention_profile_revision: String,
    pub leaf_count: u32,
    pub merkle_root_sha256: [u8; SHA256_DIGEST_LEN],
    pub previous_checkpoint_digest_sha256: [u8; SHA256_DIGEST_LEN],
    pub checkpoint_digest_sha256: [u8; SHA256_DIGEST_LEN],
    pub signature_envelope: Option<SignatureEnvelope>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct IntegrityResult {
    pub status: SnapshotStatus,
    pub explanation: String,
}

pub trait DetachedSigner {
    fn algorithm(&self) -> &str;
    fn key_reference(&self) -> &str;
    fn sign(&self, message: &[u8]) -> Result<Vec<u8>, String>;
    fn verify(&self, message: &[u8], signature: &[u8]) -> Result<bool, String>;
}

pub fn create_checkpoint(
    input: SnapshotInput,
    previous_checkpoint_digest_sha256: [u8; SHA256_DIGEST_LEN],
    signer: Option<&dyn DetachedSigner>,
) -> Result<SnapshotCheckpoint, String> {
    validate_snapshot_input(&input)?;

    let canonical_leaves = canonicalize_leaves(&input.leaves)?;
    let merkle_root_sha256 = merkle_root(&canonical_leaves);

    let checkpoint_bytes = canonical_checkpoint_bytes(
        &input,
        canonical_leaves.len() as u32,
        merkle_root_sha256,
        previous_checkpoint_digest_sha256,
    );

    let checkpoint_digest_sha256 = sha256(&checkpoint_bytes);

    let signature_envelope = match signer {
        None => None,
        Some(signer) => Some(SignatureEnvelope {
            algorithm: signer.algorithm().to_owned(),
            key_reference: signer.key_reference().to_owned(),
            detached_signature: signer.sign(&checkpoint_digest_sha256)?,
        }),
    };

    Ok(SnapshotCheckpoint {
        snapshot_id: input.snapshot_id,
        sequence: input.sequence,
        created_at_utc: input.created_at_utc,
        continuity_state: input.continuity_state,
        reported_component_count: input.reported_component_count,
        uncertainty_flag: input.uncertainty_flag,
        uncertainty_reason: input.uncertainty_reason,
        retention_profile_revision: input.retention_profile_revision,
        leaf_count: canonical_leaves.len() as u32,
        merkle_root_sha256,
        previous_checkpoint_digest_sha256,
        checkpoint_digest_sha256,
        signature_envelope,
    })
}

pub fn verify_checkpoint_integrity(
    input: &SnapshotInput,
    checkpoint: &SnapshotCheckpoint,
    expected_previous_checkpoint_digest_sha256: [u8; SHA256_DIGEST_LEN],
    signer: Option<&dyn DetachedSigner>,
) -> IntegrityResult {
    if let Err(error) = validate_snapshot_input(input) {
        return IntegrityResult {
            status: SnapshotStatus::SnapshotFormatInvalid,
            explanation: error,
        };
    }

    if input.snapshot_id != checkpoint.snapshot_id
        || input.sequence != checkpoint.sequence
        || input.created_at_utc != checkpoint.created_at_utc
        || input.continuity_state != checkpoint.continuity_state
        || input.reported_component_count != checkpoint.reported_component_count
        || input.uncertainty_flag != checkpoint.uncertainty_flag
        || input.uncertainty_reason != checkpoint.uncertainty_reason
        || input.retention_profile_revision != checkpoint.retention_profile_revision
    {
        return IntegrityResult {
            status: SnapshotStatus::SnapshotHistoryInconsistent,
            explanation: "Checkpoint metadata does not match the supplied abstract snapshot.".to_owned(),
        };
    }

    if checkpoint.previous_checkpoint_digest_sha256 != expected_previous_checkpoint_digest_sha256 {
        return IntegrityResult {
            status: SnapshotStatus::SnapshotHistoryInconsistent,
            explanation: "Checkpoint predecessor digest does not match the expected append-only chain.".to_owned(),
        };
    }

    let canonical_leaves = match canonicalize_leaves(&input.leaves) {
        Ok(value) => value,
        Err(error) => {
            return IntegrityResult {
                status: SnapshotStatus::SnapshotFormatInvalid,
                explanation: error,
            };
        }
    };

    let recomputed_merkle_root = merkle_root(&canonical_leaves);
    if recomputed_merkle_root != checkpoint.merkle_root_sha256 {
        return IntegrityResult {
            status: SnapshotStatus::SnapshotHistoryInconsistent,
            explanation: "Supplied leaves do not reconstruct the committed SHA-256 Merkle root.".to_owned(),
        };
    }

    let checkpoint_bytes = canonical_checkpoint_bytes(
        input,
        canonical_leaves.len() as u32,
        recomputed_merkle_root,
        expected_previous_checkpoint_digest_sha256,
    );

    let recomputed_checkpoint_digest = sha256(&checkpoint_bytes);
    if recomputed_checkpoint_digest != checkpoint.checkpoint_digest_sha256 {
        return IntegrityResult {
            status: SnapshotStatus::SnapshotHistoryInconsistent,
            explanation: "Checkpoint digest does not match the canonical SHA-256 commitment.".to_owned(),
        };
    }

    if let (Some(envelope), Some(signer)) = (&checkpoint.signature_envelope, signer) {
        if envelope.algorithm != signer.algorithm() || envelope.key_reference != signer.key_reference() {
            return IntegrityResult {
                status: SnapshotStatus::SnapshotReviewRequired,
                explanation: "Signature metadata differs from the supplied verification interface.".to_owned(),
            };
        }

        match signer.verify(&checkpoint.checkpoint_digest_sha256, &envelope.detached_signature) {
            Ok(true) => {}
            Ok(false) => {
                return IntegrityResult {
                    status: SnapshotStatus::SnapshotHistoryInconsistent,
                    explanation: "Detached signature verification failed.".to_owned(),
                };
            }
            Err(error) => {
                return IntegrityResult {
                    status: SnapshotStatus::SnapshotReviewRequired,
                    explanation: format!("Signature verification requires review: {error}"),
                };
            }
        }
    } else if checkpoint.signature_envelope.is_some() && signer.is_none() {
        return IntegrityResult {
            status: SnapshotStatus::SnapshotReviewRequired,
            explanation: "A signature envelope is present but no reviewed verifier was supplied.".to_owned(),
        };
    }

    if input.uncertainty_flag {
        return IntegrityResult {
            status: SnapshotStatus::SnapshotReviewRequired,
            explanation: "Snapshot integrity is internally consistent, but the supplied report is marked uncertain.".to_owned(),
        };
    }

    IntegrityResult {
        status: SnapshotStatus::SnapshotIntegrityConfirmed,
        explanation: "The abstract snapshot matches its SHA-256 commitment and expected predecessor digest. This confirms record consistency only; it does not verify real-world state.".to_owned(),
    }
}

pub fn verify_append_only_predecessor(
    earlier: &SnapshotCheckpoint,
    later: &SnapshotCheckpoint,
) -> IntegrityResult {
    if later.sequence <= earlier.sequence {
        return IntegrityResult {
            status: SnapshotStatus::SnapshotHistoryInconsistent,
            explanation: "Later checkpoint sequence must be strictly greater than earlier checkpoint sequence.".to_owned(),
        };
    }

    if later.previous_checkpoint_digest_sha256 != earlier.checkpoint_digest_sha256 {
        return IntegrityResult {
            status: SnapshotStatus::SnapshotInclusionUnconfirmed,
            explanation: "The supplied checkpoints are not adjacent. A reviewed consistency proof or intervening checkpoint chain is required.".to_owned(),
        };
    }

    IntegrityResult {
        status: SnapshotStatus::SnapshotIntegrityConfirmed,
        explanation: "Adjacent checkpoints preserve the expected append-only predecessor commitment. This does not establish the truth of any reported state.".to_owned(),
    }
}

fn validate_snapshot_input(input: &SnapshotInput) -> Result<(), String> {
    validate_opaque_token(&input.snapshot_id, "snapshot_id")?;
    validate_opaque_token(&input.retention_profile_revision, "retention_profile_revision")?;

    if !is_utc_timestamp(&input.created_at_utc) {
        return Err("created_at_utc must use an ISO-8601 UTC representation ending in Z.".to_owned());
    }

    if input.reported_component_count == 0 {
        return Err("reported_component_count must be at least one.".to_owned());
    }

    if input.leaves.is_empty() {
        return Err("At least one abstract state leaf is required.".to_owned());
    }

    if input.reported_component_count != input.leaves.len() as u32 {
        return Err("reported_component_count must equal the supplied leaf count.".to_owned());
    }

    if input.uncertainty_flag && input.uncertainty_reason.is_none() {
        return Err("An uncertainty reason is required when uncertainty_flag is true.".to_owned());
    }

    if !input.uncertainty_flag && input.uncertainty_reason.is_some() {
        return Err("An uncertainty reason is permitted only when uncertainty_flag is true.".to_owned());
    }

    for leaf in &input.leaves {
        validate_opaque_token(&leaf.leaf_id, "leaf_id")?;
        validate_component_role(&leaf.component_role)?;

        if leaf.uncertainty_flag && leaf.uncertainty_reason.is_none() {
            return Err("Each uncertain leaf must include an uncertainty reason.".to_owned());
        }

        if !leaf.uncertainty_flag && leaf.uncertainty_reason.is_some() {
            return Err("A leaf uncertainty reason is permitted only when its uncertainty flag is true.".to_owned());
        }
    }

    Ok(())
}

fn validate_component_role(value: &str) -> Result<(), String> {
    match value {
        "HOST_REPORTED_COMPONENT"
        | "HOST_REPORTED_CONTEXT"
        | "HOST_REPORTED_AMBIENT_CONTEXT"
        | "UNKNOWN_REPORTED_COMPONENT" => Ok(()),
        _ => Err("component_role is not in the approved abstract vocabulary.".to_owned()),
    }
}

fn validate_opaque_token(value: &str, field: &str) -> Result<(), String> {
    let allowed = value
        .chars()
        .all(|character| character.is_ascii_alphanumeric() || matches!(character, '.' | '_' | '~' | '-'));

    if value.len() < 8 || value.len() > 128 || !allowed {
        return Err(format!("{field} must be an opaque token with 8 to 128 safe ASCII characters."));
    }

    Ok(())
}

fn is_utc_timestamp(value: &str) -> bool {
    value.len() >= 20
        && value.ends_with('Z')
        && value.as_bytes().get(4) == Some(&b'-')
        && value.as_bytes().get(7) == Some(&b'-')
        && value.as_bytes().get(10) == Some(&b'T')
        && value.as_bytes().get(13) == Some(&b':')
        && value.as_bytes().get(16) == Some(&b':')
}

fn canonicalize_leaves(leaves: &[AbstractStateLeaf]) -> Result<Vec<Vec<u8>>, String> {
    let mut sorted = BTreeMap::new();

    for leaf in leaves {
        let bytes = canonical_leaf_bytes(leaf);
        if sorted.insert(leaf.leaf_id.clone(), bytes).is_some() {
            return Err("leaf_id values must be unique within one snapshot.".to_owned());
        }
    }

    Ok(sorted.into_values().collect())
}

fn canonical_leaf_bytes(leaf: &AbstractStateLeaf) -> Vec<u8> {
    let uncertainty_reason = match &leaf.uncertainty_reason {
        Some(reason) => uncertainty_reason_name(reason),
        None => "NONE",
    };

    format!(
        "leaf-v1|leaf_id={}|component_role={}|continuity_state={}|uncertainty_flag={}|uncertainty_reason={}|non_identifying_value={}",
        leaf.leaf_id,
        leaf.component_role,
        continuity_state_name(&leaf.continuity_state),
        leaf.uncertainty_flag,
        uncertainty_reason,
        leaf.non_identifying_value
    )
    .into_bytes()
}

fn canonical_checkpoint_bytes(
    input: &SnapshotInput,
    leaf_count: u32,
    merkle_root_sha256: [u8; SHA256_DIGEST_LEN],
    previous_checkpoint_digest_sha256: [u8; SHA256_DIGEST_LEN],
) -> Vec<u8> {
    let uncertainty_reason = match &input.uncertainty_reason {
        Some(reason) => uncertainty_reason_name(reason),
        None => "NONE",
    };

    format!(
        "checkpoint-v1|snapshot_id={}|sequence={}|created_at_utc={}|continuity_state={}|reported_component_count={}|uncertainty_flag={}|uncertainty_reason={}|retention_profile_revision={}|leaf_count={}|merkle_root_sha256={}|previous_checkpoint_digest_sha256={}",
        input.snapshot_id,
        input.sequence,
        input.created_at_utc,
        continuity_state_name(&input.continuity_state),
        input.reported_component_count,
        input.uncertainty_flag,
        uncertainty_reason,
        input.retention_profile_revision,
        hex_encode(&merkle_root_sha256),
        hex_encode(&previous_checkpoint_digest_sha256)
    )
    .into_bytes()
}

fn continuity_state_name(value: &ContinuityState) -> &'static str {
    match value {
        ContinuityState::ReportedStable => "REPORTED_STABLE",
        ContinuityState::ReportedUncertain => "REPORTED_UNCERTAIN",
        ContinuityState::ReviewRequired => "REVIEW_REQUIRED",
    }
}

fn uncertainty_reason_name(value: &UncertaintyReason) -> &'static str {
    match value {
        UncertaintyReason::ContextIncomplete => "CONTEXT_INCOMPLETE",
        UncertaintyReason::ReportedInterference => "REPORTED_INTERFERENCE",
        UncertaintyReason::ReportingDelay => "REPORTING_DELAY",
        UncertaintyReason::MethodChange => "METHOD_CHANGE",
        UncertaintyReason::OtherNonIdentifyingReason => "OTHER_NON_IDENTIFYING_REASON",
    }
}

fn merkle_root(canonical_leaves: &[Vec<u8>]) -> [u8; SHA256_DIGEST_LEN] {
    let mut level: Vec<[u8; SHA256_DIGEST_LEN]> = canonical_leaves
        .iter()
        .map(|leaf| leaf_hash(leaf))
        .collect();

    if level.len() == 1 {
        return level[0];
    }

    while level.len() > 1 {
        let mut next_level = Vec::with_capacity(level.len().div_ceil(2));

        for pair in level.chunks(2) {
            let left = pair[0];
            let right = pair.get(1).copied().unwrap_or(left);
            next_level.push(node_hash(left, right));
        }

        level = next_level;
    }

    level[0]
}

fn leaf_hash(leaf: &[u8]) -> [u8; SHA256_DIGEST_LEN] {
    let mut bytes = Vec::with_capacity(1 + leaf.len());
    bytes.push(0x00);
    bytes.extend_from_slice(leaf);
    sha256(&bytes)
}

fn node_hash(
    left: [u8; SHA256_DIGEST_LEN],
    right: [u8; SHA256_DIGEST_LEN],
) -> [u8; SHA256_DIGEST_LEN] {
    let mut bytes = Vec::with_capacity(1 + SHA256_DIGEST_LEN * 2);
    bytes.push(0x01);
    bytes.extend_from_slice(&left);
    bytes.extend_from_slice(&right);
    sha256(&bytes)
}

fn sha256(input: &[u8]) -> [u8; SHA256_DIGEST_LEN] {
    const H0: [u32; 8] = [
        0x6a09e667,
        0xbb67ae85,
        0x3c6ef372,
        0xa54ff53a,
        0x510e527f,
        0x9b05688c,
        0x1f83d9ab,
        0x5be0cd19,
    ];

    const K: [u32; 64] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    let bit_length = (input.len() as u64)
        .checked_mul(8)
        .expect("input length must fit into SHA-256 bit-length encoding");

    let mut message = input.to_vec();
    message.push(0x80);

    while (message.len() + 8) % 64 != 0 {
        message.push(0x00);
    }

    message.extend_from_slice(&bit_length.to_be_bytes());

    let mut hash = H0;

    for block in message.chunks_exact(64) {
        let mut words = [0_u32; 64];

        for (index, chunk) in block.chunks_exact(4).take(16).enumerate() {
            words[index] = u32::from_be_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
        }

        for index in 16..64 {
            let sigma0 = words[index - 15].rotate_right(7)
                ^ words[index - 15].rotate_right(18)
                ^ (words[index - 15] >> 3);
            let sigma1 = words[index - 2].rotate_right(17)
                ^ words[index - 2].rotate_right(19)
                ^ (words[index - 2] >> 10);

            words[index] = words[index - 16]
                .wrapping_add(sigma0)
                .wrapping_add(words[index - 7])
                .wrapping_add(sigma1);
        }

        let mut a = hash[0];
        let mut b = hash[1];
        let mut c = hash[2];
        let mut d = hash[3];
        let mut e = hash[4];
        let mut f = hash[5];
        let mut g = hash[6];
        let mut h = hash[7];

        for index in 0..64 {
            let sum1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let choose = (e & f) ^ ((!e) & g);
            let temp1 = h
                .wrapping_add(sum1)
                .wrapping_add(choose)
                .wrapping_add(K[index])
                .wrapping_add(words[index]);
            let sum0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let majority = (a & b) ^ (a & c) ^ (b & c);
            let temp2 = sum0.wrapping_add(majority);

            h = g;
            g = f;
            f = e;
            e = d.wrapping_add(temp1);
            d = c;
            c = b;
            b = a;
            a = temp1.wrapping_add(temp2);
        }

        hash[0] = hash[0].wrapping_add(a);
        hash[1] = hash[1].wrapping_add(b);
        hash[2] = hash[2].wrapping_add(c);
        hash[3] = hash[3].wrapping_add(d);
        hash[4] = hash[4].wrapping_add(e);
        hash[5] = hash[5].wrapping_add(f);
        hash[6] = hash[6].wrapping_add(g);
        hash[7] = hash[7].wrapping_add(h);
    }

    let mut output = [0_u8; SHA256_DIGEST_LEN];

    for (index, word) in hash.iter().enumerate() {
        output[index * 4..index * 4 + 4].copy_from_slice(&word.to_be_bytes());
    }

    output
}

fn hex_encode(bytes: &[u8]) -> String {
    let mut output = String::with_capacity(bytes.len() * 2);

    for byte in bytes {
        let _ = write!(&mut output, "{byte:02x}");
    }

    output
}

#[cfg(test)]
mod tests {
    use super::*;

    fn leaf(
        leaf_id: &str,
        state: ContinuityState,
        uncertain: bool,
    ) -> AbstractStateLeaf {
        AbstractStateLeaf {
            leaf_id: leaf_id.to_owned(),
            component_role: "HOST_REPORTED_COMPONENT".to_owned(),
            continuity_state: state,
            uncertainty_flag: uncertain,
            uncertainty_reason: uncertain.then_some(UncertaintyReason::ContextIncomplete),
            non_identifying_value: 1,
        }
    }

    fn snapshot(sequence: u64, leaves: Vec<AbstractStateLeaf>) -> SnapshotInput {
        SnapshotInput {
            snapshot_id: format!("snapshot-{sequence:08}"),
            sequence,
            created_at_utc: "2026-09-08T02:55:00Z".to_owned(),
            continuity_state: ContinuityState::ReportedStable,
            reported_component_count: leaves.len() as u32,
            uncertainty_flag: false,
            uncertainty_reason: None,
            retention_profile_revision: "retention-v1".to_owned(),
            leaves,
        }
    }

    #[test]
    fn sha256_matches_standard_known_vector() {
        assert_eq!(
            hex_encode(&sha256(b"abc")),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn checkpoint_verifies_against_identical_abstract_snapshot() {
        let input = snapshot(
            1,
            vec![
                leaf("leaf-alpha-0001", ContinuityState::ReportedStable, false),
                leaf("leaf-beta-0002", ContinuityState::ReportedStable, false),
            ],
        );

        let checkpoint = create_checkpoint(input.clone(), GENESIS_DIGEST, None)
            .expect("valid checkpoint creation");

        let result = verify_checkpoint_integrity(
            &input,
            &checkpoint,
            GENESIS_DIGEST,
            None,
        );

        assert_eq!(result.status, SnapshotStatus::SnapshotIntegrityConfirmed);
    }

    #[test]
    fn changed_leaf_is_detected_as_history_inconsistency() {
        let input = snapshot(
            1,
            vec![
                leaf("leaf-alpha-0001", ContinuityState::ReportedStable, false),
                leaf("leaf-beta-0002", ContinuityState::ReportedStable, false),
            ],
        );

        let checkpoint = create_checkpoint(input.clone(), GENESIS_DIGEST, None)
            .expect("valid checkpoint creation");

        let altered = snapshot(
            1,
            vec![
                leaf("leaf-alpha-0001", ContinuityState::ReportedStable, false),
                leaf("leaf-beta-0002", ContinuityState::ReviewRequired, false),
            ],
        );

        let result = verify_checkpoint_integrity(
            &altered,
            &checkpoint,
            GENESIS_DIGEST,
            None,
        );

        assert_eq!(result.status, SnapshotStatus::SnapshotHistoryInconsistent);
    }

    #[test]
    fn uncertain_snapshot_requires_review_even_when_integrity_matches() {
        let input = SnapshotInput {
            snapshot_id: "snapshot-00000001".to_owned(),
            sequence: 1,
            created_at_utc: "2026-09-08T02:55:00Z".to_owned(),
            continuity_state: ContinuityState::ReportedUncertain,
            reported_component_count: 1,
            uncertainty_flag: true,
            uncertainty_reason: Some(UncertaintyReason::ContextIncomplete),
            retention_profile_revision: "retention-v1".to_owned(),
            leaves: vec![leaf(
                "leaf-alpha-0001",
                ContinuityState::ReportedUncertain,
                true,
            )],
        };

        let checkpoint = create_checkpoint(input.clone(), GENESIS_DIGEST, None)
            .expect("valid checkpoint creation");

        let result = verify_checkpoint_integrity(
            &input,
            &checkpoint,
            GENESIS_DIGEST,
            None,
        );

        assert_eq!(result.status, SnapshotStatus::SnapshotReviewRequired);
    }

    #[test]
    fn adjacent_chain_requires_exact_predecessor_digest() {
        let first_input = snapshot(
            1,
            vec![leaf(
                "leaf-alpha-0001",
                ContinuityState::ReportedStable,
                false,
            )],
        );

        let first = create_checkpoint(first_input, GENESIS_DIGEST, None)
            .expect("first checkpoint");

        let second_input = snapshot(
            2,
            vec![
                leaf("leaf-alpha-0001", ContinuityState::ReportedStable, false),
                leaf("leaf-beta-0002", ContinuityState::ReportedStable, false),
            ],
        );

        let second = create_checkpoint(
            second_input,
            first.checkpoint_digest_sha256,
            None,
        )
        .expect("second checkpoint");

        let result = verify_append_only_predecessor(&first, &second);

        assert_eq!(result.status, SnapshotStatus::SnapshotIntegrityConfirmed);
    }

    #[test]
    fn uncertainty_reason_is_required_when_flagged() {
        let invalid = SnapshotInput {
            snapshot_id: "snapshot-00000001".to_owned(),
            sequence: 1,
            created_at_utc: "2026-09-08T02:55:00Z".to_owned(),
            continuity_state: ContinuityState::ReportedUncertain,
            reported_component_count: 1,
            uncertainty_flag: true,
            uncertainty_reason: None,
            retention_profile_revision: "retention-v1".to_owned(),
            leaves: vec![leaf(
                "leaf-alpha-0001",
                ContinuityState::ReportedUncertain,
                false,
            )],
        };

        assert!(create_checkpoint(invalid, GENESIS_DIGEST, None).is_err());
    }
}
