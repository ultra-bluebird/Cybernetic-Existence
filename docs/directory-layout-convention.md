# Directory Layout Convention

## Status and purpose

**Document status:** Draft governance and repository-layout convention  
**Convention version:** 1.0.0  
**Applies to:** `mk-bluebird/Augmented-Hub` and `mk-bluebird/Skynet`  
**Primary consumers:**

- `manifests/repo-relative-path-index.json`
- `manifests/artifact-metadata-registry.json`
- `schemas/artifact-repo-target.schema.json`
- `tests/test_cross_repo_references.py`
- `tests/test_cross_artifact_consistency.py`

This convention defines the intended repository-relative directory layout for governed artifacts across the two repository targets:

```text
mk-bluebird/Augmented-Hub
mk-bluebird/Skynet
```

It establishes:

- Which directories are recognized for governed artifacts.
- The purpose of each recognized directory.
- How artifact paths are expressed.
- How ownership is declared.
- How cross-repository references are permitted.
- How CI detects misplaced, ambiguous, absolute, remote, or unlisted references.
- How unverified paths remain distinct from verified repository state.

This convention is a planning and governance contract. It does not establish that any listed directory or artifact currently exists in either repository. It does not inspect, clone, access, mutate, synchronize, publish, or deploy a repository.

## Non-authorization notice

This document defines internal repository-layout conventions only.

It does not authorize:

- Repository inspection, cloning, checkout, mutation, file creation, deletion, commit, merge, branch, tag, release, deployment, or synchronization.
- External system access, connector activation, API access, database access, credential use, key handling, account access, or network activity.
- Publication, posting, sending, notification, platform contact, data transfer, or external communication.
- Field activity, ecological intervention, weather modification, infrastructure control, public alerting, or operational-system control.
- Identity verification, eligibility determination, representation, institutional-status determination, medical assessment, neural assessment, augmentation assessment, or credibility assessment.
- Use of a directory declaration as proof that a file exists, is current, has passed validation, is adopted, is repository-persisted, or is available for use.

\[
\text{directory convention}
\not\Rightarrow
\text{repository access, repository mutation, or external authority}
\]

Any action affecting a repository or an external system requires separately scoped, explicit authorization under the applicable process.

## Core principles

### Repository-relative paths only

All governed references must use POSIX-style repository-relative paths.

Allowed:

```text
docs/charter.md
policies/capability-boundary.md
schemas/research-output-record.schema.json
manifests/forward-progress-registry.json
src/governance/foundation_gate.py
tests/test_cross_repo_references.py
```

Not allowed:

```text
/absolute/path/to/file
C:\repository\schemas\artifact.schema.json
../schemas/other.schema.json
[https://example.invalid/repository/schema.json](https://example.invalid/repository/schema.json)
git@host.example:organization/repository.git
```

A declared repository-relative path is governance metadata only. It is not evidence that the file exists, that a file is current, that the file was inspected, or that the file is compatible with a consuming module.

### One owning repository

Every governed artifact must declare exactly one owning repository:

```text
mk-bluebird/Augmented-Hub
```

or:

```text
mk-bluebird/Skynet
```

A governed artifact may reference another repository only through a bounded, declared cross-repository relationship.

A file must not be assigned to an unlisted repository, an ambiguous repository alias, a remote URL, a local absolute path, or a parent-traversal path.

### One destination directory

Every governed artifact must declare:

- Its repository-relative `path`.
- Its `destination_directory`.
- Its owning `repo_target`.
- Its current `schema_version`, or `not_versioned` where no independent schema version applies.
- Its review status.
- Its last verification reference, which may be `null` when verification has not been recorded.

The `destination_directory` must equal the parent directory of `path`.

Example:

```json
{
  "repo_target": "mk-bluebird/Augmented-Hub",
  "path": "src/governance/foundation_gate.py",
  "destination_directory": "src/governance",
  "schema_version": "not_versioned",
  "review_status": "draft",
  "last_verification_reference": null
}
```

### No implicit cross-repository access

A reference crossing from one repository target to the other must be declared in both of the following places:

1. The source artifact’s `cross_repo_references_allowed` declaration.
2. `manifests/repo-relative-path-index.json`, where the target artifact path and owning repository are listed.

A cross-repository declaration does not:

- Grant repository access.
- Verify remote or local file existence.
- Permit mutation.
- Authorize syncing, copying, publishing, deployment, or transfer.
- Establish implementation compatibility beyond the declared metadata relationship.

