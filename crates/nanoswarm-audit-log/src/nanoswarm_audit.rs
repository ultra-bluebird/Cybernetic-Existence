// filename: mk-bluebird/nanorobotics/crates/nanoswarm-audit-log/src/nanoswarm_audit.rs
// edition: 2024
// rust-version: 1.85
// license: MIT OR Apache-2.0

#![forbid(unsafe_code)]
#![deny(warnings)]

use serde::{Deserialize, Serialize};

use evidence_pqc_compliance::binding::NANOSWARM_AUDIT_LOGGING_V1;
use evidence_pqc_compliance::bundle::EvidencePqcComplianceBundle;

/// Core audit log record for a single nanoswarm action.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NanoswarmAuditRecord {
    pub mission_id: String,
    pub host_did: String,
    pub bostrom_address: String,
    pub timestamp_ms: i64,
    pub action: String,
    pub safety_verdict: String,
}

impl NanoswarmAuditRecord {
    pub fn is_structurally_valid(&self, expected_host_did: &str, expected_bostrom: &str) -> bool {
        if self.host_did != expected_host_did {
            return false;
        }
        if self.bostrom_address != expected_bostrom {
            return false;
        }
        if self.mission_id.is_empty() || self.action.is_empty() || self.safety_verdict.is_empty() {
            return false;
        }
        self.timestamp_ms > 0
    }
}

/// Host-bound audit log envelope for nanoswarm actions with PQC/compliance evidence.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NanoswarmAuditLog {
    pub aln_shard_tag: String,
    pub host_did: String,
    pub bostrom_address: String,
    pub pqc_evidence_bundle: EvidencePqcComplianceBundle,
    pub records: Vec<NanoswarmAuditRecord>,
}

impl NanoswarmAuditLog {
    pub fn new(
        host_did: String,
        bostrom_address: String,
        pqc_evidence_bundle: EvidencePqcComplianceBundle,
    ) -> Self {
        Self {
            aln_shard_tag: NANOSWARM_AUDIT_LOGGING_V1.to_owned(),
            host_did,
            bostrom_address,
            pqc_evidence_bundle,
            records: Vec::new(),
        }
    }

    pub fn append(&mut self, record: NanoswarmAuditRecord) -> Result<(), String> {
        if !self.pqc_evidence_bundle.is_complete() {
            return Err("pqc evidence bundle incomplete".to_owned());
        }
        if !record.is_structurally_valid(&self.host_did, &self.bostrom_address) {
            return Err("record failed structural validation".to_owned());
        }
        self.records.push(record);
        Ok(())
    }

    pub fn is_internally_coherent(
        &self,
        expected_host_did: &str,
        expected_bostrom: &str,
    ) -> bool {
        if self.aln_shard_tag != NANOSWARM_AUDIT_LOGGING_V1 {
            return false;
        }
        if self.host_did != expected_host_did {
            return false;
        }
        if self.bostrom_address != expected_bostrom {
            return false;
        }
        if !self.pqc_evidence_bundle.is_complete() {
            return false;
        }
        for r in &self.records {
            if !r.is_structurally_valid(&self.host_did, &self.bostrom_address) {
                return false;
            }
        }
        true
    }
}
