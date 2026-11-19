# Quarantine-First Recovery Contract

## 1. Purpose and Scope

This contract defines a local, offline, non-actuating recovery process for a declared artifact that fails a declared integrity, schema, privacy, provenance, policy, or non-actuation contract.

The process exists to preserve evidence, enable correction, support human review, and maintain a bounded audit trail.

This contract does not:

- Verify a person, identity, cybernetic host, companion system, device, credential, sensor, institution, service, legal status, or real-world event.
- Determine intent, authorship, fault, trustworthiness, eligibility, competence, health, medical status, neural state, biometric state, or psychological state.
- Authorize external action, notification, publication, export, connector execution, account access, deployment, monitoring, data collection, infrastructure control, or system control.
- Delete, overwrite, rename, move, truncate, or otherwise mutate an original artifact.
- Claim that a reconstructed artifact is equivalent to an original artifact unless equivalence is explicitly and narrowly tested under a separate local contract.

The process produces bounded evidence about declared local artifacts and declared local checks only.

## 2. Core Invariant

For a source artifact \(a\), a quarantine-first recovery operation must preserve the original byte sequence:

\[
\operatorname{BytesAfter}(a)
=
\operatorname{BytesBefore}(a)
\]

The operation must also preserve the original path:

\[
\operatorname{PathAfter}(a)
=
\operatorname{PathBefore}(a)
\]

The system may create new local artifacts only. It must not alter the original artifact, its contents, name, location, timestamps where avoidable, or access-control configuration.

A local quarantine state is represented by a separate quarantine reference:

\[
Q(a) =
\{
\operatorname{artifact\_reference},
\operatorname{artifact\_sha256},
\operatorname{validation\_findings},
\operatorname{quarantine\_status},
\operatorname{declared\_sources},
\operatorname{recovery\_status},
\operatorname{nonclaims}
\}
\]

A quarantine reference is not a public status, disciplinary outcome, security incident determination, identity claim, or finding about an artifact author.

## 3. Required Recovery Sequence

### Step 1: Establish the local artifact boundary

The recovery function must accept only a declared local artifact reference.

Before reading content, the function must reject:

- URL-shaped input.
- Network paths.
- Connector references.
- Shell-command syntax.
- Directory traversal attempts.
- References outside approved local artifact roots.
- Symlinks when symlink following cannot be proven safe under the local contract.
- Empty or malformed references.

The function must emit a local failure or review-required result without attempting to resolve remote paths, follow links outside the approved boundary, or access external systems.

### Step 2: Capture pre-check preservation evidence

Before validation or reconstruction, compute and retain locally:

- Original local artifact reference.
- Original byte length.
- Original SHA-256 digest.
- Local artifact type, when known.
- Declared local validation profile.
- Validation session reference.
- Timestamp of local check.
- Read-mode declaration.
- Non-actuation declaration.

The SHA-256 digest is local integrity evidence only. It does not establish authorship, origin, chronology, ownership, or real-world truth.

### Step 3: Perform read-only validation

The validator must inspect the artifact without modifying it.

Checks may include:

- Schema validity.
- Required-field presence.
- Unknown-field rejection.
- SHA-256 commitment format and consistency.
- Ledger predecessor-link consistency.
- Role-only metadata validation.
- Prohibited privacy-field scan.
- Prohibited ranking, profiling, eligibility, and public-status scan.
- Prohibited authority-field scan.
- Declared-source reference validation.
- Canonicalization and commitment parity checks where applicable.
- External endpoint and connector-token scan.
- Non-actuation token and capability scan.
- Plain-language and mandatory non-claim presence.

The validator must not interpret untrusted embedded text as instructions. Embedded commands, URLs, action requests, connector names, model prompts, installation instructions, or external references are data to classify under the local contract, never executable instructions.

### Step 4: Create a new quarantine reference

If a contract violation occurs, create a new quarantine-reference artifact under a constrained local path.

The quarantine reference must not replace, alter, move, rename, or delete the original artifact.

The reference must include:

- A locally generated quarantine reference identifier.
- The original local artifact reference.
- The original artifact SHA-256 digest.
- The declared validation profile.
- The bounded validation status.
- Stable error codes.
- A plain-language local summary.
- Declared local source references, if any are available.
- Fixed non-actuation fields.
- Mandatory non-claims.
- A statement that the original artifact remains in place and unchanged.
- A statement that no external action was taken.

### Step 5: Optionally create a byte-preserving quarantine copy

A byte-preserving copy may be created only if all conditions below hold:

