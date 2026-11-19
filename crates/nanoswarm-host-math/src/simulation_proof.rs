// mk-bluebird/nanorobotics/crates/nanoswarm-host-math/src/simulation_proof.rs

#![forbid(unsafe_code)]
#![deny(warnings)]

use chrono::{DateTime, Utc};
use cybercore_hash::{cybercorehash256, cybercorekdf256, CYBERCOREHASH256_LEN};
use serde::{Deserialize, Serialize};

/// ALN migration clause binding for twin proof contexts.
pub const ALN_MIGRATION_CLAUSE: &str = "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

/// Host DID, Bostrom address and ALN identity that twin proofs must bind to.
pub const HOST_DID_ORGANIC_CPU: &str = "didd:aln-bostrom-organic-host";
pub const BOSTROM_ADDRESS_PRIMARY: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
pub const ALN_TWIN_IDENTITY: &str = "aln18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// 16-byte nonce for twin proofs.
pub type TwinNonce = [u8; 16];

/// EvidenceBundle10 digest over canonical serialization.
pub type EvidenceDigest = [u8; CYBERCOREHASH256_LEN];

/// Twin configuration digest (corridors, BCR, kernels).
pub type TwinConfigDigest = [u8; CYBERCOREHASH256_LEN];

/// SimulationProofContext binds a twin run to host identity, Bostrom address,
/// ALN identity, evidence bundle, config, and a proof KDF output.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SimulationProofContext {
    pub host_did: String,
    pub bostrom_address: String,
    pub aln_identity: String,
    pub evidence_digest: EvidenceDigest,
    pub twin_config_digest: TwinConfigDigest,
    pub proof_nonce: TwinNonce,
    pub kdf_output: [u8; CYBERCOREHASH256_LEN],
}

impl SimulationProofContext {
    pub fn new(
        evidence_bytes: &[u8],
        twin_config_bytes: &[u8],
        proof_nonce: TwinNonce,
        master_key: &[u8],
    ) -> Self {
        let evidence_digest = cybercorehash256(evidence_bytes);
        let twin_config_digest = cybercorehash256(twin_config_bytes);
        let mut salt = [0u8; CYBERCOREHASH256_LEN];
        salt[..proof_nonce.len()].copy_from_slice(&proof_nonce);
        let info = b"SimulationProofContext.v1";
        let kdf_output = cybercorekdf256(master_key, &salt, info);

        Self {
            host_did: HOST_DID_ORGANIC_CPU.to_owned(),
            bostrom_address: BOSTROM_ADDRESS_PRIMARY.to_owned(),
            aln_identity: ALN_TWIN_IDENTITY.to_owned(),
            evidence_digest,
            twin_config_digest,
            proof_nonce,
            kdf_output,
        }
    }

    /// Deterministic 256-bit digest over the context itself.
    pub fn proof_digest(&self) -> [u8; CYBERCOREHASH256_LEN] {
        let bytes = bincode::serialize(self)
            .expect("SimulationProofContext must be serializable");
        cybercorehash256(&bytes)
    }

    /// Lightweight identity / authority validation prior to guard acceptance.
    pub fn validate_identity(&self) -> Result<(), String> {
        if self.host_did != HOST_DID_ORGANIC_CPU {
            return Err("host_did mismatch for SimulationProofContext".to_owned());
        }
        if self.bostrom_address != BOSTROM_ADDRESS_PRIMARY {
            return Err("bostrom_address mismatch for SimulationProofContext".to_owned());
        }
        if self.aln_identity != ALN_TWIN_IDENTITY {
            return Err("aln_identity mismatch for SimulationProofContext".to_owned());
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deterministic_proof_digest() {
        let evidence = b"evidence-bundle-10";
        let config = b"twin-config";
        let mut nonce = [0u8; 16];
        nonce.copy_from_slice(&[1u8; 16]);
        let master_key = b"master-key";

        let c1 = SimulationProofContext::new(evidence, config, nonce, master_key);
        let c2 = SimulationProofContext::new(evidence, config, nonce, master_key);
        assert_eq!(c1.proof_digest(), c2.proof_digest());
    }

    #[test]
    fn identity_validation() {
        let evidence = b"evidence";
        let config = b"config";
        let mut nonce = [0u8; 16];
        nonce.copy_from_slice(&[2u8; 16]);
        let master_key = b"key";

        let ctx = SimulationProofContext::new(evidence, config, nonce, master_key);
        assert!(ctx.validate_identity().is_ok());
    }
}
