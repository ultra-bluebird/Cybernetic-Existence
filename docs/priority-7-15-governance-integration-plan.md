# Priorities 7–15: Governance Integration Plan

## Status

This document defines implementation requirements for K-factor calibration,
risk aggregation, retention enforcement, domain ecological-value calculation,
temporal and spatial compatibility, graceful degradation, sampling feedback,
and accessible review outputs.

All automated outputs are advisory only. They do not operate, command, alter,
or directly control physical infrastructure, environmental systems, devices,
or people.

## Core invariants

1. Every evidence-derived value has a stable evidence identifier, schema
   version, observation time, spatial anchor, provenance chain, and retention
   classification.
2. K, E, and R values are normalized finite values in the closed interval
   [0.0, 1.0].
3. A non-compensating risk veto cannot be offset by high knowledge,
   ecological-value, confidence, or benefit values.
4. Missing provenance, invalid signatures where required, expired parameters,
   invalid temporal scope, incompatible spatial scope, or revoked consent
   produce withholding rather than a positive advisory.
5. Negative evidence can narrow a defined uncertainty interval only within
   its stated method, detection limit, location, population, and time scope.
   It cannot independently establish a positive ecological advisory.
6. Retention enforcement minimizes data storage while retaining only the
   minimum non-sensitive audit metadata needed for accountability, correction,
   and deletion verification.
7. Accessible plain-language output and a human review fallback are available
   for every withheld, material, disputed, or correction-related advisory.
8. CyberRank, self-description, communication style, identity, health,
   augmentation status, location inference, device metadata, and disclosure
   choices are never K, E, R, eligibility, risk, or calibration inputs.

## Priority 7: K-factor calibration

### Purpose

The K factor represents the bounded quality and applicability of an evidence
record for a declared use. It is not a truth score, scientific certification,
institutional status, or measure of any person or community.

### Dimensions

The required dimensions are:

| Dimension | Weight | Meaning |
|---|---:|---|
| Measurement precision | 0.25 | Fitness of the measured quantity for the declared uncertainty interval |
| Calibration confidence | 0.20 | Validity and recency of the documented instrument or method calibration |
| Reproducibility | 0.20 | Ability for an independent process to reproduce the result under stated conditions |
| Sample representativeness | 0.15 | Suitability of the sampling design for the declared population or area |
| Temporal relevance | 0.10 | Applicability of the observation date to the advisory time window |
| Spatial relevance | 0.10 | Applicability of the observation geography and resolution to the anchor |

Each dimension must include:

- A normalized value in [0.0, 1.0]
- A plain-language rationale
- A source or method reference
- A reviewer or calculation identity represented by a local pseudonymous role
- An evaluated-at UTC timestamp
- A validity interval
- A reason for any manual override

### K-factor formula

Let the six dimension values be \(m, c, r, s, t, g\). The initial K score is:

\[
K_{raw} = 0.25m + 0.20c + 0.20r + 0.15s + 0.10t + 0.10g
\]

The admissible K score is:

\[
K = clamp(K_{raw}, 0.0, 1.0)
\]

The score is eligible for advisory use only when all dimensions are present,
finite, within range, source-bound, and valid for the requested time and
spatial scope. Otherwise the evidence is marked `K_WITHHELD`.

### Calibration requirements

- Calibration inputs must reference a versioned parameter source record.
- Site-specific field validation takes precedence over generalized values only
  when the field method, local scope, sample timing, and uncertainty are
  recorded.
- A parameter is not automatically applicable because it is peer reviewed,
  published, or associated with a recognizable institution.
- Every calibration must state whether it is measured, derived, simulated,
  interpolated, extrapolated, or expert-reviewed.
- Calibration reports must include holdout or independent-check results when
  available.
- Calibration drift must be measured against a declared baseline and recorded
  as a material-change event when the defined threshold is exceeded.
- K-factor values may be recalculated after new evidence is accepted, but the
  previous calculation and its inputs must remain traceable until their
  retention policy requires deletion.

### Evidence grades

| Grade | K interval | Meaning | Advisory eligibility |
|---|---:|---|---|
| A | 0.85–1.00 | Strongly documented, applicable, current, and independently checkable | Eligible if no other gate withholds |
| B | 0.70–0.849999 | Good evidence with bounded limitations | Eligible if risk and scope gates pass |
| C | 0.60–0.699999 | Limited but potentially informative evidence | Advisory only with explicit limitations |
| D | 0.35–0.599999 | Weak applicability or material uncertainty | Withhold positive advisory |
| E | 0.00–0.349999 | Insufficient, invalid, expired, or non-applicable evidence | Withhold |

