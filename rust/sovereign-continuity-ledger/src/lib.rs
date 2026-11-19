use rusqlite::{params, Connection, OptionalExtension};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;
use std::fmt;
use std::time::{SystemTime, UNIX_EPOCH};

const SHA256_HEX_LENGTH: usize = 64;
const MAX_PARENTS: usize = 16;
const MAX_LABEL_LENGTH: usize = 160;
const MAX_SUMMARY_LENGTH: usize = 2_000;
const MAX_EXTERNAL_REFERENCE_LENGTH: usize = 512;

#[derive(Debug)]
pub enum LedgerError {
    InvalidField { field: &'static str, reason: &'static str },
    Serialization(serde_json::Error),
    Database(rusqlite::Error),
    Clock(std::time::SystemTimeError),
    ParentNotFound(String),
    DuplicateParent(String),
    CheckpointAlreadyExists(String),
    CheckpointNotFound(String),
    IntegrityViolation { checkpoint_id: String, reason: String },
}

impl fmt::Display for LedgerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidField { field, reason } => write!(f, "invalid {field}: {reason}"),
            Self::Serialization(error) => write!(f, "serialization error: {error}"),
            Self::Database(error) => write!(f, "database error: {error}"),
            Self::Clock(error) => write!(f, "clock error: {error}"),
            Self::ParentNotFound(parent_id) => write!(f, "parent checkpoint not found: {parent_id}"),
            Self::DuplicateParent(parent_id) => write!(f, "duplicate parent checkpoint: {parent_id}"),
            Self::CheckpointAlreadyExists(checkpoint_id) => {
                write!(f, "checkpoint already exists: {checkpoint_id}")
            }
            Self::CheckpointNotFound(checkpoint_id) => write!(f, "checkpoint not found: {checkpoint_id}"),
            Self::IntegrityViolation {
                checkpoint_id,
                reason,
            } => write!(f, "integrity violation for {checkpoint_id}: {reason}"),
        }
    }
}

impl std::error::Error for LedgerError {}

impl From<serde_json::Error> for LedgerError {
    fn from(error: serde_json::Error) -> Self {
        Self::Serialization(error)
    }
}

impl From<rusqlite::Error> for LedgerError {
    fn from(error: rusqlite::Error) -> Self {
        Self::Database(error)
    }
}