### Fail closed on ambiguity

The following conditions must produce a structural block in a validator or CI check:

- An artifact has no `repo_target`.
- An artifact has an unsupported `repo_target`.
- An artifact path is absolute.
- An artifact path uses parent traversal.
- An artifact path begins outside a recognized root directory.
- A destination directory does not match the artifact path’s parent directory.
- A cross-repository reference targets an unlisted path.
- A cross-repository reference targets an unlisted repository.
- A path maps to more than one repository target without an explicit disambiguation record.
- A remote URL is used where a repository-relative governed reference is required.
- A schema references an artifact in another repository without that repository appearing in `cross_repo_references_allowed`.
- A governed artifact lacks a current version declaration or explicit `not_versioned` marker.

A structural block is a visible metadata or compatibility condition. It does not establish fault, identity, intent, authority, or repository state.

## Repository ownership model

The two repositories have complementary but distinct responsibilities.

| Repository target | Primary responsibility | Typical governed content |
|---|---|---|
| `mk-bluebird/Augmented-Hub` | Rights-centered governance, privacy, accessibility, consent, provenance, artifact controls, AI-chat safeguards, schemas, tests, policy contracts, metadata registries | Policies, governance schemas, manifests, chat modules, validators, tests, enums, templates |
| `mk-bluebird/Skynet` | Research-output composition, model provenance, posterior checkpoints, uncertainty, calibration eligibility, research workflows, and related governed research artifacts | Research-output schemas, model checkpoints, research manifests, composition contracts, calibration records, research tests |

A repository target identifies ownership for governance purposes. It does not imply that the repository is active, public, accessible, installed locally, inspected, validated, or authorized for modification.

## Recognized directories

The following top-level directories are recognized across both repositories.

| Directory | Allowed content | Typical extensions | Ownership and placement rule |
|---|---|---|---|
| `docs/` | Human-readable specifications, charters, process documents, architecture notes, protocol documents, directory conventions | `.md` | Place narrative governance, research-process, and user-facing documentation here |
| `policies/` | Machine-adjacent or human-readable policy documents and Rego policy files | `.md`, `.rego`, `.json` | Place capability, privacy, access, correction, consent, retention, and governance policies here |
| `schemas/` | JSON Schema contracts and related schema documents | `.schema.json`, `.json` | Place versioned structured-data contracts here |
| `manifests/` | Machine-readable planning, registry, continuity, index, eligibility, and metadata records | `.json` | Place artifact registries, path indexes, planned-artifact records, and continuity manifests here |
| `enums/` | Shared controlled vocabularies and enum registry guidance | `.json`, `.md` | Place canonical enum values and enum version guidance here |
| `src/` | Production local source modules | `.py`, `.ts`, `.js`, `.lua`, `.cpp`, `.java`, `.kt` | Place implementation code under a language- or domain-appropriate subtree |
| `tests/` | Unit, integration, mutation, schema, policy, and consistency tests | `.py`, `.ts`, `.js`, `.lua`, `.cpp`, `.java`, `.kt` | Place non-destructive tests here |
| `rego/` | Standalone Rego policy modules | `.rego` | Use when a Rego module is not grouped beneath `policies/` |
| `lua/` | Lua implementation modules | `.lua` | Use for Lua source intended as a governed artifact |
| `cpp/` | C++ implementation modules | `.cpp`, `.hpp`, `.h` | Use for C++ source intended as a governed artifact |
| `java/` | Java implementation modules | `.java` | Use for Java source intended as a governed artifact |
| `kotlin/` | Kotlin implementation modules | `.kt`, `.kts` | Use for Kotlin source intended as a governed artifact |
| `python/` | Python application or library modules outside the common `src/` tree | `.py` | Use only when a repository chooses a language-root layout; do not duplicate the same module under `src/` |
| `javascript/` | JavaScript implementation modules outside the common `src/` tree | `.js`, `.mjs`, `.cjs` | Use only when a repository chooses a language-root layout |
| `typescript/` | TypeScript implementation modules outside the common `src/` tree | `.ts`, `.tsx` | Use only when a repository chooses a language-root layout |
| `web/` | Static web resources, browser-facing assets, HTML documents, and related styles or scripts | `.html`, `.css`, `.js`, `.ts` | Place web-facing governed assets here |
| `templates/` | Reusable non-executing document, report, and response templates | `.txt`, `.md`, `.json` | Place AI-chat, review, notice, and governance templates here |