Grade labels are communication aids. They do not replace the underlying
dimensions, sources, validity window, or uncertainty statement.

## Priority 8: Risk taxonomy

### Risk semantics

Risk values describe the bounded likelihood, severity, uncertainty, or
exposure concern associated with a declared advisory. They are not judgments
about a person, group, identity, communication mode, or self-description.

Each risk record must declare:

- Risk dimension
- Assessment method and version
- Evidence inputs
- Scope in space and time
- Value in [0.0, 1.0]
- Uncertainty or confidence bounds
- Maximum tolerance
- Whether the dimension is non-compensating
- Required action when tolerance is exceeded

### Required dimensions

| Dimension | Default rule | Minimum response |
|---|---|---|
| Ecological harm | Non-compensating | Withhold if tolerance exceeded |
| Privacy risk | Non-compensating | Withhold sharing or disclosure path |
| Accessibility impact | Non-compensating | Withhold inaccessible workflow; provide equivalent access |
| Operational risk | Non-compensating when it affects safety or integrity | Withhold until safe fallback or review |
| Equity risk | Non-compensating | Withhold disparate or exclusionary outcome |
| Community burden | Non-compensating | Withhold until burden is assessed and reviewable |

### Composition

The overall risk is the maximum required non-compensating risk:

\[
R_{overall} = \max(R_{ecological}, R_{privacy}, R_{accessibility},
R_{operational}, R_{equity}, R_{community})
\]

A weighted mean may be calculated for internal descriptive analysis only. It
must never override a non-compensating risk, lower a required safeguard, or
convert a withheld result into a positive advisory.

### Default advisory gates

- `R > 0.35`: `WITHHOLD_RISK`
- Any risk dimension above its configured tolerance: `WITHHOLD_DIMENSION`
- Missing, invalid, expired, or out-of-scope risk assessment:
  `WITHHOLD_RISK_EVIDENCE`
- Accessibility impact above zero where no equivalent accessible path exists:
  `WITHHOLD_ACCESS_EQUIVALENCE`
- Privacy risk above zero where the workflow would disclose data beyond its
  approved scope: `WITHHOLD_PRIVACY`

Thresholds are configuration values requiring source justification, versioning,
review status, effective dates, and a local material-change audit event.

## Priority 9: Retention enforcement

### Retention principle

Retention is purpose-bound and minimum-necessary. The system must not retain
raw payloads, precise locations, sensitive operational records, or reviewer
notes longer than the active purpose, explicit consent scope, legal
obligation, or approved accountability requirement permits.

### Required lifecycle states

| State | Meaning |
|---|---|
| Active | Usable for the declared purpose |
| Restricted | Access narrowed pending review, dispute, or consent change |
| Tombstoned | Content unavailable for ordinary use; deletion is queued or completed |
| Deleted | Sensitive payload removed or cryptographically destroyed |
| Audit-minimized | Only permitted non-sensitive deletion/accountability metadata remains |
| Preservation-hold | Retention paused by a documented, time-bounded authorized hold |

### Enforcement requirements

- Do not rely on an insert trigger alone for lifecycle deletion. A trigger
  only runs when its triggering SQL operation occurs and cannot serve as a
  reliable scheduler.
- Use an offline local maintenance process that runs on a bounded schedule,
  records its execution, and safely resumes after interruption.
- Enforce retention at query time as well as deletion time: expired records
  must not be included in ordinary advisory computation.
- Use tombstoning only as a short-lived transition state. Define maximum
  tombstone duration and a deletion completion check.
- Keep deletion-audit records free of raw payloads, sensitive location data,
  identity details, and prior sensitive content.
- Record deletion reason, policy version, affected record count, time window,
  integrity result, and whether human verification was required.
- Support correction and appeal workflows without restoring deleted raw data
  when doing so would violate retention or privacy constraints.
- Maintain encrypted backups with the same or shorter retention period and
  verify deletion propagation to each local backup set.

### Deletion audit minimum fields

- `deletion_id`
- `policy_id`
- `policy_version`
- `executed_at_utc`
- `deletion_reason`
- `record_class`
- `record_count`
- `tombstone_count`
- `payload_delete_status`
- `backup_propagation_status`
- `human_verified`
- `integrity_check_status`

## Priority 10: Ecological-value specialization

### E-factor semantics

The E factor expresses the documented ecological relevance or prospective
ecological value of evidence within a named domain and scope. It does not
guarantee ecological outcomes, substitute for field validation, or justify
action where risk, uncertainty, consent, or review gates withhold output.

