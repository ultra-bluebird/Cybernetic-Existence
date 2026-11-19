use rand::rngs::OsRng;
use rand::RngCore;
use sha2::{Digest, Sha256};
use subtle::ConstantTimeEq;
use thiserror::Error;

const RECEIPT_SECRET_BYTES: usize = 32;
const DOMAIN_SEPARATOR: &[u8] = b"augmented-hub.anonymous-civic-feedback.receipt.v1";

#[derive(Debug, Error, PartialEq, Eq)]
pub enum ReceiptError {
    #[error("receipt must be a valid base64url value")]
    InvalidEncoding,

    #[error("receipt has an unexpected length")]
    InvalidLength,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ReportReceipt {
    secret: [u8; RECEIPT_SECRET_BYTES],
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ReceiptVerifier {
    digest: [u8; 32],
}

impl ReportReceipt {
    pub fn generate() -> Self {
        let mut secret = [0_u8; RECEIPT_SECRET_BYTES];
        OsRng.fill_bytes(&mut secret);
        Self { secret }
    }

    pub fn encode(&self) -> String {
        base64_url_encode(&self.secret)
    }

    pub fn verifier(&self) -> ReceiptVerifier {
        ReceiptVerifier {
            digest: receipt_digest(&self.secret),
        }
    }

    pub fn parse(encoded: &str) -> Result<Self, ReceiptError> {
        let decoded = base64_url_decode(encoded)?;

        if decoded.len() != RECEIPT_SECRET_BYTES {
            return Err(ReceiptError::InvalidLength);
        }

        let mut secret = [0_u8; RECEIPT_SECRET_BYTES];
        secret.copy_from_slice(&decoded);

        Ok(Self { secret })
    }
}

impl ReceiptVerifier {
    pub fn verify(&self, receipt: &ReportReceipt) -> bool {
        self.digest
            .ct_eq(&receipt_digest(&receipt.secret))
            .into()
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.digest
    }

    pub fn from_bytes(digest: [u8; 32]) -> Self {
        Self { digest }
    }
}

fn receipt_digest(secret: &[u8; RECEIPT_SECRET_BYTES]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(DOMAIN_SEPARATOR);
    hasher.update(secret);

    let digest = hasher.finalize();
    let mut output = [0_u8; 32];
    output.copy_from_slice(&digest);
    output
}

fn base64_url_encode(bytes: &[u8]) -> String {
    const TABLE: &[u8; 64] =
        b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

    let mut output = String::with_capacity((bytes.len() * 4).div_ceil(3));

    for chunk in bytes.chunks(3) {
        let first = chunk[0];
        let second = *chunk.get(1).unwrap_or(&0);
        let third = *chunk.get(2).unwrap_or(&0);

        output.push(TABLE[(first >> 2) as usize] as char);
        output.push(TABLE[(((first & 0b0000_0011) << 4) | (second >> 4)) as usize] as char);

        if chunk.len() >= 2 {
            output.push(TABLE[(((second & 0b0000_1111) << 2) | (third >> 6)) as usize] as char);
        }

        if chunk.len() == 3 {
            output.push(TABLE[(third & 0b0011_1111) as usize] as char);
        }
    }

    output
}

fn base64_url_decode(encoded: &str) -> Result<Vec<u8>, ReceiptError> {
    if encoded.is_empty() || encoded.len() % 4 == 1 {
        return Err(ReceiptError::InvalidEncoding);
    }

    let mut output = Vec::with_capacity(encoded.len() * 3 / 4);
    let bytes = encoded.as_bytes();

    for chunk in bytes.chunks(4) {
        let first = decode_base64_url_character(chunk[0])?;
        let second = decode_base64_url_character(chunk[1])?;
        let third = chunk.get(2).map(|value| decode_base64_url_character(*value)).transpose()?;
        let fourth = chunk.get(3).map(|value| decode_base64_url_character(*value)).transpose()?;

        output.push((first << 2) | (second >> 4));

        if let Some(third) = third {
            output.push((second << 4) | (third >> 2));
        }

        if let Some(fourth) = fourth {
            output.push((third.unwrap_or_default() << 6) | fourth);
        }
    }

    Ok(output)
}

fn decode_base64_url_character(value: u8) -> Result<u8, ReceiptError> {
    match value {
        b'A'..=b'Z' => Ok(value - b'A'),
        b'a'..=b'z' => Ok(value - b'a' + 26),
        b'0'..=b'9' => Ok(value - b'0' + 52),
        b'-' => Ok(62),
        b'_' => Ok(63),
        _ => Err(ReceiptError::InvalidEncoding),
    }
}

#[cfg(test)]
mod tests {
    use super::{ReceiptError, ReportReceipt};

    #[test]
    fn generated_receipt_verifies_against_its_verifier() {
        let receipt = ReportReceipt::generate();
        let verifier = receipt.verifier();

        assert!(verifier.verify(&receipt));
    }

    #[test]
    fn different_receipt_does_not_verify() {
        let first = ReportReceipt::generate();
        let second = ReportReceipt::generate();

        assert!(!first.verifier().verify(&second));
    }

    #[test]
    fn receipt_round_trip_preserves_verification() {
        let receipt = ReportReceipt::generate();
        let encoded = receipt.encode();
        let decoded = ReportReceipt::parse(&encoded).expect("receipt encoding must parse");

        assert!(receipt.verifier().verify(&decoded));
    }

    #[test]
    fn invalid_encoding_is_rejected() {
        assert_eq!(
            ReportReceipt::parse("invalid+receipt"),
            Err(ReceiptError::InvalidEncoding)
        );
    }

    #[test]
    fn short_receipt_is_rejected() {
        assert_eq!(
            ReportReceipt::parse("AQ"),
            Err(ReceiptError::InvalidLength)
        );
    }
}
