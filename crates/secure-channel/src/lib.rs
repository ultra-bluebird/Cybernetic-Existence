// nanorobotics/secure-channel/src/lib.rs
use serde::{Deserialize, Serialize};

// Abstract cipher; concrete algorithm must be chosen to avoid blacklisted primitives.
pub trait Cipher {
    fn encrypt(&self, plaintext: &[u8], nonce: &[u8]) -> Vec<u8>;
    fn decrypt(&self, ciphertext: &[u8], nonce: &[u8]) -> Option<Vec<u8>>;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecureMessage {
    pub host_did: String,
    pub bostrom_address: String,
    pub payload: Vec<u8>,
    pub mac: Vec<u8>,
}

pub trait Mac {
    fn tag(&self, data: &[u8]) -> Vec<u8>;
    fn verify(&self, data: &[u8], tag: &[u8]) -> bool;
}
