#![forbid(unsafe_code)]

use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};
use thiserror::Error;

type HmacSha256 = Hmac<Sha256>;

pub const SESSION_KEY_BYTES: usize = 32;
pub const MAX_CONTEXT_BYTES: usize = 512;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum PrivacyError {
    #[error("master secret must be at least 32 bytes")]
    WeakMasterSecret,
    #[error("context must be non-empty and bounded")]
    InvalidContext,
}

pub fn derive_session_key(
    master_secret: &[u8],
    protocol_label: &str,
    peer_context: &[u8],
    purpose: &str,
    session_nonce: &[u8],
) -> Result<[u8; SESSION_KEY_BYTES], PrivacyError> {
    if master_secret.len() < SESSION_KEY_BYTES {
        return Err(PrivacyError::WeakMasterSecret);
    }

    if protocol_label.is_empty()
        || purpose.is_empty()
        || peer_context.is_empty()
        || session_nonce.is_empty()
        || peer_context.len() > MAX_CONTEXT_BYTES
        || session_nonce.len() > MAX_CONTEXT_BYTES
    {
        return Err(PrivacyError::InvalidContext);
    }

    let peer_hash = Sha256::digest(peer_context);

    let mut mac =
        HmacSha256::new_from_slice(master_secret).map_err(|_| PrivacyError::WeakMasterSecret)?;
    mac.update(protocol_label.as_bytes());
    mac.update(&[0]);
    mac.update(&peer_hash);
    mac.update(&[0]);
    mac.update(purpose.as_bytes());
    mac.update(&[0]);
    mac.update(session_nonce);

    let bytes = mac.finalize().into_bytes();
    let mut output = [0u8; SESSION_KEY_BYTES];
    output.copy_from_slice(&bytes);
    Ok(output)
}

pub fn derive_pairwise_pseudonym(
    pseudonym_secret: &[u8],
    peer_context: &[u8],
    scope: &str,
    epoch: u64,
) -> Result<[u8; SESSION_KEY_BYTES], PrivacyError> {
    if pseudonym_secret.len() < SESSION_KEY_BYTES {
        return Err(PrivacyError::WeakMasterSecret);
    }

    if peer_context.is_empty() || scope.is_empty() || peer_context.len() > MAX_CONTEXT_BYTES {
        return Err(PrivacyError::InvalidContext);
    }

    let peer_hash = Sha256::digest(peer_context);

    let mut mac = HmacSha256::new_from_slice(pseudonym_secret)
        .map_err(|_| PrivacyError::WeakMasterSecret)?;
    mac.update(b"msfp/pairwise-pseudonym/v1");
    mac.update(&[0]);
    mac.update(&peer_hash);
    mac.update(&[0]);
    mac.update(scope.as_bytes());
    mac.update(&[0]);
    mac.update(&epoch.to_be_bytes());

    let bytes = mac.finalize().into_bytes();
    let mut output = [0u8; SESSION_KEY_BYTES];
    output.copy_from_slice(&bytes);
    Ok(output)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fresh_nonce_produces_distinct_session_key() {
        let master = [7u8; 32];

        let first = derive_session_key(
            &master,
            "msfp/session/v1",
            b"peer.example",
            "consent.read",
            b"nonce-a",
        )
        .unwrap();

        let second = derive_session_key(
            &master,
            "msfp/session/v1",
            b"peer.example",
            "consent.read",
            b"nonce-b",
        )
        .unwrap();

        assert_ne!(first, second);
    }

    #[test]
    fn purpose_domain_separates_keys() {
        let master = [9u8; 32];

        let read = derive_session_key(
            &master,
            "msfp/session/v1",
            b"peer.example",
            "consent.read",
            b"nonce-a",
        )
        .unwrap();

        let revoke = derive_session_key(
            &master,
            "msfp/session/v1",
            b"peer.example",
            "consent.revoke",
            b"nonce-a",
        )
        .unwrap();

        assert_ne!(read, revoke);
    }

    #[test]
    fn pairwise_pseudonyms_do_not_match_between_peers() {
        let secret = [11u8; 32];

        let first =
            derive_pairwise_pseudonym(&secret, b"peer-one.example", "status", 1).unwrap();
        let second =
            derive_pairwise_pseudonym(&secret, b"peer-two.example", "status", 1).unwrap();

        assert_ne!(first, second);
    }
}
