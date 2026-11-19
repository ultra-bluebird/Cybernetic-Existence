// mk-bluebird/nanorobotics/crates/nanoswarm-host-math/src/twin_result.rs

#![forbid(unsafe_code)]
#![deny(warnings)]

use chrono::{DateTime, Utc};
use cybercore_hash::{cybercorehash256, CYBERCOREHASH256_LEN};
use serde::{Deserialize, Serialize};

/// Digest types reused by guards and audit log.
pub type TwinResultDigest = [u8; CYBERCOREHASH256_LEN];
pub type HostStateDigest = [u8; CYBERCOREHASH256_LEN];
pub type BiocompatProfileDigest = [u8; CYBERCOREHASH256_LEN];

/// TwinSimulationResult carries RoH, margins, host and mission binding,
/// and integrity digests for host state and biocompatibility profile.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TwinSimulationResult {
    pub mission_id: String,
    pub host_did: String,
    pub bostrom_address: String,
    pub aln_identity: String,
    pub roh_global_max: f32,
    pub min_margin_per_region: f32,
    pub host_state_digest: HostStateDigest,
    pub biocompat_profile_digest: BiocompatProfileDigest,
    pub generated_at: DateTime<Utc>,
    pub validity_window_s: i64,
    pub twin_nonce: [u8; 16],
}

impl TwinSimulationResult {
    /// Compute a canonical digest over all fields, for signing and audit anchoring.
    pub fn result_digest(&self) -> TwinResultDigest {
        let bytes = bincode::serialize(self)
            .expect("TwinSimulationResult must be serializable");
        cybercorehash256(&bytes)
    }

    /// Compute expiration timestamp.
    pub fn expires_at(&self) -> DateTime<Utc> {
        self.generated_at + chrono::Duration::seconds(self.validity_window_s)
    }

    /// Staleness detection against current state/profile hashes and wall clock.
    pub fn is_stale(
        &self,
        current_host_state_digest: &HostStateDigest,
        current_biocompat_digest: &BiocompatProfileDigest,
        now: DateTime<Utc>,
    ) -> bool {
        if &self.host_state_digest != current_host_state_digest {
            return true;
        }
        if &self.biocompat_profile_digest != current_biocompat_digest {
            return true;
        }
        now > self.expires_at()
    }

    /// Basic identity/binding verification prior to guard use.
    pub fn validate_identity(
        &self,
        expected_host_did: &str,
        expected_bostrom: &str,
        expected_aln_identity: &str,
    ) -> Result<(), String> {
        if self.host_did != expected_host_did {
            return Err("TwinSimulationResult host_did mismatch".to_owned());
        }
        if self.bostrom_address != expected_bostrom {
            return Err("TwinSimulationResult bostrom_address mismatch".to_owned());
        }
        if self.aln_identity != expected_aln_identity {
            return Err("TwinSimulationResult aln_identity mismatch".to_owned());
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mk_digest(byte: u8) -> [u8; CYBERCOREHASH256_LEN] {
        [byte; CYBERCOREHASH256_LEN]
    }

    #[test]
    fn digest_determinism() {
        let r1 = TwinSimulationResult {
            mission_id: "m-1".to_owned(),
            host_did: "didd:aln-bostrom-organic-host".to_owned(),
            bostrom_address: "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_owned(),
            aln_identity: "aln18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_owned(),
            roh_global_max: 0.12,
            min_margin_per_region: 0.08,
            host_state_digest: mk_digest(1),
            biocompat_profile_digest: mk_digest(2),
            generated_at: Utc::now(),
            validity_window_s: 60,
            twin_nonce: [3u8; 16],
        };
        let r2 = r1.clone();
        assert_eq!(r1.result_digest(), r2.result_digest());
    }

    #[test]
    fn staleness_detection() {
        let now = Utc::now();
        let current_host = mk_digest(1);
        let current_bio = mk_digest(2);

        let res = TwinSimulationResult {
            mission_id: "m-2".to_owned(),
            host_did: "didd:aln-bostrom-organic-host".to_owned(),
            bostrom_address: "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_owned(),
            aln_identity: "aln18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_owned(),
            roh_global_max: 0.10,
            min_margin_per_region: 0.05,
            host_state_digest: current_host,
            biocompat_profile_digest: current_bio,
            generated_at: now,
            validity_window_s: 30,
            twin_nonce: [4u8; 16],
        };

        assert!(!res.is_stale(&current_host, &current_bio, now));
        let future = now + chrono::Duration::seconds(31);
        assert!(res.is_stale(&current_host, &current_bio, future));
    }
}
