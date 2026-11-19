# ADR 0001: Canonical Evidence Envelope, Parity, and Local-First Governance

- Status: Accepted
- Date: 2026-09-05
- Decision type: Foundational architecture
- Scope: Advisory-only ecological evidence, validation, review, retention, and local presentation

## Context

Augmented-Hub integrates ecological research artifacts that may differ in field names, temporal conventions, spatial-resolution semantics, uncertainty handling, evidence provenance, and numerical implementation language.

Directly combining those artifacts would create ambiguity. It could also allow a favorable score in one domain to obscure an unresolved condition in another domain, including uncertainty, contamination, privacy, accessibility, equity, provenance, or required human review.

This architecture establishes a canonical, local-first evidence model. It does not authorize physical-world action, infrastructure control, sampling, remediation, deployment, service changes, or external communication.

## Decision

Augmented-Hub adopts all of the following decisions.

### 1. Canonical envelope first

All newly produced evidence records SHALL conform to the Canonical Evidence Envelope Contract.

Existing domain outputs SHALL remain preserved as source artifacts. They SHALL be imported only through versioned, deterministic adapters and SHALL NOT define the semantics of the canonical contract.

The canonical contract SHALL include:

- Envelope and contract version identifiers
- Domain and model identifiers
- Declared purpose and advisory-only status
- Temporal scope and quality state
- Spatial reference, anchor scheme, resolution, and quality state
- Evidence polarity and method limitations
- Parameter and provenance references
- Knowledge-factor components
- Domain-specific ecological-value components
- Risk-vector components
- Uncertainty representation
- FOG, parity, promotability, and review states
- Retention and deletion state
- Append-only audit linkage

A canonical envelope SHALL NOT be interpreted as:

- A regulatory determination
- A physical recommendation
- A command or authorization
- A claim of real-world certainty
- A substitute for community governance, scientific validation, or human review
- Evidence about a person's identity, health, augmentation, institutional status, or credibility

### 2. Versioned migration without semantic invention

Legacy artifacts SHALL be classified as one of:

| Migration class | Meaning | Integrated-advisory eligibility |
|---|---|---|
| `native_canonical` | Produced directly under this contract | Eligible if all other gates pass |
| `lossless_import` | Deterministically adapted with every required semantic field available | Eligible if all other gates pass |
| `partial_import` | Preserved with known semantic omissions | Not eligible for promoted integrated advisories |
| `archive_only` | Cannot be safely mapped to canonical semantics | Historical reference only |

Every import adapter SHALL record:

- `source_schema_id`
- `source_schema_version`
- `adapter_id`
- `adapter_version`
- `migration_class`
- `migration_observed_at`
- `missing_semantics`
- `canonicalization_status`

Adapters SHALL NOT infer unavailable information.

In particular:

\[
\text{unknown} \neq 0
\]

\[
\text{not measured} \neq \text{not detected}
\]

\[
\text{legacy score} \neq \text{canonical review clearance}
\]

### 3. Advisory-only and non-interference

Every contract-governed result SHALL be advisory-only.

The system SHALL NOT:

- Control, actuate, deploy, sample, modify, repair, or operate physical systems
- Issue instructions for changes to land, water, infrastructure, services, or equipment
- Open network listeners
- Automatically communicate with external services
- Discover hardware or external devices
- Create remote-control, scheduling, orchestration, or enforcement outputs
- Automatically export evidence
- Infer personal identity, health, communication mode, augmentation, institutional affiliation, eligibility, or credibility

A result may support local research review only within its stated purpose, evidence scope, uncertainty limits, and human-review status.

### 4. Structural non-compensation

Knowledge, ecological value, risk, uncertainty, and promotability SHALL remain separate.

A favorable result in one domain SHALL NOT compensate for an active withholding or blocking condition in another domain.

Promotability SHALL use one of the following states:

| State | Meaning |
|---|---|
| `blocked` | A non-compensating condition prevents advisory promotion |
| `low_confidence` | Bounded partial evidence may be displayed locally but requires limitations |
| `human_review_required` | Evidence may be inspectable but cannot be treated as reviewed advisory output |
| `reviewed_advisory` | Human review completed within declared scope; still advisory-only |

Risk SHALL be represented as a vector:

\[
\mathbf{R} =
(
R_{\text{ecological}},
R_{\text{privacy}},
R_{\text{accessibility}},
R_{\text{misuse}},
R_{\text{equity}},
R_{\text{community}},
R_{\text{provenance}},
R_{\text{data-quality}}
)
\]

The system SHALL evaluate an independent blocking predicate:

