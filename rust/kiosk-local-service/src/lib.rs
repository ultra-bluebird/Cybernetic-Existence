use rusqlite::{params, Connection, OpenFlags};
use serde::Serialize;
use std::path::Path;
use thiserror::Error;

const MAX_QUERY_CHARS: usize = 120;
const MAX_RESULTS: usize = 25;

#[derive(Debug, Error)]
pub enum KioskError {
    #[error("the search text is empty")]
    EmptyQuery,

    #[error("the search text exceeds the maximum length")]
    QueryTooLong,

    #[error("the search text contains unsupported control characters")]
    InvalidQuery,

    #[error("database error: {0}")]
    Database(#[from] rusqlite::Error),
}

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct ServiceResult {
    pub slug: String,
    pub category: String,
    pub name: String,
    pub description: String,
    pub address: String,
    pub cross_street: Option<String>,
    pub latitude: f64,
    pub longitude: f64,
    pub hours_text: String,
    pub access_notes: String,
    pub phone_public: Option<String>,
    pub url_public: Option<String>,
    pub verified_at: String,
    pub source_name: String,
    pub source_url: Option<String>,
    pub package_version: String,
}

pub struct LocalServiceCatalog {
    connection: Connection,
}

impl LocalServiceCatalog {
    pub fn open_read_only(path: impl AsRef<Path>) -> Result<Self, KioskError> {
        let connection = Connection::open_with_flags(
            path,
            OpenFlags::SQLITE_OPEN_READ_ONLY
                | OpenFlags::SQLITE_OPEN_NO_MUTEX
                | OpenFlags::SQLITE_OPEN_URI,
        )?;

        connection.execute_batch(
            r#"
            PRAGMA query_only = ON;
            PRAGMA trusted_schema = OFF;
            PRAGMA foreign_keys = ON;
            PRAGMA temp_store = MEMORY;
            "#,
        )?;

        Ok(Self { connection })
    }

    pub fn search(&self, raw_query: &str) -> Result<Vec<ServiceResult>, KioskError> {
        let query = normalize_query(raw_query)?;
        let fts_query = to_prefix_fts_query(&query);

        let mut statement = self.connection.prepare(
            r#"
            SELECT
                s.slug,
                s.category,
                s.name,
                s.description,
                s.address,
                s.cross_street,
                s.latitude,
                s.longitude,
                s.hours_text,
                s.access_notes,
                s.phone_public,
                s.url_public,
                s.verified_at,
                s.source_name,
                s.source_url,
                s.package_version
            FROM service_search
            JOIN service AS s ON s.rowid = service_search.rowid
            WHERE service_search MATCH ?1
              AND s.is_active = 1
            ORDER BY bm25(service_search), s.name COLLATE NOCASE
            LIMIT ?2
            "#,
        )?;

        let rows = statement.query_map(params![fts_query, MAX_RESULTS as i64], |row| {
            Ok(ServiceResult {
                slug: row.get(0)?,
                category: row.get(1)?,
                name: row.get(2)?,
                description: row.get(3)?,
                address: row.get(4)?,
                cross_street: row.get(5)?,
                latitude: row.get(6)?,
                longitude: row.get(7)?,
                hours_text: row.get(8)?,
                access_notes: row.get(9)?,
                phone_public: row.get(10)?,
                url_public: row.get(11)?,
                verified_at: row.get(12)?,
                source_name: row.get(13)?,
                source_url: row.get(14)?,
                package_version: row.get(15)?,
            })
        })?;

        rows.collect::<Result<Vec<_>, _>>().map_err(KioskError::from)
    }

    pub fn list_category(&self, category: &str) -> Result<Vec<ServiceResult>, KioskError> {
        let permitted_category = normalize_category(category)?;

        let mut statement = self.connection.prepare(
            r#"
            SELECT
                slug,
                category,
                name,
                description,
                address,
                cross_street,
                latitude,
                longitude,
                hours_text,
                access_notes,
                phone_public,
                url_public,
                verified_at,
                source_name,
                source_url,
                package_version
            FROM service
            WHERE category = ?1
              AND is_active = 1
            ORDER BY name COLLATE NOCASE
            LIMIT ?2
            "#,
        )?;

        let rows = statement.query_map(params![permitted_category, MAX_RESULTS as i64], |row| {
            Ok(ServiceResult {
                slug: row.get(0)?,
                category: row.get(1)?,
                name: row.get(2)?,
                description: row.get(3)?,
                address: row.get(4)?,
                cross_street: row.get(5)?,
                latitude: row.get(6)?,
                longitude: row.get(7)?,
                hours_text: row.get(8)?,
                access_notes: row.get(9)?,
                phone_public: row.get(10)?,
                url_public: row.get(11)?,
                verified_at: row.get(12)?,
                source_name: row.get(13)?,
                source_url: row.get(14)?,
                package_version: row.get(15)?,
            })
        })?;

        rows.collect::<Result<Vec<_>, _>>().map_err(KioskError::from)
    }
}

fn normalize_query(raw_query: &str) -> Result<String, KioskError> {
    let query = raw_query.trim();

    if query.is_empty() {
        return Err(KioskError::EmptyQuery);
    }

    if query.chars().count() > MAX_QUERY_CHARS {
        return Err(KioskError::QueryTooLong);
    }

    if query.chars().any(char::is_control) {
        return Err(KioskError::InvalidQuery);
    }

    Ok(query.to_owned())
}

fn to_prefix_fts_query(query: &str) -> String {
    query
        .split_whitespace()
        .filter_map(|term| {
            let escaped = term.replace('"', "");
            (!escaped.is_empty()).then(|| format!("\"{escaped}\"*"))
        })
        .collect::<Vec<_>>()
        .join(" AND ")
}

fn normalize_category(category: &str) -> Result<&'static str, KioskError> {
    match category.trim().to_ascii_lowercase().as_str() {
        "water" => Ok("water"),
        "cooling" => Ok("cooling"),
        "transit" => Ok("transit"),
        "emergency" => Ok("emergency"),
        "health" => Ok("health"),
        "shelter" => Ok("shelter"),
        "sanitation" => Ok("sanitation"),
        _ => Err(KioskError::InvalidQuery),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_plain_language_search() {
        assert_eq!(
            normalize_query("  drinking water  ").expect("valid query"),
            "drinking water"
        );
    }

    #[test]
    fn rejects_empty_search() {
        assert!(matches!(normalize_query(" \n "), Err(KioskError::EmptyQuery)));
    }

    #[test]
    fn rejects_control_characters() {
        assert!(matches!(
            normalize_query("cooling\u{0000}center"),
            Err(KioskError::InvalidQuery)
        ));
    }

    #[test]
    fn produces_safe_prefix_query() {
        assert_eq!(
            to_prefix_fts_query("drinking water"),
            "\"drinking\"* AND \"water\"*"
        );
    }

    #[test]
    fn accepts_only_public_service_categories() {
        assert_eq!(normalize_category("WATER").expect("valid category"), "water");
        assert!(normalize_category("eligibility").is_err());
    }
}
