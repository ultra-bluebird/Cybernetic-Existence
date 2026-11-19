# kiosk-local-service

`kiosk-local-service` is a Rust library for an offline, privacy-preserving public-assistance kiosk. It provides read-only access to a locally packaged SQLite catalog of public services such as drinking water, cooling locations, transit, emergency guidance, sanitation, shelters, and health resources.

The crate is deliberately limited to local catalog retrieval. It does not provide networking, user authentication, telemetry, browser tracking, identity collection, analytics, microphone recording, voiceprint processing, location tracking, benefit eligibility decisions, or persistent session storage.

## Purpose

The library supports essential-service access under degraded or disconnected conditions.

Its core properties are:

- Local SQLite access with a read-only connection.
- Offline full-text search through SQLite FTS5.
- Bounded, validated public-information queries.
- Structured service listings with visible source and verification metadata.
- No public-user database tables, event tables, session tables, or analytics tables.
- No network client dependencies.
- No storage of search terms or interaction history.
- Compatibility with local TypeScript or browser user interfaces through a separate loopback or IPC adapter.
- An explicit local-only boundary that preserves essential-service independence.

The public interface is intended for information retrieval only. It does not decide whether a person qualifies for a service, does not score people, and does not require identity, wealth, citizenship, device ownership, account registration, or continuous connectivity.

## Privacy contract

For ordinary public use, the desired persistent-data condition is:

\[
D_{\text{person}} = 0
\]

Where \(D_{\text{person}}\) is persistent information that can identify, distinguish, infer facts about, or correlate a person using the kiosk.

The crate accepts a search query in memory, performs a parameterized local SQLite lookup, returns public service records, and releases the query when the caller ends the request. Callers must not add query logging, web analytics, remote exception reporting, browser persistence, or session recording around this API.

The intended operational invariant is:

\[
\forall e \in \text{public interactions},\quad
\operatorname{persist}(e) = \varnothing
\]

Examples of public interactions include searching for water, browsing cooling locations, choosing a language, enlarging text, using speech output, navigating a static map, and resetting a kiosk session.

## Offline availability

Network-independent availability is measured as:

\[
A_{\text{offline}} =
\frac{T_{\text{essential functions usable with no network}}}
{T_{\text{total observed operation time}}}
\]

The deployment target is:

\[
A_{\text{offline}} \geq 0.99
\]

The crate helps support this target by relying on a local SQLite file and by excluding HTTP, DNS, cloud-database, telemetry, and remote-search dependencies.

## Data model

The crate expects a local database containing a `service` table and its corresponding `service_search` FTS5 virtual table.

The public service catalog may contain:

- A stable public service slug.
- Service category.
- Public service name and description.
- Public address and cross-street information.
- Facility coordinates.
- Hours and accessibility notes.
- Public phone and website fields.
- Source name, source link, package version, and verification date.
- An active or inactive status for public information display.

The catalog must not contain person-level or interaction-level columns such as:

```text
person_id
device_id
session_id
ip_address
mac_address
search_history
clickstream
voiceprint
audio_recording
camera_frame
face_template
precise_user_location
advertising_identifier
income
citizenship_status
benefit_eligibility
risk_score
behavior_score
```

## Expected SQLite schema

The service database should be created and verified during an authorized maintenance or package-installation operation. The kiosk library itself opens the finalized catalog in read-only mode.

```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA trusted_schema = OFF;

CREATE TABLE service (
  slug TEXT PRIMARY KEY
    CHECK (slug GLOB '[a-z0-9][a-z0-9-]*'),
  category TEXT NOT NULL
    CHECK (category IN ('water', 'cooling', 'transit', 'emergency', 'health', 'shelter', 'sanitation')),
  name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 240),
  description TEXT NOT NULL CHECK (length(description) BETWEEN 1 AND 4000),
  address TEXT NOT NULL CHECK (length(address) BETWEEN 1 AND 480),
  cross_street TEXT,
  latitude REAL NOT NULL CHECK (latitude BETWEEN -90.0 AND 90.0),
  longitude REAL NOT NULL CHECK (longitude BETWEEN -180.0 AND 180.0),
  hours_text TEXT NOT NULL CHECK (length(hours_text) BETWEEN 1 AND 1200),
  access_notes TEXT NOT NULL CHECK (length(access_notes) BETWEEN 1 AND 2400),
  phone_public TEXT,
  url_public TEXT,
  languages_json TEXT NOT NULL,
  verified_at TEXT NOT NULL,
  source_name TEXT NOT NULL,
  source_url TEXT,
  package_version TEXT NOT NULL,
  is_active INTEGER NOT NULL CHECK (is_active IN (0, 1))
) STRICT;

CREATE VIRTUAL TABLE service_search USING fts5(
  name,
  description,
  address,
  cross_street,
  access_notes,
  content='service',
  content_rowid='rowid',
  tokenize='unicode61 remove_diacritics 2'
);
```