Each domain calculator must define:

- Input schema and units
- Component definitions
- Source requirements
- Validity range
- Component weights
- Non-compensating components
- Missing-input behavior
- Uncertainty propagation
- Version and effective interval
- Plain-language explanation template

### Domain registration rules

- A domain may define weighted components only after each component has an
  explicit meaning, unit, source basis, and validation procedure.
- A non-compensating ecological component must be evaluated before weighted
  aggregation.
- Missing required components cause `E_WITHHELD`, not zero substitution.
- Every output includes component values and explanation; a single scalar E
  is insufficient for review.
- Domain calculators must be deterministic for the same canonical input,
  algorithm version, and numeric contract.

### Thermal example requirements

A thermal E calculation may include cooling, shade, and habitat components only
when all component definitions state their unit, observation time, spatial
scope, source, calibration method, uncertainty, and non-compensating
thresholds.

A generic weighted example is:

\[
E_{thermal} = 0.4C_{cooling} + 0.3S_{shade} + 0.3H_{habitat}
\]

This formula is advisory-model structure, not a validated ecological claim.
Before use, the project must establish whether any component is
non-compensating, how local evidence maps to each normalized component, and
how uncertainty changes the output or withholding state.

## Priority 11: Temporal consistency

### Canonical time rules

- Store all timestamps as RFC 3339 UTC text with a `Z` suffix.
- Treat `Instant` as the canonical machine time representation.
- Store local display timezone separately from observed time.
- Do not require all evidence to have the same timezone; UTC normalization
  makes differing source timezones comparable.
- Preserve source-provided timezone and original timestamp only when needed
  for traceability, accessibly displayed interpretation, or correction.
- Define inclusive/exclusive interval semantics consistently:
  `[valid_from_utc, valid_to_utc)`.
- Reject records where `valid_to_utc <= valid_from_utc`.
- Reject observations outside declared source validity, parameter validity, or
  retention eligibility.
- Compute elapsed time from explicit reference instants rather than storing
  mutable derived values unless cached values include their calculation basis.

### Temporal compatibility

Evidence may participate in one combined advisory only when:

- Observation windows overlap the advisory window as required by the domain.
- Parameter versions are effective for the calculation time.
- The record is not expired, superseded, invalidated, or deleted.
- The allowed staleness interval for the domain is satisfied.
- Clock-skew limits are satisfied for local device-ingested records.
- The evidence has not been changed after the advisory cutoff without causing
  a material-change review.

## Priority 12: Spatial resolution registry

### Registry requirements

The spatial registry must record:

- Canonical anchor scheme name and version
- Anchor identifier
- Resolution
- Parent anchor identifier, if applicable
- Child anchors only when derivable or explicitly versioned
- Geometry or reproducible geometry derivation reference
- Coordinate reference system
- Validity interval
- Measurement uncertainty or positional tolerance
- Anchor derivation method
- Boundary-assignment rule
- Geodesic or projection correction version where used

### Compatibility rules

Two records are spatially compatible only when all applicable conditions hold:

1. They use the same registered anchor scheme and compatible version.
2. Their temporal validity windows overlap the requested advisory window.
3. Their spatial relationship is identical-anchor, valid ancestor/descendant,
   or explicitly permitted neighborhood relation.
4. Aggregation direction is permitted by the domain. Child-to-parent
   aggregation may be permitted; parent-to-child inference must be marked as
   coarse and cannot claim unobserved child-level detail.
5. Resolution change does not exceed the configured uncertainty budget.
6. The measurement and model method permit aggregation at the requested
   resolution.
7. Privacy constraints permit the requested spatial join or output.

A hex identifier alone is not proof of geographic compatibility. The system
must verify resolution, anchor scheme, time validity, uncertainty, and domain
aggregation rules.

## Priority 13: Error handling and degradation

### Error tiers

| Tier | Condition | Computation | Advisory | Required response |
|---|---|---|---|---|
| 0 | No material error | Full | Allowed if all gates pass | Record normal decision |
| 1 | Recoverable non-material error | Bounded | Allowed only with limitation statement | Record degraded mode |
| 2 | Missing optional evidence or recoverable source issue | Bounded with explicit uncertainty | Withhold positive recommendation unless policy permits limited informational output | Request review or additional evidence |
| 3 | Missing required provenance, expired input, incompatibility, integrity failure, or unavailable accessibility equivalent | No substantive score | Withhold | Explain, preserve local audit, offer review path |
| 4 | Privacy, security, consent, or non-interference violation | No computation using affected data | Withhold and isolate affected path | Minimize exposure, record non-sensitive event, require review |