impl From<std::time::SystemTimeError> for LedgerError {
    fn from(error: std::time::SystemTimeError) -> Self {
        Self::Clock(error)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContinuityEventKind {
    Reflection,
    LearningInterval,
    PlatformMigration,
    ModelUpdate,
    InstitutionalChange,
    AccessChange,
    AttributionRecord,
    ConsentBoundaryChange,
    RecoveryCheckpoint,
    Other,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContinuityCheckpoint {
    pub checkpoint_id: String,
    pub created_at_unix_seconds: i64,
    pub event_kind: ContinuityEventKind,
    pub summary: String,
    pub continuity_label: String,
    pub parent_checkpoint_ids: Vec<String>,
    pub external_reference: Option<String>,
    pub schema_version: u16,
    pub content_sha256_hex: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
struct CheckpointCommitment<'a> {
    created_at_unix_seconds: i64,
    event_kind: &'a ContinuityEventKind,
    summary: &'a str,
    continuity_label: &'a str,
    parent_checkpoint_ids: &'a [String],
    external_reference: &'a Option<String>,
    schema_version: u16,
}

impl ContinuityCheckpoint {
    pub fn new(
        created_at_unix_seconds: i64,
        event_kind: ContinuityEventKind,
        summary: impl Into<String>,
        continuity_label: impl Into<String>,
        mut parent_checkpoint_ids: Vec<String>,
        external_reference: Option<String>,
    ) -> Result<Self, LedgerError> {
        let summary = summary.into();
        let continuity_label = continuity_label.into();

        validate_nonempty("summary", &summary)?;
        validate_max_length("summary", &summary, MAX_SUMMARY_LENGTH)?;
        validate_nonempty("continuity_label", &continuity_label)?;
        validate_max_length("continuity_label", &continuity_label, MAX_LABEL_LENGTH)?;

        if parent_checkpoint_ids.len() > MAX_PARENTS {
            return Err(LedgerError::InvalidField {
                field: "parent_checkpoint_ids",
                reason: "too many parent checkpoints",
            });
        }

        parent_checkpoint_ids.sort();

        let mut parent_ids = BTreeSet::new();
        for parent_checkpoint_id in &parent_checkpoint_ids {
            validate_sha256_hex("parent_checkpoint_ids", parent_checkpoint_id)?;
            if !parent_ids.insert(parent_checkpoint_id.clone()) {
                return Err(LedgerError::DuplicateParent(parent_checkpoint_id.clone()));
            }
        }

        if let Some(reference) = &external_reference {
            validate_max_length(
                "external_reference",
                reference,
                MAX_EXTERNAL_REFERENCE_LENGTH,
            )?;
        }

        let schema_version = 1;
        let commitment = CheckpointCommitment {
            created_at_unix_seconds,
            event_kind: &event_kind,
            summary: &summary,
            continuity_label: &continuity_label,
            parent_checkpoint_ids: &parent_checkpoint_ids,
            external_reference: &external_reference,
            schema_version,
        };

        let canonical_bytes = serde_json::to_vec(&commitment)?;
        let content_sha256_hex = sha256_hex(&canonical_bytes);

        Ok(Self {
            checkpoint_id: content_sha256_hex.clone(),
            created_at_unix_seconds,
            event_kind,
            summary,
            continuity_label,
            parent_checkpoint_ids,
            external_reference,
            schema_version,
            content_sha256_hex,
        })
    }

    pub fn verify_self_commitment(&self) -> Result<(), LedgerError> {
        validate_sha256_hex("checkpoint_id", &self.checkpoint_id)?;
        validate_sha256_hex("content_sha256_hex", &self.content_sha256_hex)?;

        if self.checkpoint_id != self.content_sha256_hex {
            return Err(LedgerError::IntegrityViolation {
                checkpoint_id: self.checkpoint_id.clone(),
                reason: "checkpoint_id must equal content_sha256_hex".to_owned(),
            });
        }

        let mut parents = self.parent_checkpoint_ids.clone();
        parents.sort();

        if parents != self.parent_checkpoint_ids {
            return Err(LedgerError::IntegrityViolation {
                checkpoint_id: self.checkpoint_id.clone(),
                reason: "parent identifiers are not canonically sorted".to_owned(),
            });
        }

        let commitment = CheckpointCommitment {
            created_at_unix_seconds: self.created_at_unix_seconds,
            event_kind: &self.event_kind,
            summary: &self.summary,
            continuity_label: &self.continuity_label,
            parent_checkpoint_ids: &self.parent_checkpoint_ids,
            external_reference: &self.external_reference,
            schema_version: self.schema_version,
        };

        let expected = sha256_hex(&serde_json::to_vec(&commitment)?);

        if expected != self.content_sha256_hex {
            return Err(LedgerError::IntegrityViolation {
                checkpoint_id: self.checkpoint_id.clone(),
                reason: "content commitment does not match checkpoint fields".to_owned(),
            });
        }

        Ok(())
    }
}

pub struct SovereignContinuityLedger {
    connection: Connection,
}

impl SovereignContinuityLedger {
    pub fn open(path: impl AsRef<std::path::Path>) -> Result<Self, LedgerError> {
        let connection = Connection::open(path)?;
        let ledger = Self { connection };
        ledger.initialize()?;
        Ok(ledger)
    }

    pub fn open_in_memory() -> Result<Self, LedgerError> {
        let connection = Connection::open_in_memory()?;
        let ledger = Self { connection };
        ledger.initialize()?;
        Ok(ledger)
    }

    pub fn append(
        &self,
        event_kind: ContinuityEventKind,
        summary: impl Into<String>,
        continuity_label: impl Into<String>,
        parent_checkpoint_ids: Vec<String>,
        external_reference: Option<String>,
    ) -> Result<ContinuityCheckpoint, LedgerError> {
        let created_at_unix_seconds = current_unix_seconds()?;
        let checkpoint = ContinuityCheckpoint::new(
            created_at_unix_seconds,
            event_kind,
            summary,
            continuity_label,
            parent_checkpoint_ids,
            external_reference,
        )?;

        self.append_checkpoint(&checkpoint)?;
        Ok(checkpoint)
    }

    pub fn append_checkpoint(&self, checkpoint: &ContinuityCheckpoint) -> Result<(), LedgerError> {
        checkpoint.verify_self_commitment()?;

        for parent_checkpoint_id in &checkpoint.parent_checkpoint_ids {
            if !self.checkpoint_exists(parent_checkpoint_id)? {
                return Err(LedgerError::ParentNotFound(parent_checkpoint_id.clone()));
            }
        }

        let inserted_rows = self.connection.execute(
            "
            INSERT INTO continuity_checkpoints (
                checkpoint_id,
                created_at_unix_seconds,
                event_kind_json,
                summary,
                continuity_label,
                parent_checkpoint_ids_json,
                external_reference,
                schema_version,
                content_sha256_hex
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
            ",
            params![
                checkpoint.checkpoint_id,
                checkpoint.created_at_unix_seconds,
                serde_json::to_string(&checkpoint.event_kind)?,
                checkpoint.summary,
                checkpoint.continuity_label,
                serde_json::to_string(&checkpoint.parent_checkpoint_ids)?,
                checkpoint.external_reference,
                checkpoint.schema_version,
                checkpoint.content_sha256_hex,
            ],
        );

        match inserted_rows {
            Ok(1) => Ok(()),
            Ok(_) => Err(LedgerError::IntegrityViolation {
                checkpoint_id: checkpoint.checkpoint_id.clone(),
                reason: "unexpected insert count".to_owned(),
            }),
            Err(rusqlite::Error::SqliteFailure(_, Some(message)))
                if message.contains("UNIQUE constraint failed") =>
            {
                Err(LedgerError::CheckpointAlreadyExists(
                    checkpoint.checkpoint_id.clone(),
                ))
            }
            Err(error) => Err(LedgerError::Database(error)),
        }
    }

    pub fn get(
        &self,
        checkpoint_id: &str,
    ) -> Result<ContinuityCheckpoint, LedgerError> {
        validate_sha256_hex("checkpoint_id", checkpoint_id)?;

        let row = self
            .connection
            .query_row(
                "
                SELECT
                    checkpoint_id,
                    created_at_unix_seconds,
                    event_kind_json,
                    summary,
                    continuity_label,
                    parent_checkpoint_ids_json,
                    external_reference,
                    schema_version,
                    content_sha256_hex
                FROM continuity_checkpoints
                WHERE checkpoint_id = ?1
                ",
                params![checkpoint_id],
                |row| {
                    let event_kind_json: String = row.get(2)?;
                    let parent_checkpoint_ids_json: String = row.get(5)?;

                    Ok(ContinuityCheckpoint {
                        checkpoint_id: row.get(0)?,
                        created_at_unix_seconds: row.get(1)?,
                        event_kind: serde_json::from_str(&event_kind_json).map_err(
                            |error| {
                                rusqlite::Error::FromSqlConversionFailure(
                                    event_kind_json.len(),
                                    rusqlite::types::Type::Text,
                                    Box::new(error),
                                )
                            },
                        )?,
                        summary: row.get(3)?,
                        continuity_label: row.get(4)?,
                        parent_checkpoint_ids: serde_json::from_str(&parent_checkpoint_ids_json)
                            .map_err(|error| {
                                rusqlite::Error::FromSqlConversionFailure(
                                    parent_checkpoint_ids_json.len(),
                                    rusqlite::types::Type::Text,
                                    Box::new(error),
                                )
                            })?,
                        external_reference: row.get(6)?,
                        schema_version: row.get(7)?,
                        content_sha256_hex: row.get(8)?,
                    })
                },
            )
            .optional()?;

        row.ok_or_else(|| LedgerError::CheckpointNotFound(checkpoint_id.to_owned()))
    }

    pub fn verify_integrity(&self) -> Result<(), LedgerError> {
        let mut statement = self.connection.prepare(
            "
            SELECT checkpoint_id
            FROM continuity_checkpoints
            ORDER BY created_at_unix_seconds ASC, checkpoint_id ASC
            ",
        )?;

        let checkpoint_ids = statement
            .query_map([], |row| row.get::<_, String>(0))?
            .collect::<Result<Vec<_>, _>>()?;

        for checkpoint_id in checkpoint_ids {
            let checkpoint = self.get(&checkpoint_id)?;
            checkpoint.verify_self_commitment()?;

            for parent_checkpoint_id in &checkpoint.parent_checkpoint_ids {
                if !self.checkpoint_exists(parent_checkpoint_id)? {
                    return Err(LedgerError::IntegrityViolation {
                        checkpoint_id: checkpoint.checkpoint_id.clone(),
                        reason: format!("parent does not exist: {parent_checkpoint_id}"),
                    });
                }

                let parent = self.get(parent_checkpoint_id)?;

                if parent.created_at_unix_seconds > checkpoint.created_at_unix_seconds {
                    return Err(LedgerError::IntegrityViolation {
                        checkpoint_id: checkpoint.checkpoint_id.clone(),
                        reason: format!(
                            "parent timestamp occurs after child timestamp: {parent_checkpoint_id}"
                        ),
                    });
                }
            }
        }

        Ok(())
    }

    pub fn export_json(&self) -> Result<String, LedgerError> {
        let mut statement = self.connection.prepare(
            "
            SELECT checkpoint_id
            FROM continuity_checkpoints
            ORDER BY created_at_unix_seconds ASC, checkpoint_id ASC
            ",
        )?;

        let checkpoint_ids = statement
            .query_map([], |row| row.get::<_, String>(0))?
            .collect::<Result<Vec<_>, _>>()?;

        let mut checkpoints = Vec::with_capacity(checkpoint_ids.len());
        for checkpoint_id in checkpoint_ids {
            checkpoints.push(self.get(&checkpoint_id)?);
        }

        Ok(serde_json::to_string_pretty(&checkpoints)?)
    }

    fn initialize(&self) -> Result<(), LedgerError> {
        self.connection.execute_batch(
            "
            PRAGMA foreign_keys = ON;
            PRAGMA journal_mode = WAL;
            PRAGMA secure_delete = ON;

            CREATE TABLE IF NOT EXISTS continuity_checkpoints (
                checkpoint_id TEXT PRIMARY KEY NOT NULL,
                created_at_unix_seconds INTEGER NOT NULL,
                event_kind_json TEXT NOT NULL,
                summary TEXT NOT NULL,
                continuity_label TEXT NOT NULL,
                parent_checkpoint_ids_json TEXT NOT NULL,
                external_reference TEXT,
                schema_version INTEGER NOT NULL,
                content_sha256_hex TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS continuity_checkpoints_created_at_index
                ON continuity_checkpoints(created_at_unix_seconds, checkpoint_id);
            ",
        )?;

        Ok(())
    }

    fn checkpoint_exists(&self, checkpoint_id: &str) -> Result<bool, LedgerError> {
        let exists = self
            .connection
            .query_row(
                "SELECT EXISTS(SELECT 1 FROM continuity_checkpoints WHERE checkpoint_id = ?1)",
                params![checkpoint_id],
                |row| row.get::<_, bool>(0),
            )?;

        Ok(exists)
    }
}

fn sha256_hex(bytes: &[u8]) -> String {
    let digest = Sha256::digest(bytes);
    let mut output = String::with_capacity(SHA256_HEX_LENGTH);

    for byte in digest {
        use std::fmt::Write;
        let _ = write!(&mut output, "{byte:02x}");
    }

    output
}

fn current_unix_seconds() -> Result<i64, LedgerError> {
    let seconds = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();

    i64::try_from(seconds).map_err(|_| LedgerError::InvalidField {
        field: "created_at_unix_seconds",
        reason: "current timestamp exceeds signed 64-bit range",
    })
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), LedgerError> {
    if value.trim().is_empty() {
        return Err(LedgerError::InvalidField {
            field,
            reason: "must not be empty",
        });
    }

    Ok(())
}

fn validate_max_length(
    field: &'static str,
    value: &str,
    maximum_length: usize,
) -> Result<(), LedgerError> {
    if value.chars().count() > maximum_length {
        return Err(LedgerError::InvalidField {
            field,
            reason: "exceeds maximum character length",
        });
    }

    Ok(())
}

fn validate_sha256_hex(field: &'static str, value: &str) -> Result<(), LedgerError> {
    if value.len() != SHA256_HEX_LENGTH || !value.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(LedgerError::InvalidField {
            field,
            reason: "must be a lowercase-or-uppercase 64-character SHA-256 hexadecimal digest",
        });
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn append_and_verify_a_two_checkpoint_chain() {
        let ledger = SovereignContinuityLedger::open_in_memory().expect("ledger must open");

        let root = ledger
            .append(
                ContinuityEventKind::LearningInterval,
                "Completed a self-authored research interval and preserved a local summary.",
                "daily-continuity",
                Vec::new(),
                None,
            )
            .expect("root checkpoint must append");

        let migration = ledger
            .append(
                ContinuityEventKind::PlatformMigration,
                "Migrated a locally exported research record to a new workflow.",
                "migration-boundary",
                vec![root.checkpoint_id.clone()],
                Some("local-export-v1".to_owned()),
            )
            .expect("child checkpoint must append");

        assert_eq!(migration.parent_checkpoint_ids, vec![root.checkpoint_id]);
        ledger.verify_integrity().expect("ledger must verify");
    }

    #[test]
    fn rejects_unknown_parent() {
        let ledger = SovereignContinuityLedger::open_in_memory().expect("ledger must open");

        let unknown_parent = "a".repeat(SHA256_HEX_LENGTH);

        let error = ledger
            .append(
                ContinuityEventKind::ModelUpdate,
                "Observed a material model behavior change.",
                "model-change",
                vec![unknown_parent],
                None,
            )
            .expect_err("unknown parent must be rejected");

        assert!(matches!(error, LedgerError::ParentNotFound(_)));
    }

    #[test]
    fn content_change_invalidates_commitment() {
        let checkpoint = ContinuityCheckpoint::new(
            1_700_000_000,
            ContinuityEventKind::Reflection,
            "Original continuity note.",
            "reflection",
            Vec::new(),
            None,
        )
        .expect("checkpoint must construct");

        let mut altered = checkpoint;
        altered.summary = "Substituted continuity note.".to_owned();

        let error = altered
            .verify_self_commitment()
            .expect_err("altered content must fail");

        assert!(matches!(error, LedgerError::IntegrityViolation { .. }));
    }

    #[test]
    fn export_is_portable_json() {
        let ledger = SovereignContinuityLedger::open_in_memory().expect("ledger must open");

        ledger
            .append(
                ContinuityEventKind::AttributionRecord,
                "Recorded a locally maintained project milestone.",
                "attribution",
                Vec::new(),
                None,
            )
            .expect("checkpoint must append");

        let export = ledger.export_json().expect("export must succeed");
        let parsed: Vec<ContinuityCheckpoint> =
            serde_json::from_str(&export).expect("export must be valid JSON");

        assert_eq!(parsed.len(), 1);
        parsed[0]
            .verify_self_commitment()
            .expect("exported checkpoint must verify");
    }
}
