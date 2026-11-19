//! aln-to-rust-bridge
//!
//! Small helper library for loading ALN shards into strongly-typed Rust
//! structs. This crate keeps shard parsing logic in one place so guard
//! crates and kernels can share it.
//!
//! All code is `forbid(unsafe_code)` and edition 2024.

#![forbid(unsafe_code)]
#![deny(missing_docs)]

use std::fs;
use std::path::Path;

use serde::Deserialize;

/// Generic error type for ALN loading.
#[derive(Debug)]
pub enum AlnLoadError {
    /// Underlying IO error while reading the shard file.
    Io(std::io::Error),
    /// JSON / text deserialization error.
    Deserialize(String),
    /// Shard-specific invariant failure.
    Invariant(String),
}

impl From<std::io::Error> for AlnLoadError {
    fn from(e: std::io::Error) -> Self {
        AlnLoadError::Io(e)
    }
}

/// Metadata section for simple ALN shards.
///
/// This matches basic `meta` sections with id, version, and subjectid.
#[derive(Clone, Debug, Deserialize)]
pub struct AlnMeta {
    /// Shard identifier.
    pub id: String,
    /// Shard version string.
    pub version: String,
    /// Subject identifier (typically a Bostrom address or DID).
    pub subjectid: String,
}

/// Load an ALN shard from a path and deserialize it into `T`.
///
/// `T` is expected to be a struct that matches the JSON representation of
/// the shard content. Minimal shard-level invariants can be checked by
/// the caller after loading.
///
/// This function assumes that an upstream tool has converted the `.aln`
/// source into a JSON file with the same stem and `.json` extension.
pub fn load_aln_json<T, P>(path: P) -> Result<T, AlnLoadError>
where
    T: for<'de> Deserialize<'de>,
    P: AsRef<Path>,
{
    let data = fs::read_to_string(path)?;
    let value: T = serde_json::from_str(&data)
        .map_err(|e| AlnLoadError::Deserialize(e.to_string()))?;
    Ok(value)
}

/// Simple helper for checking a subject binding.
///
/// Many nanorobotics shards must bind to the primary host / Bostrom
/// address. This helper can be used in loader code to enforce that.
pub fn assert_subject_is(meta: &AlnMeta, expected_subject: &str) -> Result<(), AlnLoadError> {
    if meta.subjectid == expected_subject {
        Ok(())
    } else {
        Err(AlnLoadError::Invariant(format!(
            "subjectid mismatch: shard {} subject {}, expected {}",
            meta.id, meta.subjectid, expected_subject
        )))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Clone, Debug, Deserialize)]
    struct DummyShard {
        meta: AlnMeta,
        value: f32,
    }

    #[test]
    fn load_dummy_shard_from_json() {
        // This test assumes a small JSON file is present in the test
        // data directory. Adjust the path to your repo layout.
        let path = "tests/data/dummy-shard.json";
        let result = load_aln_json::<DummyShard, _>(path);
        // We only assert that deserialization happens; content checks
        // should be added once test data exists.
        assert!(result.is_ok());
    }

    #[test]
    fn subject_check_succeeds_for_expected_subject() {
        let meta = AlnMeta {
            id: "dummy".to_string(),
            version: "1.0.0".to_string(),
            subjectid: "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_string(),
        };
        assert!(assert_subject_is(&meta, "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7").is_ok());
    }

    #[test]
    fn subject_check_fails_for_wrong_subject() {
        let meta = AlnMeta {
            id: "dummy".to_string(),
            version: "1.0.0".to_string(),
            subjectid: "bostrom1other".to_string(),
        };
        let err = assert_subject_is(&meta, "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7");
        assert!(matches!(err, Err(AlnLoadError::Invariant(_))));
    }
}