## Standard source subtrees

The preferred source layout for common local implementation modules is:

```text
src/
  chat/
  governance/
  shared/
  community/
```

| Source subtree | Purpose |
|---|---|
| `src/chat/` | Scope parsing, interpretation routing, context management, artifact provenance, self-report integration, non-authorizing chat controls |
| `src/governance/` | Foundation gates, withdrawal propagation, correction handling, evidence-class transition, checkpoint-chain resolution, metadata registry, structural blocks, policy evaluation |
| `src/shared/` | Reusable non-domain-specific support such as posterior checkpoint metadata, confidence decay, OOD propagation, and stable utility contracts |
| `src/community/` | Accessible, rights-preserving intake, anonymous-case handling, communication routing, and community-facing governance support |

A module path must appear only once as a governed artifact. A source implementation must not be mirrored in two different language-root conventions without an explicit compatibility or generated-artifact record.

## Schema naming and placement

JSON Schema contracts belong in `schemas/` and should use a clear, stable suffix:

```text
schemas/<artifact-name>.schema.json
```

Examples:

```text
schemas/research-output-record.schema.json
schemas/research-output-lifecycle.schema.json
schemas/benefit-commitment.schema.json
schemas/session-carrier.schema.json
schemas/governance-drift-report.schema.json
schemas/artifact-repo-target.schema.json
```

A schema must:

- Declare its draft version in `$schema`.
- Declare a stable `$id`.
- Declare its artifact repository target through a metadata envelope or companion record governed by `schemas/artifact-repo-target.schema.json`.
- Use `additionalProperties: false` unless a deliberate extensibility policy is documented.
- Include a non-authorization contract where the schema represents governed output, policy, continuity, review, or external-action-adjacent data.
- Use explicit `required` clauses for each discriminator referenced in `if` branches.
- Preserve explicit `unknown`, `unverified`, `pending`, and `structural_block` values where applicable.
- Avoid using a relative parent traversal such as `../schemas/` or `../enums/` for cross-repository relationships.
- Use a path-indexed reference and explicit target declaration for any cross-repository dependency.

## Manifest naming and placement

Machine-readable governance and continuity records belong in `manifests/`:

```text
manifests/<artifact-name>.json
```

Examples:

```text
manifests/forward-progress-registry.json
manifests/session-carrier.json
manifests/foundation-gate-registry.json
manifests/artifact-metadata-registry.json
manifests/repo-relative-path-index.json
manifests/session-resumption-preflight.json
manifests/bri-calibration-eligibility-matrix.json
```

A manifest must:

- Declare `format`, `schema_version`, `artifact_type`, and `repo_targets`.
- Declare one owning `repo_target` when it indexes or describes itself through governed metadata.
- Include a review status and verification reference field.
- Use only repository-relative references.
- Identify the intended repository target for every referenced governed artifact.
- Avoid treating a path reference as proof of existence, currentness, validation, adoption, or authority.
- Include a non-authorization block when the manifest influences governance, continuity, review, provenance, or release planning.

## Documentation and policy placement

Human-readable specifications belong in `docs/`. Governance rules that define constraints or enforceable policy belong in `policies/`.

Use `docs/` for:

- Charters.
- Lifecycle specifications.
- Protocols.
- Calibration requirements.
- Directory conventions.
- Checkpoint-chain rules.
- Multi-model composition policies.
- External notice process specifications.
- Canonical-choice logs.
- Session resumption guidance.

Use `policies/` for:

- Capability boundaries.
- Rights-holder governance rules.
- Community reporting policy.
- Privacy, retention, and access policies.
- Rego policy modules where policy grouping improves reviewability.

A document or policy artifact may describe a related implementation module, but it must not imply that the module exists, is current, has passed tests, or is authorized for external use.

## Enum placement and versioning

Controlled vocabularies belong in `enums/`.

Examples:

```text
enums/audience_track.json
enums/attribution_mode.json
enums/knowledge_class.json
```

An enum artifact must:

- Use a stable enum name and version.
- Identify its owning repository.
- Preserve `unknown` where the modeled condition cannot be established safely.
- Avoid using enum values to infer identity, health, augmentation, neural status, authority, rights-holder status, eligibility, credibility, or institutional affiliation.
- Be referenced by exact path and repository target.
- Be reconciled when a schema references a different enum version than the registry declares.

## Test placement and boundaries