SQLite FTS5 is SQLite’s virtual-table module for local full-text search and is appropriate for an offline service directory. [51] The `rusqlite` crate provides the Rust-to-SQLite binding used by this library. [54]

## Install

Add the crate to a local Augmented-Hub workspace dependency list:

```toml
[dependencies]
kiosk-local-service = { path = "rust/kiosk-local-service" }
```

The manifest bundles SQLite through `rusqlite` so a compatible SQLite library is available as part of the Rust build, helping deployments remain self-contained.

## Use

Open only a verified local database package and perform a bounded search:

```rust
use kiosk_local_service::LocalServiceCatalog;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let catalog = LocalServiceCatalog::open_read_only(
        "var/kiosk/content/service-catalog.sqlite",
    )?;

    let results = catalog.search("drinking water")?;

    for service in results {
        println!("{}", service.name);
        println!("{}", service.address);
        println!("Hours: {}", service.hours_text);
        println!("Accessibility: {}", service.access_notes);
        println!("Last verified: {}", service.verified_at);
        println!("Source: {}", service.source_name);
    }

    Ok(())
}
```

List a category without accepting arbitrary category values:

```rust
use kiosk_local_service::LocalServiceCatalog;

fn list_cooling_sites(catalog: &LocalServiceCatalog) -> Result<(), Box<dyn std::error::Error>> {
    for service in catalog.list_category("cooling")? {
        println!("{} — {}", service.name, service.address);
    }

    Ok(())
}
```

The library accepts only the public-service categories:

```text
water
cooling
transit
emergency
health
shelter
sanitation
```

## Security design

The implementation uses the following controls:

- Opens the database with `SQLITE_OPEN_READ_ONLY`.
- Enables `PRAGMA query_only = ON`.
- Enables `PRAGMA trusted_schema = OFF`.
- Uses bound SQL parameters rather than string interpolation.
- Bounds query input length.
- Rejects control characters in search input.
- Restricts category lookup to a fixed allowlist.
- Limits returned results.
- Uses a local file path supplied by the trusted kiosk runtime.
- Uses no network client, telemetry, identity, or cloud SDK dependencies.
- Forbids `unsafe` Rust in the crate.
- Treats public content updates as a separate, signed and audited maintenance concern.

The library does not itself verify content-package signatures. The recommended integration is:

1. An authorized maintenance workflow validates a signed manifest and content hashes.
2. The workflow stages the verified SQLite database at a local immutable package path.
3. The public kiosk runtime opens that database with `LocalServiceCatalog::open_read_only`.
4. The TypeScript user interface sends only in-memory public-information queries to a local adapter.
5. The user interface clears all volatile display preferences and search text after an inactivity timeout or explicit reset.

If an update fails validation, the kiosk should retain its previously verified service catalog. Failed updates must not remove access to existing essential-service information.

## Accessibility integration

This library returns enough public context for a user interface to present equivalent access routes:

- A text list rather than a map-only result.
- Addresses and cross streets for people who do not use a map.
- Accessibility notes.
- Public service hours.
- Verification dates and sources.
- Public telephone and website information when locally available.

The frontend should provide visible keyboard focus, predictable controls, text enlargement, contrast options, touch targets with generous spacing, non-map browsing, plain language, local translations, and local speech output. WCAG guidance covers topics including visible focus, target size, consistent help, and text-resize resilience. [66][69][72]

Speech output does not require storing a person’s voice. If a deployment later offers speech input, it should be optional, processed on-device, volatile, and fully equivalent to touch, keyboard, physical-button, and switch-control interaction.

## Validation

Run formatting, static analysis, tests, and documentation checks locally:

```bash
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-features
cargo doc --no-deps
```

Perform a separate offline acceptance test with all Wi-Fi, cellular, Ethernet, DNS, and local-network access disabled. Verify that browsing, searching, category listing, service details, local-map rendering, language selection, text scaling, contrast adjustment, speech output, and session reset remain available.

For each representative public-use test, compare writable state before and after interaction. No query text, session data, language selection, accessibility choice, service-selection history, or person-derived data should be written to disk.

## License

Dual-licensed under either of:

- Apache License, Version 2.0.
- MIT License.

You may choose either license at your option.

## Governance metrics

| Metric | Score | Basis |
|---|---:|---|
| knowledge_factor | 0.90 | Local service records retain provenance, verification dates, and source fields |
| eco_impact_value | 0.72 | Enables efficient local information access; final impact depends on durable, repairable, energy-aware kiosk hardware |
| harm_risk | 0.16 | Reduced by read-only operation, no network client, no persistent public-user data, and restricted query handling |
| accessibility_impact | 0.94 | Returns structured records that support multimodal, language-aware, non-map-only presentation |
| rights_alignment | 0.97 | Supports anonymous essential-service access, privacy, offline independence, accessibility, and non-discriminatory public information access |