\[
B =
B_{\text{FOG}}
\lor
B_{\text{parity}}
\lor
B_{\text{privacy}}
\lor
B_{\text{accessibility}}
\lor
B_{\text{misuse}}
\lor
B_{\text{equity}}
\lor
B_{\text{community}}
\lor
B_{\text{contaminant}}
\lor
B_{\text{required-review}}
\]

The required outcome is:

\[
B = \mathrm{true}
\Rightarrow
\text{promotability} = \texttt{blocked}
\]

No knowledge factor, ecological-value component, display score, confidence interval, or favorable model output may reverse an active block.

### 5. Domain-specific ecological value

Ecological value SHALL be domain-specific and component-preserving.

\[
\mathbf{E}_{d} =
(E_{d,1}, E_{d,2}, \ldots, E_{d,n})
\]

Examples include:

| Domain | Example value components |
|---|---|
| Thermal | Shade context, cooling estimate, temporal persistence, habitat-relevant context |
| Water | Quality context, quantity context, timing, uncertainty, contaminant compatibility |
| Soil | Carbon persistence, structure, infiltration context, biotic-support evidence |
| Connectivity | Permeability assumptions, continuity, redundancy, route uncertainty |
| Materials | Lifecycle evidence, durability, recovery/reuse evidence, contaminant compatibility |
| Energy/carbon | Method completeness and attributable resource evidence only |

Any scalar display calculation SHALL be explicitly labeled non-authorizing and SHALL retain its component values:

\[
\text{display score} =
f(K_d, \mathbf{E}_{d}, \mathbf{R}_{d})
\]

### 6. Evidence polarity and negative evidence

Evidence polarity SHALL distinguish:

- `detected`
- `not_detected`
- `inconclusive`
- `not_applicable`
- `not_measured`
- `contradictory`
- `modeled_absence`

A `not_detected` result SHALL require sufficient method metadata for its domain, including applicable detection or quantification limits, method context, temporal scope, spatial scope, and quality status.

A negative result SHALL NOT automatically clear FOG or other blocks.

\[
\texttt{not\_detected} \neq \texttt{clear}
\]

### 7. Time and duration semantics

Canonical ordering SHALL use UTC instants.

\[
t_{\text{canonical}} = \text{UTC instant}
\]

Physical duration SHALL be derived from canonical instants:

\[
\Delta t_s =
t_{\text{end,utc}} - t_{\text{start,utc}}
\]

The contract SHALL support:

- `observed_at_utc`
- `interval_start_utc`
- `interval_end_utc`
- `duration_seconds`
- `time_basis`
- `time_resolution_seconds`
- `temporal_quality_state`
- `observed_time_zone` when civil-time interpretation is relevant
- `observed_offset_minutes`
- `gap_policy_id`

Missing, malformed, out-of-order, or policy-incompatible time data SHALL cause a declared withholding state, including `withhold_time_integrity` or `withhold_temporal_gap`.

The system SHALL NOT silently infer timing or interpolate a gap unless a declared model-specific policy permits it and records the resulting uncertainty.

### 8. Spatial and resolution semantics

Spatial identity SHALL be separate from spatial meaning.

Every spatially scoped record SHALL declare:

- `spatial_reference_id`
- `anchor_scheme_version`
- `anchor_id`
- `anchor_level`
- `cell_edge_length_m`
- `geometry_basis`
- `geometry_uncertainty_m`
- `coverage_fraction`
- `spatial_quality_state`
- `privacy_resolution_state`

Cross-domain spatial use SHALL declare one relation:

\[
\text{relation} \in
\{
\texttt{same},
\texttt{parent},
\texttt{child},
\texttt{overlap},
\texttt{adjacent},
\texttt{disjoint},
\texttt{unknown}
\}
\]

Only policy-approved relations may support integration.

Disaggregation SHALL be labeled as modeled allocation, SHALL carry increased uncertainty, and SHALL NOT replace observed child-level evidence.

An unavailable or incompatible spatial relationship SHALL cause `withhold_spatial_relation` or `withhold_resolution_review`.

### 9. Cross-language parity

Cross-language parity SHALL use exact comparison for discrete semantics and bounded tolerance for general floating-point calculations.

Exact comparison SHALL apply to:

- State-transition results
- Policy-gate outcomes
- Identifiers and contract versions
- Canonical timestamp serialization
- Integer counts
- Deterministic ordering
- Required-field acceptance or rejection
- SQLite constraint and trigger outcomes

General finite numerical values SHALL use fixture-declared tolerance:

\[
|x_{\mathrm{impl}} - x_{\mathrm{reference}}|
\leq
\epsilon_{\mathrm{abs}}
+
\epsilon_{\mathrm{rel}}
\cdot
\max(1, |x_{\mathrm{reference}}|)
\]

Each numerical fixture SHALL declare:

- Comparison mode
- Absolute and relative tolerance where applicable
- Unit
- Rounding and serialization policy
- Treatment of non-finite values
- Tie-breaking policy
- Seed and resampling conditions where applicable

Interval outputs SHALL use fixture-declared conservative containment, permitted-envelope containment, overlap, or other explicit interval policy.

A failed parity check SHALL create:

\[
\text{state} = \texttt{withhold\_parity}
\]

A parity failure SHALL remain visible locally with a plain-language explanation and SHALL block advisory promotion until reviewed and corrected through an append-only process.

### 10. Local-first deployment

Release 1 SHALL operate as a local-first system.

The release-1 topology SHALL include:

- A locally controlled application instance
- A local SQLite evidence store
- Local validation and review
- Local, accessible presentation
- Explicit user-controlled import of local files

The release-1 topology SHALL NOT include:

- Distributed execution
- Network federation
- Peer discovery
- Automatic synchronization
- Remote database connections
- Cloud dependencies
- Shared mutable queues
- Remote review authority
- Remote device control
- Automatic import or export

A later version MAY define an offline evidence-bundle profile only after independent review of privacy, retention, accessibility, integrity, and purpose-limitation requirements.

\[
\text{manual offline bundle}
\neq
\text{distributed system}
\]

Any future bundle SHALL be explicitly selected, privacy-minimized, purpose-limited, integrity-checked, retention-aware, and imported into a local quarantine area before independent validation.

### 11. Human review, correction, and appeal

FOG and withholding states SHALL NOT self-clear.

The review lifecycle SHALL support:

- Plain-language explanation
- Missing-evidence category
- Technical evidence inspection
- Correction request
- Appeal request
- Evidence submission
- Accessibility request
- Privacy or deletion request
- Human decision with role-bounded accountability
- Append-only review event

A review event SHALL not overwrite source evidence. Later correction or review may supersede an interpretation while preserving prior evidence and decision history.

The review interface SHALL:

- Support keyboard navigation
- Avoid color-only communication
- Present uncertainty, intervals, and blocks in text
- Provide accessible tables for visual/model outputs
- Make the advisory-only limitation visible
- Provide a plain-language correction path

### 12. Retention and deletion

Every canonical envelope SHALL have a declared data class, purpose limitation, retention rule, and deletion or restriction state.

Deletion SHALL be purpose-limited and auditable without retaining the deleted content itself.

Deletion records SHALL preserve only the minimum accountability metadata necessary to show:

- A deletion or restriction event occurred
- The data class or scope affected
- The policy basis
- The execution time
- The result status
- The prior audit linkage

Deletion records SHALL NOT preserve raw deleted content, unnecessary private details, or recoverable copies of deleted evidence.

## Consequences

### Positive consequences

- New outputs have consistent semantics across domains.
- Legacy artifacts remain preserved without governing new semantics.
- Cross-language numerical differences are visible and reviewable.
- High scores cannot hide active blocks.
- Local processing reduces exposure to network-based exfiltration and remote misuse.
- Human reviewers receive accessible, bounded explanations.
- Retention and deletion become enforceable design elements rather than metadata only.

### Trade-offs

- Legacy import requires explicit adapter work.
- Some historical artifacts remain partial or archive-only.
- Local-first operation does not provide automatic collaboration or synchronization.
- Floating-point tolerance policies require fixture-specific justification.
- Human review is required for promotion and correction of blocked outputs.
- A domain may remain withheld even where another domain reports favorable evidence.

## Implementation sequence

1. Publish the Evidence Envelope Contract.
2. Confirm the repository-approved ALN v2 grammar before creating policy syntax.
3. Implement SQLite `STRICT` tables, append-only events, and non-compensation triggers.
4. Implement deterministic local Lua gating.
5. Publish synthetic and analytical fixtures.
6. Implement C++, Java, Kotlin, Lua, and SQLite parity harnesses against the same fixtures.
7. Implement the accessible local review interface only after state, retention, and review semantics are verified.

## Acceptance criteria

The first implementation milestone SHALL demonstrate:

- A valid canonical envelope can be stored and retrieved locally.
- A lossless adapter produces a versioned migration event.
- A partial import remains visible but cannot become a promoted integrated advisory.
- Negative evidence requires method and detection-limit metadata.
- An active privacy, accessibility, contamination, FOG, parity, or review block prevents `reviewed_advisory`.
- High K or ecological-value components cannot clear an active block.
- Invalid temporal ordering and prohibited spatial relationships produce withholding states.
- Numerical results within declared tolerance pass parity.
- Numerical results outside declared tolerance produce `withhold_parity`.
- No network listener, external communication, automatic export, or hardware interaction is introduced.
- All states and correction paths are available in plain language and without color-only signaling.
- Fixtures are synthetic or analytical and do not claim real-world certainty.