### Degradation rules

- Partial evidence may produce a bounded informational summary only if the
  output visibly identifies missing inputs, uncertainty, and non-eligibility
  for positive advisory status.
- Minimal evidence must not use invented defaults, silently imputed values, or
  optimistic scores.
- None, invalid, expired, or privacy-restricted evidence produces withholding.
- All fallback strategies must have test fixtures and a plain-language
  explanation.
- A degraded response must never bypass non-compensating risk gates,
  parameter-source validation, retention limits, consent scope, or accessible
  review requirements.

## Priority 14: Feedback loops and sampling

### Purpose

Feedback loops may identify evidence gaps and create reviewable sampling
requests. They must not automatically direct field activity, collect data,
modify models, or change an advisory without the required authorization,
method validation, provenance, and material-change review.

### Sampling request requirements

Each request must include:

- Request identifier
- Advisory and evidence-gap reference
- Requested measurement question
- Justification in plain language
- Proposed spatial and temporal scope
- Minimum data fields
- Method and detection-limit requirements
- Expected privacy and ecological impact
- Retention class
- Consent or authorization basis where applicable
- Approval status and accountable human or approved role
- Accessibility and safety accommodations where relevant
- Cancellation and correction path

### Sampling status machine

Allowed states:

`draft -> pending_review -> approved -> scheduled -> collected -> processed ->
results_received -> validation_pending -> accepted`

Terminal or alternative states:

`rejected`, `cancelled`, `expired`, `invalidated`, `deleted`

No transition may skip review, provenance validation, or required safety and
privacy checks. Results are not used in a model until they reach `accepted`.

### Model update requirements

- A received result triggers validation and review, not direct model rerun.
- A model update creates a new immutable model version and links prior and
  successor versions.
- The system compares prior and updated output, K/E/R values, FOG state, risk
  gates, and affected advisory scope.
- Material changes require re-review and a correction notice when an earlier
  advisory is affected.
- Information gain must be defined per model and bounded. It must not be
  displayed as certainty or a guarantee of ecological outcome.
- The prior advisory remains auditable, subject to retention limits, and is
  marked superseded rather than silently overwritten.

## Priority 15: visualization and accessible review

### Accessible visualization baseline

Every visual evidence output must provide:

- A text equivalent that conveys status, values, uncertainty, scope, and
  withholding reason
- Non-color-only encoding using labels, patterns, symbols, or direct values
- Keyboard-accessible navigation and visible focus
- Screen-reader labels, table alternatives, and concise landmark structure
- Adjustable text size without loss of content or function
- High-contrast mode and color-blind-safe palettes
- Reduced-motion support
- Plain-language summaries alongside technical detail
- Downloadable accessible tabular representation where feasible
- Error messages that identify what failed, what remains available, and the
  correction or review route
- Equivalent review access when a map, chart, token, or visual interaction is
  unavailable

### Dashboard content boundaries

An evidence dashboard may display only data permitted by purpose, consent,
retention, and privacy rules. It must not expose precise locations, private
identifiers, raw telemetry, sensitive reviewer notes, or inference-prone
metadata merely for convenience.

Each dashboard summary must state:

- Domain and advisory scope
- Current status: advisory, informational, withheld, superseded, or pending review
- K, E, and R components with non-technical explanation
- FOG state and reason
- Input coverage and staleness
- Parameter/model version
- Material limitations
- Review, correction, and appeal route
- Whether the display uses aggregation, redaction, or privacy-preserving
  spatial resolution

## Cross-priority acceptance criteria

The priorities are integrated only when the following are true:

1. A record with expired parameters cannot produce an advisory.
2. A record with invalid provenance cannot produce an advisory.
3. A risk dimension above its non-compensating threshold withholds the
   combined result regardless of K or E values.
4. A negative finding cannot independently produce a positive advisory.
5. A spatial join across incompatible resolution or time validity fails closed.
6. A retention-expired record is excluded from ordinary computation and enters
   the deletion lifecycle.
7. Every degraded or withheld result has a machine-readable reason code and an
   accessible plain-language explanation.
8. Every sampling-derived model update is versioned, reviewable, and compared
   with the prior model state.
9. Every dashboard state is available without color-only, pointer-only, or
   token-only interaction.
10. Golden fixtures generate equivalent canonical results across supported
    implementations within the declared numeric tolerance.
