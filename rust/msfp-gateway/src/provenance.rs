use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use sha2::{Digest, Sha256};
use std::fmt;
use thiserror::Error;

const PROVENANCE_LABEL: &[u8] = b"ORGANICHAIN-v1";
const HASH_BYTES: usize = 32;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd, Hash)]
pub struct ArtifactHash(pub [u8; HASH_BYTES]);

#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd, Hash)]
pub struct ChainHead(pub [u8; HASH_BYTES]);

#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd, Hash)]
pub struct AuthorPseudonymCommitment(pub [u8; HASH_BYTES]);

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ProvenanceRecordType {
    Created,
    Revised,
    Tested,
    Reviewed,
    Superseded,
    Revoked,
    RetentionDeleted,
}

impl ProvenanceRecordType {
    fn as_bytes(&self) -> &'static [u8] {
        match self {
            Self::Created => b"created",
            Self::Revised => b"revised",
            Self::Tested => b"tested",
            Self::Reviewed => b"reviewed",
            Self::Superseded => b"superseded",
            Self::Revoked => b"revoked",
            Self::RetentionDeleted => b"retention_deleted",
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ProvenanceRecord {
    pub schema_version: u16,
    pub sequence: u64,
    pub artifact_hash: ArtifactHash,
    pub parent_head: ChainHead,
    pub author_pseudonym: AuthorPseudonymCommitment,
    pub record_type: ProvenanceRecordType,
    pub policy_version: String,
    pub retention_class: String,
    pub metadata_commitment: [u8; HASH_BYTES],
    pub supersedes: Option<ArtifactHash>,
    pub signature: [u8; 64],
}

#[derive(Debug, Error)]
pub enum ProvenanceError {
    #[error("policy version is invalid")]
    InvalidPolicyVersion,
    #[error("retention class is invalid")]
    InvalidRetentionClass,
    #[error("record sequence is invalid")]
    InvalidSequence,
    #[error("signature verification failed")]
    SignatureInvalid,
    #[error("parent chain head does not match")]
    ParentMismatch,
    #[error("canonical encoding failed")]
    EncodingFailed,
}

impl ArtifactHash {
    pub fn from_bytes(
        bytes: &[u8],
    ) -> Self {
        Self(Sha256::digest(bytes).into())
    }
}

impl ChainHead {
    pub fn genesis(
        workspace_commitment: [u8; HASH_BYTES],
    ) -> Self {
        let mut hasher = Sha256::new();
        hasher.update(PROVENANCE_LABEL);
        hasher.update(b":GENESIS:");
        hasher.update(workspace_commitment);
        Self(hasher.finalize().into())
    }
}

impl fmt::Display for ArtifactHash {
    fn fmt(
        &self,
        formatter: &mut fmt::Formatter<'_>,
    ) -> fmt::Result {
        for byte in self.0 {
            write!(formatter, "{byte:02x}")?;
        }

        Ok(())
    }
}

impl ProvenanceRecord {
    pub fn new_signed(
        sequence: u64,
        artifact_hash: ArtifactHash,
        parent_head: ChainHead,
        author_pseudonym: AuthorPseudonymCommitment,
        record_type: ProvenanceRecordType,
        policy_version: impl Into<String>,
        retention_class: impl Into<String>,
        metadata_commitment: [u8; HASH_BYTES],
        supersedes: Option<ArtifactHash>,
        signing_key: &SigningKey,
    ) -> Result<Self, ProvenanceError> {
        let policy_version = policy_version.into();
        let retention_class = retention_class.into();

        validate_text(&policy_version)
            .map_err(|_| ProvenanceError::InvalidPolicyVersion)?;
        validate_text(&retention_class)
            .map_err(|_| ProvenanceError::InvalidRetentionClass)?;

        if sequence == 0 {
            return Err(ProvenanceError::InvalidSequence);
        }

        let unsigned = UnsignedRecord {
            schema_version: 1,
            sequence,
            artifact_hash,
            parent_head,
            author_pseudonym,
            record_type,
            policy_version,
            retention_class,
            metadata_commitment,
            supersedes,
        };

        let digest = unsigned.digest()?;
        let signature = signing_key.sign(&digest).to_bytes();

        Ok(Self {
            schema_version: unsigned.schema_version,
            sequence: unsigned.sequence,
            artifact_hash: unsigned.artifact_hash,
            parent_head: unsigned.parent_head,
            author_pseudonym: unsigned.author_pseudonym,
            record_type: unsigned.record_type,
            policy_version: unsigned.policy_version,
            retention_class: unsigned.retention_class,
            metadata_commitment: unsigned.metadata_commitment,
            supersedes: unsigned.supersedes,
            signature,
        })
    }

    pub fn verify(
        &self,
        verifying_key: &VerifyingKey,
    ) -> Result<(), ProvenanceError> {
        let digest = self.unsigned().digest()?;
        let signature = Signature::from_bytes(&self.signature);

        verifying_key
            .verify(&digest, &signature)
            .map_err(|_| ProvenanceError::SignatureInvalid)
    }

    pub fn head(
        &self,
    ) -> Result<ChainHead, ProvenanceError> {
        let digest = self.unsigned().digest()?;

        let mut hasher = Sha256::new();
        hasher.update(PROVENANCE_LABEL);
        hasher.update(b":HEAD:");
        hasher.update(self.parent_head.0);
        hasher.update(digest);
        hasher.update(self.signature);

        Ok(ChainHead(hasher.finalize().into()))
    }

    fn unsigned(
        &self,
    ) -> UnsignedRecord {
        UnsignedRecord {
            schema_version: self.schema_version,
            sequence: self.sequence,
            artifact_hash: self.artifact_hash,
            parent_head: self.parent_head,
            author_pseudonym: self.author_pseudonym,
            record_type: self.record_type.clone(),
            policy_version: self.policy_version.clone(),
            retention_class: self.retention_class.clone(),
            metadata_commitment: self.metadata_commitment,
            supersedes: self.supersedes,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct UnsignedRecord {
    schema_version: u16,
    sequence: u64,
    artifact_hash: ArtifactHash,
    parent_head: ChainHead,
    author_pseudonym: AuthorPseudonymCommitment,
    record_type: ProvenanceRecordType,
    policy_version: String,
    retention_class: String,
    metadata_commitment: [u8; HASH_BYTES],
    supersedes: Option<ArtifactHash>,
}

impl UnsignedRecord {
    fn digest(
        &self,
    ) -> Result<[u8; HASH_BYTES], ProvenanceError> {
        let encoded = self.canonical_bytes()?;
        Ok(Sha256::digest(encoded).into())
    }

    fn canonical_bytes(
        &self,
    ) -> Result<Vec<u8>, ProvenanceError> {
        let policy_bytes = self.policy_version.as_bytes();
        let retention_bytes = self.retention_class.as_bytes();

        if policy_bytes.len() > u16::MAX as usize
            || retention_bytes.len() > u16::MAX as usize
        {
            return Err(ProvenanceError::EncodingFailed);
        }

        let mut output = Vec::new();
        output.extend_from_slice(PROVENANCE_LABEL);
        output.extend_from_slice(&self.schema_version.to_be_bytes());
        output.extend_from_slice(&self.sequence.to_be_bytes());
        output.extend_from_slice(&self.artifact_hash.0);
        output.extend_from_slice(&self.parent_head.0);
        output.extend_from_slice(&self.author_pseudonym.0);
        append_length_prefixed(&mut output, self.record_type.as_bytes())?;
        append_length_prefixed(&mut output, policy_bytes)?;
        append_length_prefixed(&mut output, retention_bytes)?;
        output.extend_from_slice(&self.metadata_commitment);

        match self.supersedes {
            Some(artifact_hash) => {
                output.push(1);
                output.extend_from_slice(&artifact_hash.0);
            }
            None => output.push(0),
        }

        Ok(output)
    }
}

pub fn verify_chain_append(
    previous: Option<&ProvenanceRecord>,
    next: &ProvenanceRecord,
    verifying_key: &VerifyingKey,
) -> Result<(), ProvenanceError> {
    next.verify(verifying_key)?;

    match previous {
        None => {
            if next.sequence != 1 {
                return Err(ProvenanceError::InvalidSequence);
            }
        }
        Some(previous) => {
            if next.sequence != previous.sequence.saturating_add(1) {
                return Err(ProvenanceError::InvalidSequence);
            }

            if next.parent_head != previous.head()? {
                return Err(ProvenanceError::ParentMismatch);
            }
        }
    }

    Ok(())
}

pub fn pseudonym_commitment(
    pseudonym_bytes: &[u8],
) -> AuthorPseudonymCommitment {
    let mut hasher = Sha256::new();
    hasher.update(PROVENANCE_LABEL);
    hasher.update(b":AUTHOR:");
    hasher.update(pseudonym_bytes);
    AuthorPseudonymCommitment(hasher.finalize().into())
}

pub fn metadata_commitment(
    approved_metadata: &[u8],
) -> [u8; HASH_BYTES] {
    let mut hasher = Sha256::new();
    hasher.update(PROVENANCE_LABEL);
    hasher.update(b":METADATA:");
    hasher.update(approved_metadata);
    hasher.finalize().into()
}

fn append_length_prefixed(
    output: &mut Vec<u8>,
    value: &[u8],
) -> Result<(), ProvenanceError> {
    let length =
        u16::try_from(value.len()).map_err(|_| ProvenanceError::EncodingFailed)?;

    output.extend_from_slice(&length.to_be_bytes());
    output.extend_from_slice(value);
    Ok(())
}

fn validate_text(
    value: &str,
) -> Result<(), ()> {
    if value.is_empty()
        || value.len() > 256
        || !value.is_ascii()
        || value.as_bytes().contains(&0)
    {
        return Err(());
    }

    Ok(())
}
