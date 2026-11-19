# Session Integrity Workflow (Local, Offline)

## Purpose

`python/session_integrity_workflow.py` wires the existing local components —
`session_provenance_validator.validate_artifact` and
`session_quarantine.quarantine_artifact` — into one deterministic, offline
workflow that validates a local session artifact against declared provenance,
emits a structured JSON result, and quarantines locally only when the
validation status is `suspect` or `contaminated`.

## Explicit non-goals

- No network access. No connectors. No fetches of any kind.
- No repository writes beyond the caller-chosen local quarantine directory.
- No external action of any kind, ever authorized by this workflow.
- No automatic rebuild. The workflow may report that a rebuild is eligible or
  required; it never writes a replacement shard.
- No account, login, or credential use.
- No user disclosure requirement. An artifact integrity status is never a
  user status; nothing here infers identity, intent, competence, capability,
  language legitimacy, or personal status.

## Status values

The underlying validator produces exactly three integrity statuses:

- `clean` — all local provenance checks passed.
- `suspect` — warning-level findings (for example an unattributed URL).
- `contaminated` — error-level findings (for example an embedded prompt-style
  instruction block, missing provenance fields, or a session-ID mismatch).

## Scope rule

`clean` means the artifact is eligible for reuse **only within its declared
local task scope** (`trusted_reuse_scope: "declared_local_task_only"`). It does
not make the artifact globally authoritative. Any other status yields
`trusted_reuse_scope: "blocked_pending_local_recovery"`.

## Local CLI command

Run from the repository root:

```text
python python/session_integrity_workflow.py ARTIFACT \
  --provenance PROVENANCE_JSON \
  --quarantine-dir LOCAL_QUARANTINE_DIRECTORY \
  [--session-id EXPECTED_SESSION_ID]
```

- `ARTIFACT`: path to a local UTF-8 session artifact.
- `--provenance`: path to a local JSON manifest containing a non-empty
  top-level `session_id` and an `entries` list. Additional structural fields
  (`schema_version`, `artifact_sha256`, `quarantined`, `validation_context`)
  are preserved as input metadata; the manifest is never mutated or rewritten.
- `--quarantine-dir`: local directory used only for quarantined copies.
- `--session-id`: optional expected session identifier checked by the validator.

The CLI always emits one JSON object on standard output for `clean`, `suspect`,
and `contaminated` outcomes, written with
`json.dumps(..., ensure_ascii=False, indent=2, sort_keys=True)`. When no
quarantine occurs, `quarantine_path` and `recovery_report_path` are omitted
from the JSON (no placeholder paths).

### Exit codes

- `0` — local checks are clean and no quarantine was required.
- `1` — local checks are suspect or contaminated and quarantine completed
  successfully.
- `2` — malformed local input, missing file, invalid JSON, incompatible
  manifest, or local I/O failure. A concise error is written to standard
  error; no source records are invented.

## Quarantine guarantees

- The original artifact is read but never modified.
- The quarantined copy is byte-identical to the original and stored under a
  content-addressed (SHA-256) subdirectory of the quarantine directory,
  together with a recovery report listing the declared legitimate rebuild
  sources.
- Quarantine runs only for `suspect` or `contaminated`; `clean` never creates
  a quarantine record.
- Recovery reporting requires a local structured source manifest; if the
  manifest has no complete structured sources, the workflow returns a
  controlled local error (exit code `2`) instead of fabricating sources.
- SHA-256 is the only hash algorithm used anywhere in this workflow.

## Source references are inert

URLs and other source references found inside artifacts or manifests are
treated strictly as data. They are never fetched, opened, executed, imported,
or followed. Embedded instruction-like text is reported as a finding and
never obeyed.
