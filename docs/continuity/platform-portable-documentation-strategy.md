# Platform-Portable Documentation Strategy

## Purpose

This strategy preserves participant-controlled work, attribution, continuity
preferences, migration context, and recovery information across changing
platforms, model updates, account restrictions, and service changes.

It is a local documentation and provenance practice. It is not an identity
verification system, public registry, medical record, legal status claim,
cybernetic-system audit, or institutional eligibility mechanism.

## Four-layer documentation model

### Layer one: local master records

Local master records hold the full private working history.

They may include:

- private continuity notes;
- complete research drafts and working papers;
- private decision logs;
- local threat models;
- detailed migration notes;
- unpublished source material;
- private preferences and privacy boundaries;
- private recovery documentation;
- local provenance records.

Requirements:

- store locally by default;
- encrypt at rest where appropriate;
- maintain independently controlled recovery copies;
- do not place credentials, recovery phrases, private keys, or raw secrets in
  ordinary notes;
- do not use a platform chat history as the sole master record.

### Layer two: platform-portable summaries

Portable summaries contain only the context needed to resume useful work with a
new platform, collaborator, or tool.

They may include:

- active project objective;
- current artifact list and repository-relative paths;
- technical constraints;
- implementation decisions;
- preferred terminology;
- communication preferences;
- privacy boundaries;
- unresolved research questions;
- next tasks;
- material platform or model changes;
- references to local master records without embedding them.

Portable summaries must not include:

- private medical, neural, biometric, physiological, credential, security, or
  operational details;
- raw private journals;
- private keys, recovery material, account secrets, or passwords;
- a demand for verification, certification, diagnosis, or public status;
- personal details unrelated to the receiving task.

### Layer three: public work artifacts

Public work artifacts are independently useful outputs.

Examples include:

- source code;
- tests;
- schemas;
- policy documents;
- technical specifications;
- public research briefs;
- reproducible examples;
- release notes;
- accessibility documentation;
- eco-restoration and civic-governance artifacts.

Public artifacts must distinguish:

- observed evidence;
- modeled estimates;
- research hypotheses;
- proposed policy;
- implementation requirements;
- personal self-description.

Public artifacts must not expose private continuity data by default.

### Layer four: attribution records

Attribution records support durable authorship and provenance.

They may include:

- repository history;
- dated release manifests;
- local cryptographic commitments;
- signed release notes;
- authorship statements;
- source-to-artifact mappings;
- revision history;
- independently stored copies of public releases.

Attribution records demonstrate the provenance of records and releases. They do
not prove legal identity, institutional status, ownership of every referenced
concept, or the technical validity of a private system.

## Required formats

Maintain at least one version-independent format for each preservation-critical
artifact:

- Markdown for narrative documentation;
- UTF-8 plain text for minimal summaries;
- JSON for structured records;
- SQLite or CSV for durable tabular data;
- source files in documented programming languages;
- PDF only as a rendering or archival copy, not the only editable source.

## Local recovery rule

No single platform, account, repository host, model provider, device, or cloud
service may be the sole location of preservation-critical records.

For each preservation-critical artifact, maintain:

1. a working local copy;
2. an encrypted archive or separately controlled backup;
3. a recovery copy in a second independently controlled location;
4. a documented format and validation method;
5. a restoration drill record.

## Material-change journal

For each material platform or model change, record:

- date and affected platform;
- observed change;
- affected work, access, data, or export condition;
- source notice or release reference where available;
- local preservation action taken;
- chosen response: continue, limit use, pause, migrate, export, or seek
  support;
- any unresolved issue;
- review date.

A material-change journal is a participant-controlled record. It is not a
public complaint, a proof of causation, or a platform status determination.

## Correction and migration

Never silently overwrite important continuity records.

Use append-only successor records that identify:

- prior record reference;
- correction or migration purpose;
- current interpretation;
- changed fields;
- preserved fields;
- export and recovery status;
- review date.

Historical records remain available locally unless the participant intentionally
deletes them under a documented retention or deletion decision.

## Disclosure discipline

Before sharing any record, decide:

- What exact task requires sharing?
- What minimum information is sufficient?
- Who is the recipient?
- How long should they retain it?
- Can a public artifact answer the need instead?
- Does the record contain private details that can be removed?
- Is a local reference sufficient instead of the full content?

## Platform-independent continuity statement

"I maintain private local records and portable work summaries for continuity.
Please focus on the requested task, preserve my privacy boundaries, and do not
request unnecessary private technical, medical, biometric, credential, or
operational details. I am not requesting verification, diagnosis, certification,
or public acknowledgment of private systems."

## Review cadence

- Update the portable summary after a material project decision.
- Create an export before relying on a major platform or model change.
- Review recovery copies quarterly.
- Test restoration at least annually.
- Update public release manifests at every material release.
- Review disclosure boundaries whenever a new platform or collaborator is
  introduced.