Tests belong in `tests/` and must use repository-relative paths.

Examples:

```text
tests/test_cross_artifact_consistency.py
tests/test_cross_repo_references.py
tests/test_fail_closed_coverage.py
tests/test_conditional_schema_guards.py
tests/test_rego_nonempty_collections.py
tests/test_research_output_lifecycle.py
tests/test_next_wave_object_record.py
tests/test_correction_appeal.py
```

Tests must:

- Use synthetic, metadata-only, or explicitly supplied non-sensitive fixtures.
- Avoid external network access, connector activation, credential handling, repository mutation, file deletion, publication, data transfer, field activity, or operational control.
- Check directory paths before reading a local artifact.
- Fail visibly on missing required artifacts, unsupported repository targets, unresolved references, malformed schema discriminators, or unexpected cross-repository references.
- Preserve `structural_block` as a distinct result from a substantive failure.
- Avoid treating a passing test as governance adoption, publication approval, external authorization, or a claim about external reality.

## Template placement

Reusable templates belong in `templates/`.

Examples:

```text
templates/agent-self-report.txt
templates/non-authorization-block.txt
templates/artifact-draft-register.txt
```

Templates must:

- Be clear about whether they are advisory, draft, reviewed, or adopted.
- Avoid citation markers and unsupported authority claims.
- Preserve non-authorization and minimal-disclosure boundaries.
- Avoid embedding personal identity, health, neural, biometric, credential, telemetry, companion-system, institutional, protected-site, or operational-system information unless explicitly supplied and necessary for a bounded task.
- Be linked to an owning repository through the artifact metadata registry and repository path index.

## Cross-repository reference protocol

A source artifact in one repository may reference a target artifact in the other repository only if all conditions are met:

1. The source artifact has exactly one declared `repo_target`.
2. The target artifact is listed in `manifests/repo-relative-path-index.json`.
3. The target path is repository-relative.
4. The target artifact has exactly one declared owning repository.
5. The target repository appears in the source artifact’s `cross_repo_references_allowed` list.
6. The source and target relationship is covered by a bounded `reference_policy`.
7. The reference does not use a remote URL, absolute path, parent traversal, or ambiguous alias.
8. The reference does not silently bypass an unresolved canonical-choice, schema-version conflict, withdrawal impact, correction issue, or structural block.
9. The CI validator passes.
10. The reference remains explicitly unverified unless a separate bounded verification record exists.

### Permitted reference pattern

A governed metadata record may express a cross-repository reference as:

```json
{
  "source_repo_target": "mk-bluebird/Augmented-Hub",
  "source_path": "schemas/artifact-repo-target.schema.json",
  "target_repo_target": "mk-bluebird/Skynet",
  "target_path": "schemas/research-output-record.schema.json",
  "reference_policy": "schema_contract_reference",
  "verification_status": "referenced_unverified"
}
```

This pattern is metadata only. It does not resolve files or grant access.

### Prohibited reference patterns

The following patterns are prohibited for governed cross-repository references:

```text
../schemas/research-output-record.schema.json
../../Skynet/schemas/research-output-record.schema.json
/opt/project/Skynet/schemas/research-output-record.schema.json
[https://github.com/mk-bluebird/Skynet/blob/main/schemas/research-output-record.schema.json](https://github.com/mk-bluebird/Skynet/blob/main/schemas/research-output-record.schema.json)
git@github.com:mk-bluebird/Skynet.git
Skynet:schema:research-output-record
```

These forms create ambiguity, privilege expansion, or hidden repository assumptions.

## Artifact ownership declaration

Every governed artifact must have a corresponding declaration compatible with:

```text
schemas/artifact-repo-target.schema.json
```

The declaration must include at least:

```json
{
  "artifact_id": "example-governed-artifact",
  "repo_target": "mk-bluebird/Augmented-Hub",
  "path": "schemas/example-governed-artifact.schema.json",
  "destination_directory": "schemas",
  "schema_version": "1.0.0",
  "review_status": "draft",
  "last_verification_reference": null,
  "repo_targets": [
    "mk-bluebird/Augmented-Hub",
    "mk-bluebird/Skynet"
  ],
  "cross_repo_references_allowed": [],
  "reference_policy": "same_repository_only",
  "non_authorization": {
    "statement": "This declaration records repository ownership metadata only. It does not authorize external action or verify repository state.",
    "external_action_requires_separate_approval": true,
    "does_not_verify_identity_or_status": true,
    "does_not_verify_repository_state": true
  },
  "privacy": {
    "data_class": "governance_metadata",
    "contains_personal_data": false,
    "minimum_disclosure_rule": "Record only the metadata necessary for governed artifact ownership and reference validation."
  }
}
```

