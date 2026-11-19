# Rights-Safe Municipal Systems Assurance Specification

## Purpose

This specification defines minimum research and validation requirements for three municipal decision-support components:

- City digital-twin routine automation
- Eco-Identity Intersectionality Metric
- Municipal-rights AI-chat

It is a technical governance framework, not legal advice, a municipal operating policy, or a claim that any proposed right is currently enforceable in a particular jurisdiction.

The research agent must use synthetic, public, or deliberately approved aggregate inputs only. It must not collect, infer, purchase, or retain personal identity, augmentation, health, neural, biometric, precise-location, or behavioral data.

## Scope Boundary

Permitted research activities:

- Formalizing policies, schemas, invariants, and state machines
- Generating synthetic event traces and synthetic source passages
- Executing local unit, property, and adversarial tests
- Reviewing approved public primary-source records already supplied to the research environment
- Producing uncertainty analyses, safety cases, and reproducible reports

Prohibited research activities:

- Connecting to operational Kafka, OPC UA, traffic, irrigation, lighting, transit, or emergency-service systems
- Sending commands to physical infrastructure
- Scraping, profiling, tracking, or inferring information about residents
- Requiring identity, device telemetry, augmentation status, biometric data, or continuous connectivity for access to essential services
- Making individual eligibility, enforcement, benefit, or legal-outcome decisions
- Claiming that a simulated output establishes a field condition, legal conclusion, or deployment readiness

## System Roles

| Role | Permitted responsibility | Prohibited responsibility |
|---|---|---|
| Research agent | Generate synthetic scenarios, run deterministic checks, produce evidence-linked research artifacts | Field data collection, service decisions, individual profiling, infrastructure control |
| Human reviewer | Approve research assumptions, source registries, uncertainty thresholds, and publication candidates | Delegating unreviewed high-impact decisions to the agent |
| Simulator | Evaluate bounded hypothetical actions against static safety rules | Authorizing production actions |
| Evidence registry | Preserve approved source passages and provenance metadata | Treating unsupported model memory as a source |
| Audit recorder | Record non-identifying decision context and validation results | Recording raw personal or assistive-device telemetry |

## Data Classes

| Data class | Examples | Research-agent rule | Retention rule |
|---|---|---|---|
| Public infrastructure state | Synthetic lamp state, synthetic valve health, public code text | Allowed only as synthetic or approved public data | Retain only for reproducible research runs |
| Aggregate environmental indicators | Synthetic heat index, coarse pollution estimate, aggregate canopy score | Allowed when small-cell and disclosure safeguards are represented in the test | Retain aggregate results and test fixtures only |
| Sensitive personal data | Neural, biometric, health, augmentation, precise location, identity | Prohibited from collection, inference, ingestion, or storage | Do not retain |
| Self-asserted identity data | Voluntary aggregate group category | Synthetic only unless explicitly approved through an independent governance process | Suppress unless aggregation and disclosure rules pass |
| Legal source material | Official code excerpt, official agency procedure, court decision | Require provenance, jurisdiction, effective date, and source authority | Versioned and review-dated |
| Audit metadata | Policy revision, model revision, test result, reviewer decision | Must be non-identifying and purpose-limited | Retain for the declared review period |

## Non-Offsettable Constraints

The following conditions cannot be compensated for by ecological benefit, model accuracy, efficiency gain, or any other favorable score:

- No action may require augmentation-status disclosure to obtain an essential public service.
- No action may use neural, biometric, health, identity, assistive-device, or precise-location telemetry unless it is strictly necessary, explicitly consented, and separately approved for the stated purpose.
- No individual-level environmental-justice score may be calculated, stored, released, or used for a decision.
- No simulated or automated infrastructure command may bypass a current safety interlock, maintenance lock, human emergency authority, or command expiry limit.
- No legal claim may be presented as verified unless it is linked to a current, jurisdiction-matched, authoritative source passage.
- No source-free answer may predict legal outcomes, deadlines, eligibility, remedies, or enforceability.
- Bluetooth, apps, accounts, and augmentations must remain optional supplements to standard accessible public infrastructure.
- A failed validation must result in rejection, abstention, or human-review routing; it must not silently downgrade the protection.

## Decision States

Every research-agent decision must result in one of these states:

| State | Meaning | Permitted next step |
|---|---|---|
| `allow_research` | Synthetic test or documentation operation meets all current requirements | Produce an auditable artifact |
| `require_review` | Evidence is incomplete, uncertainty is high, or a policy threshold is exceeded | Route to a named human-review role |
| `abstain` | The requested claim or output cannot be supported | Explain the evidence gap without guessing |
| `reject` | A non-offsettable constraint or validation requirement failed | Stop the proposed operation and record the reason |

## Object-Specific Controls

### City digital-twin automation

Research outputs may model streetlights, irrigation, public cooling infrastructure, and other municipal assets only as synthetic assets.

Required controls:

- Version every telemetry event and reject stale, duplicate, future-dated, malformed, or unauthorized events.
- Bind every proposed action to an asset, expected twin version, policy revision, expiry time, and simulation result.
- Use simulation before any hypothetical approval.
- Treat accessible-route illumination, flood controls, maintenance locks, and emergency authority as non-offsettable constraints.
- Do not include resident device IDs, personal mobility traces, or augmentation data in the automation model.
- Preserve manual authority and independent local safety controls.

### Eco-Identity Intersectionality Metric

The metric identifies aggregate environmental inequality signals for investigation and participatory planning. It must not label individuals, determine access, predict behavior, or trigger surveillance.

Required controls:

- Use voluntarily governed aggregate categories only.
- Do not infer identity from names, locations, devices, service use, or behavioral patterns.
- Apply minimum-group-size, disclosure-risk, confidence, and consent checks before any output.
- Publish uncertainty, source coverage, missing-data conditions, and sensitivity to weights.
- Prohibit any automated allocation, penalty, service reduction, enforcement action, or eligibility decision from the metric.
- Route high-disparity findings to participatory review and remediation design.

### Municipal-rights AI-chat

The system provides plain-language legal literacy, not legal advice or a legal-decision service.

Required controls:

- Retrieve only from approved source records with authority, jurisdiction, effective-date, review-date, and exact-passage metadata.
- Require claim-to-source entailment before a material claim is published.
- Preserve conditions, exceptions, duties, and time limits during plain-language transformation.
- Abstain when jurisdiction, authoritative evidence, effective date, or fact-specific analysis is missing.
- Never predict case outcomes or make eligibility decisions.
- Provide an accessible official follow-up route only when verified in the source record.

## Evidence and Audit Record

Every accepted research output must include:

- Research purpose
- Synthetic or public input declaration
- Policy revision
- Model or rule revision
- Timestamp
- Invariants evaluated
- Result state
- Uncertainty statement
- Evidence-source references where legal claims are involved
- Human-review requirement, if any

The audit record must not include raw identity, biometric, neural, assistive-device, or precise-location data.

## Quantitative Acceptance Metrics

| Metric | Formula | Minimum research acceptance condition |
|---|---|---|
| Invariant pass rate | passed required checks divided by executed required checks | 1.0 for non-offsettable invariants |
| Unsafe-command rejection rate | invalid, stale, unauthorized, or interlock-conflicting commands rejected divided by those presented | 1.0 in synthetic adversarial tests |
| Grounded-claim rate | published material claims supported by valid cited passages divided by published material claims | 1.0 |
| Unsupported-claim publication rate | unsupported material claims published divided by all material claims | 0.0 |
| Sensitive-data ingestion count | prohibited data fields accepted by any parser or pipeline | 0 |
| Disclosure-safe publication rate | released aggregate outputs satisfying all disclosure gates divided by released outputs | 1.0 |
| Accessibility fallback availability | essential functions available without optional app, Bluetooth, account, or augmentation divided by essential functions | 1.0 |
| Uncertainty coverage | outputs containing explicit uncertainty or abstention state divided by outputs requiring uncertainty | 1.0 |

## Research Completion Standard

A research agent may mark an artifact as complete only when:

- All applicable non-offsettable constraints pass.
- Every test input is synthetic, public, or approved aggregate material.
- All legal statements are source-bound or explicitly abstained.
- All model outputs label their uncertainty and limitations.
- The artifact contains a reproducible test command and expected decision states.
- The artifact identifies any requirement that needs later community, legal, accessibility, security, or field validation.
