# Local-First Governance Integration

## Purpose

This page explains how the Objects 25–43 artifacts — Rust governance crates,
JSON schemas and policy records, OpenAPI contracts, SQL migrations, and
JavaScript modules — compose into a single discoverable, local-first
governance plane. The integration layer is metadata-only: it registers what
exists, declares each artifact's runtime boundary, and evaluates release
readiness without executing Rust, reading sensitive payloads, or contacting
any external service.

Two invariants frame everything below:

- **Sensitive source signals and sensitive derived artifacts are local-first
  by default.** `schemas/neural-data-governance/data-classification.json`
  assigns `local_only` storage to the `sensitive_source` and
  `sensitive_derived` classes, and the plane-wide default posture is
  `deny_external_disclosure`.
- **The policy layer evaluates metadata and does not prove endpoint
  confidentiality.** Consent, classification, gate, and quorum checks operate
  on identifiers, epochs, and digests. They reduce remote exposure; they do
  not certify that any given device is secure.

## Artifact Roles

| Family | Representative paths | Role in the plane |
| --- | --- | --- |
| Governance crates | `crates/mesh-trust`, `crates/anchor-registry`, `crates/environmental-emc-monitor`, `crates/protected-operation-state`, `crates/external-energy-accounting`, `crates/workload-cost-estimator`, `crates/evidence-gate-engine`, `crates/neural-data-policy`, `crates/oversight-quorum` | Local policy computation over supplied metadata. Each crate's boundary statement (see `config/integration/local-first-governance-manifest.json`) states explicitly what it does *not* do — e.g. `mesh-trust` classifies neighbor capabilities from bounded local signals but establishes no identity or permanent trust. |
| JSON schemas & policy records | `schemas/**` | Shapes for consent receipts, revocation events, decision records, anchor manifests, evidence ledgers, DP release policy, and data classification. |
| OpenAPI contracts | `openapi/smart-city-augmented-hub.openapi.yaml`, `openapi/augmented-citizen-rights.openapi.yaml` | Localhost-served metadata interfaces; contracts imply no remote availability or regulatory approval. |
| SQL migrations | `db/migrations/025_cyberrank_tier3.sql`, `db/migrations/030_social_goods_metrics.sql`, `db/migrations/040_neural_data_audit.sql` | Audit surfaces storing opaque references, epochs, and digests — never signals or payloads. |
| JavaScript modules | `src/sovereignty-preservation/decision-record.js`, `src/procedural-claims/entitlement-guard.js`, `src/integration/local-first-governance-catalog.js`, `src/integration/local-first-release-readiness.js` | Decision receipts, procedural entitlement gating, the immutable policy catalog, and the readiness evaluator. Public surface: `src/index.js`. |
| Governance & continuity documents | `governance/non-removal-clause.jsonld`, `governance/oversight-membership.jsonld`, `continuity/*`, `specs/**` | Declared procedures, reviewer membership, continuity transition graphs, threat models, and architecture specs. |

## Processing Sequence

The declared integration order (mirrored from
`config/integration/local-first-governance-manifest.json`) is:

1. Load data classification and consent policy.
2. Validate current consent epoch before sensitive processing.
3. Keep sensitive source and derived artifacts in local-only storage.
4. Use evidence gates before advancing research stage.
5. Require oversight quorum for policy-defined high-impact actions.
6. Apply aggregation, release checks, and privacy accounting before corridor publication.
7. Record minimal audit metadata and exportable decision receipts.

## Release Readiness

`src/integration/local-first-release-readiness.js` evaluates two things from
supplied metadata only:

- **Artifact completeness** — every ID in `REQUIRED_ARTIFACT_IDS` must appear
  in `availableArtifactIds`.
- **Control enablement** — all six controls must be `true`:
  `consent_epoch_check`, `local_only_default`, `derived_data_default_deny`,
  `high_impact_oversight`, `dp_release_policy`, `audit_ledger`.

Only when both hold does the evaluator report `status: "ready"`, whose next
action is *"Proceed to human release review; this result is not a safety,
legal, clinical, or deployment authorization."* A `blocked` result names the
missing artifacts or failed controls. The evaluation never executes Rust,
never inspects files, and never touches sensitive data.

## Revocation and Derived Artifacts

Consent operates in monotonic epochs. A revocation event
(`schemas/consent/revocation-event.json`) advances the epoch, which blocks
future cooperative authorization for prior-epoch receipts — the entitlement
guard denies stale-epoch requests, and derived artifacts inherit the highest
sensitivity class of their inputs under the classification policy's lineage
rule.

**Revocation blocks future cooperative authorization but cannot guarantee
retrieval or deletion of copies already held outside controlled boundaries.**
Deletion receipts are evidence of a recipient's statement, not proof that
every copy was erased. Downgrading a derived artifact's sensitivity requires
a documented transformation, privacy review, reidentification-risk
assessment, an active authorized basis, and a retention policy.

## Differential Privacy Boundary

Differential privacy in this plane is a **disclosure control, not
anonymization**. A released aggregate is protected only relative to a fully
declared configuration, as encoded in
`schemas/corridor-calibration/dp-release-policy.json`:

- a declared **adjacency definition** (add/remove one subject contribution
  per release window),
- **contribution bounds** with required clipping,
- **group thresholds** (minimum contributor count and time window),
- an explicit **privacy budget** (per-release and cumulative epsilon/delta
  with a named mechanism), and
- **composition accounting** whose exhaustion action denies release and
  requires policy review.

Release decisions additionally pass the checks in
`schemas/corridor-calibration/release-decision-policy.json` before any
corridor publication. Passing these checks authorizes review of a release; it
certifies neither safety nor regulatory compliance.

## Oversight Boundary

`crates/oversight-quorum` checks whether supplied review records satisfy the
quorum defined by policy against `governance/oversight-membership.jsonld`.
Membership entries record declarations of independence and conflict
disclosure; those declarations are procedural inputs, and reviewer neutrality
itself requires external verification. **Oversight records document adopted
procedures and do not independently create legal authority**: they bind
cooperating components only within an enforcement context that has adopted
them. Non-removable clauses (`governance/non-removal-clause.jsonld`) may be
superseded only through the recorded amendment procedure with an oversight
review receipt.

## Non-Claims

The full non-claims list lives in the integration manifest and the catalog
module:

- No artifact verifies brain-bound identity or personhood.
- No artifact grants legal rights, clinical status, or regulatory approval.
- Local-first processing reduces remote exposure but does not prove endpoint security.
- Revocation prevents future cooperative use but cannot recall prior disclosure.
- Differential privacy is a disclosure control, not anonymization.
- Oversight records are procedural and require an adopted enforcement context.

Nothing in this repository makes medical claims, legal determinations,
personhood assertions, or deployment approvals.

## Local Validation

Integration wiring is validated with Node built-ins only — file existence,
JSON parseability, inventory completeness, and boundary-declaration presence:

```bash
node scripts/validate-local-first-governance.mjs
```

The script prints `status=pass` or `status=fail` with artifact, missing-path,
invalid-JSON, and error counts, and exits nonzero on failure. It never runs
Cargo or Rust tooling, never installs anything, and never opens a network
connection.

**A successful local validation proves only that registered files exist and
parse where applicable. It does not prove security, privacy, regulatory
compliance, or safe deployment.**
