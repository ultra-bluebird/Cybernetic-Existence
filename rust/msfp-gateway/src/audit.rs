use crate::TeardownReceipt;
use sha2::{Digest, Sha256};
use std::fs::{create_dir_all, OpenOptions};
use std::io::{self, Write};
use std::path::Path;

const AUDIT_LABEL: &[u8] = b"MSFP-AUDIT-v1";

pub fn write_teardown_receipt(
    directory: &Path,
    receipt: &TeardownReceipt,
) -> io::Result<[u8; 32]> {
    create_dir_all(directory)?;

    let digest = receipt_digest(receipt);
    let path = directory.join("teardown-receipts.log");

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)?;

    let line = format!(
        "receipt_hash={} generation={} reason={} key_handles_invalidated={} capability_revoked={} policy_version={}\n",
        hex(&digest),
        receipt.session_generation,
        receipt.reason_code,
        receipt.key_handles_invalidated,
        receipt.capability_revoked,
        receipt.policy_version,
    );

    file.write_all(line.as_bytes())?;
    file.sync_data()?;

    Ok(digest)
}

pub fn receipt_digest(
    receipt: &TeardownReceipt,
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(AUDIT_LABEL);
    hasher.update(receipt.session_id_commitment);
    hasher.update(receipt.session_generation.to_be_bytes());
    hasher.update(receipt.reason_code.as_bytes());
    hasher.update([u8::from(receipt.key_handles_invalidated)]);
    hasher.update([u8::from(receipt.capability_revoked)]);
    hasher.update(receipt.policy_version.as_bytes());
    hasher.finalize().into()
}

fn hex(
    bytes: &[u8; 32],
) -> String {
    let mut output = String::with_capacity(64);

    for byte in bytes {
        use std::fmt::Write;
        write!(&mut output, "{byte:02x}").expect("string write");
    }

    output
}