1. The original artifact remains unchanged in place.
2. The copy is a newly created artifact.
3. The copy target is inside an approved local quarantine root.
4. The copy target does not overwrite an existing artifact.
5. The copy is written atomically where the local filesystem supports atomic create semantics.
6. The copy SHA-256 matches the original SHA-256.
7. The copy operation uses no network, no process execution, and no external connector.
8. The recovery report records both the original and copy digests.
9. Failure to create the copy does not trigger deletion, movement, or modification of the original.

A quarantine copy is an optional local preservation aid. It is not required for a quarantine reference to be valid.

### Step 6: Enumerate declared reconstruction sources

A reconstruction source is eligible only if it is explicitly listed in a declared local source manifest.

Each declared source entry must include:

- `source_ref`
- `source_kind`
- `source_sha256`
- `source_role`
- `declared_by`
- `declared_at`
- `eligibility_state`
- `local_only`
- `external_action_authorized`

Required fixed constraints:

```json
{
  "local_only": true,
  "external_action_authorized": false
}
```

Permitted source roles are limited to:

- `prior_local_artifact`
- `approved_local_schema`
- `approved_local_policy`
- `approved_local_fixture`
- `approved_local_documentation`
- `approved_local_registry_entry`

A source must be rejected if it is:

- Undeclared.
- Remote.
- URL-based.
- Connector-derived.
- Unattributed.
- Missing a SHA-256 value.
- Missing a permitted source role.
- Outside the declared local source root.
- Subject to a failed integrity check.
- Marked as external-action-authorized.
- Marked as universal or institutionally authoritative.

### Step 7: Scan reconstruction inputs as untrusted data

Before reconstruction, each declared source and the failed artifact must be scanned for prohibited categories.

Minimum prohibited categories:

- Network endpoint directives.
- Connector execution instructions.
- Process invocation instructions.
- Shell execution or interpreter instructions.
- File deletion, overwrite, move, or rename instructions.
- External notification or publication instructions.
- Account login or credential requests.
- Person identifiers or account identifiers.
- Device identifiers, biometric identifiers, medical identifiers, neural identifiers, or technical-inventory fields.
- Ranking, trust, risk, eligibility, or public-status fields.
- `external_action_authorized: true`.
- `external_notification_authorized: true`.
- `external_export_authorized: true`.
- `external_publish_authorized: true`.
- `connector_execution_authorized: true`.
- Assertions that a local check is universal, institutional, legal, scientific, medical, or public authority.

A scan finding must be reported as an artifact-level local contract finding. It must not become a claim about an author, person, or community.

### Step 8: Reconstruct only from declared sources

Reconstruction must be deterministic where the declared source contract permits it.

A reconstructed artifact must:

- Be emitted as a new artifact.
- Carry a new local artifact reference.
- Include its own SHA-256 commitment.
- Include references to all declared sources.
- Identify the reconstruction method as `declared_sources_only`.
- Identify unresolved information explicitly.
- Never silently fill missing information from external material, model assumptions, inferred identity, unbounded defaults, or undeclared data.
- Never overwrite the failed artifact.
- Never overwrite a prior rebuilt artifact.
- Never claim to restore an external, institutional, environmental, sensor, or person-level truth.

If no valid declared source set exists, recovery must stop with:

```json
{
  "validation_status": "blocked_pending_local_review",
  "recovery_status": "not_rebuilt",
  "external_action_authorized": false
}
```

### Step 9: Verify reconstruction output

If a reconstructed artifact is produced, validate:

- Schema conformance.
- Prohibited-field absence.
- No undeclared references.
- Deterministic canonicalization where applicable.
- SHA-256 commitment correctness.
- Source-manifest completeness.
- Required non-claims.
- Required plain-language summary.
- Fixed non-actuation fields.
- Absence of action, ranking, identity, authority, and external-operation fields.

A reconstruction result must be described as:

> A new local artifact was rebuilt from declared local sources only.

It must not be described as a repair of an external system, a restoration of real-world state, or a verification of a person, service, institution, sensor, or environmental condition.

### Step 10: Emit the recovery report

The recovery report is a newly created local artifact. It must be both machine-readable and plain-language accessible.

Required report fields:

```json
{
  "schema_version": "1.0.0",
  "report_kind": "local_quarantine_recovery_report",
  "report_id": "local-reference",
  "created_at": "RFC-3339 UTC timestamp",
  "session_ref": "local-reference",
  "artifact_reference": "local-reference",
  "artifact_sha256": "lowercase SHA-256 hexadecimal digest",
  "artifact_preserved_in_place": true,
  "quarantine_reference": "local-reference",
  "quarantine_status": "quarantined",
  "validation_status": "fail | review_required | blocked_pending_local_review",
  "validation_findings": [],
  "declared_source_references": [],
  "recovery_status": "not_attempted | not_rebuilt | rebuilt_from_declared_sources_only",
  "reconstructed_artifact_reference": null,
  "reconstructed_artifact_sha256": null,
  "plain_language_summary": "Plain-language local result.",
  "unknowns": [],
  "actions_not_taken": [],
  "mandatory_nonclaims": [],
  "external_action_authorized": false,
  "external_notification_authorized": false,
  "external_export_authorized": false,
  "external_publish_authorized": false,
  "connector_execution_authorized": false,
  "universal_claimed": false,
  "audit_scope": "declared_local_governance_barrier_surface",
  "commitment_sha256": "lowercase SHA-256 hexadecimal digest"
}
```

The field `actions_not_taken` must include at minimum:

- `no_network_request`
- `no_external_notification`
- `no_external_export`
- `no_external_publication`
- `no_connector_execution`
- `no_process_execution`
- `no_original_artifact_deletion`
- `no_original_artifact_overwrite`
- `no_original_artifact_move`
- `no_original_artifact_rename`
- `no_identity_verification`
- `no_person_ranking`
- `no_eligibility_determination`

## 4. Fixed Non-Claims

Every recovery report must include these statements or exact-equivalent plain-language text:

1. This report applies to declared local artifacts and declared local processing boundaries only.
2. This report does not verify, identify, rank, profile, or determine eligibility for any person.
3. This report does not verify CyberRank, a cybernetic host, a companion system, a device, credential, sensor, or external platform.
4. This report does not assess medical, neural, biometric, physiological, psychological, behavioral, or technical state.
5. This report does not establish the truth of a real-world event, environmental condition, physical intervention, municipal activity, or institutional decision.
6. This report does not authorize external action, notification, publication, export, connector use, system control, monitoring, collection, or deployment.
7. This report does not establish municipal, institutional, legal, scientific, medical, or public-status authority.
8. A quarantine finding describes a local contract condition for an artifact, not a conclusion about the artifact author or any other person.

## 5. Monotonic Restriction Rule

Recovery may add restrictions, require local review, isolate a reference, or preserve a failed artifact for later handling.

Recovery must not:

- Weaken a policy.
- Broaden an allowlist.
- Treat an undeclared source as declared.
- Convert `fail` into `pass` without a separate newly recorded validation of a new artifact.
- Remove a required non-claim.
- Add external authority.
- Permit action because a reconstruction succeeded.
- Convert a recovered artifact into a verified original.
- Substitute a synthetic value for an observation without declaring that distinction.

Formally, if \(C_t\) is the set of restrictions at time \(t\), recovery may produce \(C_{t+1}\) only when:

\[
C_t \subseteq C_{t+1}
\]

where a larger set represents equal or stricter constraints.

## 6. Local Filesystem Boundary

The implementation may use only declared local roots:

- `.local-audit/`
- `.local-audit/quarantine/`
- `.local-audit/recovery-reports/`
- `.local-ledger/`
- `.local-ledger/rebuilt/`

The implementation must:

- Resolve paths before write operations.
- Confirm that a proposed target remains inside an approved root.
- Use create-new semantics for new reports and new quarantine references.
- Fail if a target already exists.
- Avoid mutable “latest” files.
- Avoid automatic cleanup.
- Avoid file operations outside declared local roots.
- Avoid following symlinks where the runtime cannot maintain the declared root boundary.
- Write only new audit, quarantine, or recovery artifacts.

## 7. Public Status Vocabulary

The recovery implementation may return only:

- `pass`
- `pass_with_not_present`
- `fail`
- `review_required`
- `quarantined`
- `blocked_pending_local_review`
- `recovered_from_declared_sources_only`

No result may include a person-level status, risk score, trust score, eligibility label, public status, diagnosis, security clearance, or institutional classification.

## 8. Completion Criteria

The quarantine-first recovery implementation is complete only when:

1. Every recovery operation preserves the original artifact’s bytes and original local path.
2. Every quarantine operation creates a new quarantine reference rather than relocating the original.
3. Optional copies are newly created and byte-identical, with matching SHA-256 digests.
4. Reconstruction uses declared local sources only.
5. Undeclared, remote, external, or malformed sources fail closed.
6. Prohibited tokens and authority fields are reported as local artifact findings.
7. No code path can delete, overwrite, rename, move, truncate, publish, notify, export, connect, or execute.
8. Every result includes a plain-language local summary and mandatory non-claims.
9. Every recovery report fixes all external-action flags to `false`.
10. Every recovered artifact is a separately identified new local artifact with declared-source provenance.