## CI validation order

The intended validation sequence is:

```text
1. Parse the path index.
2. Validate index entries for unique artifact IDs.
3. Validate unique repository-target and path pairs.
4. Validate path and destination-directory alignment.
5. Validate each governed artifact ownership declaration.
6. Discover governed schemas and other supported artifacts.
7. Verify that discovered governed artifacts appear in the path index.
8. Extract repository-relative references.
9. Resolve each reference against the path index.
10. Verify same-repository or explicitly permitted cross-repository ownership.
11. Emit structural-block or governance-drift findings for every mismatch.
12. Do not infer file existence, compatibility, adoption, or external authority from a passing reference check.
```

The relevant validator target is:

```text
tests/test_cross_repo_references.py
```

A validator should emit findings in a form compatible with:

```text
schemas/governance-drift-report.schema.json
```

Each finding should include:

- Source artifact path.
- Source repository target.
- Referenced path.
- Resolved target repository target, if any.
- Token type.
- Expected repository target or path.
- Actual repository target or path.
- Structural-block reason, if applicable.
- Remediation reference.

## Ownership examples

### Same-repository schema reference

```text
Source repository: mk-bluebird/Augmented-Hub
Source path: schemas/benefit-commitment.schema.json
Target path: enums/attribution_mode.json
Target repository: mk-bluebird/Augmented-Hub
Result: Allowed when both artifacts are indexed and ownership is consistent.
```

### Allowed cross-repository reference

```text
Source repository: mk-bluebird/Augmented-Hub
Source path: manifests/repo-relative-path-index.json
Target path: schemas/research-output-record.schema.json
Target repository: mk-bluebird/Skynet
Result: Allowed only when the source artifact explicitly permits mk-bluebird/Skynet and the target path is indexed under that repository.
```

### Blocked reference

```text
Source repository: mk-bluebird/Skynet
Source path: schemas/research-output-record.schema.json
Target path: ../enums/audience_track.json
Target repository: unknown
Result: structural_block because parent traversal does not declare repository ownership.
```

## Migration rules

Existing references using `../schemas/`, `../enums/`, absolute paths, repository aliases, remote URLs, or undocumented cross-repository assumptions must be reconciled through a forward-only migration record.

The migration process must:

1. Preserve the predecessor reference for auditability.
2. Identify the source artifact and its owning repository.
3. Identify the intended target artifact and its owning repository.
4. Add or update the target path in `manifests/repo-relative-path-index.json`.
5. Add or update each artifact’s repository-target declaration.
6. Declare `cross_repo_references_allowed` only where the relationship is intended.
7. Update the source artifact to use the governed reference format.
8. Run cross-repository validation.
9. Record any unresolved target as `structural_block`.
10. Avoid deleting history, silently rewriting provenance, or treating unverified paths as verified.

A migration must not weaken privacy, consent, withdrawal, correction, appeal, accessibility, non-authorization, or non-interference constraints.

## Review and revision triggers

Review this convention when:

- A new governed directory is introduced.
- A directory is retired, split, merged, or assigned a new purpose.
- A repository target is added, removed, renamed, or re-scoped.
- A new artifact language, format, or build system requires a placement rule.
- A cross-repository validator identifies an unexpected reference, ambiguous owner, unsupported root directory, absolute path, remote URL, or parent traversal.
- An artifact metadata registry, path index, repository-target schema, or governance drift schema changes.
- A privacy, security, accessibility, consent, withdrawal, correction, appeal, retention, provenance, or external-action boundary affects artifact placement or referencing.
- A material repository-layout conflict is discovered.

## Integrity and privacy

This convention records layout and governance metadata only.

It must not contain:

- Personal identity, health, neural, biometric, credential, telemetry, companion-system, private institutional, protected-site, or operational-system information.
- Private repository content.
- Access tokens, keys, passwords, endpoints, account identifiers, or secrets.
- Claims that any local or remote repository has been inspected, validated, synchronized, or modified unless a separate bounded verification or authorization record exists.

A directory path, ownership declaration, or allowed cross-repository reference remains `referenced_unverified` until an appropriate verification process records otherwise.
