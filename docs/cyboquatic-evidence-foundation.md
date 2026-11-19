# Cyboquatic Evidence Foundation

## Status

This document defines the evidence, claim, and validation structure for
Cyboquatic ecological-restoration research artifacts.

It does not certify machinery, environmental performance, regulatory
approval, scientific validity, operator competency, or deployment safety.
Such conclusions require project-specific evidence and appropriate
independent review.

## Claim classes

| Class | Meaning | Minimum evidence |
|---|---|---|
| Reference claim | A source, standard, specification, or repository convention exists. | Stable citation, version or revision, retrieval date, and quoted scope. |
| Design claim | A project artifact implements a stated requirement. | Source path, revision identifier, tests, and review record. |
| Measurement claim | A measured observation occurred under recorded conditions. | Method, instrument, calibration status, units, timestamp, uncertainty, and provenance. |
| Performance claim | A system met a bounded criterion in a defined evaluation. | Acceptance criterion, test protocol, sample or run record, results, limitations, and reviewer. |
| Environmental claim | A modeled or measured environmental effect occurred. | Functional unit, system boundary, baseline, inventory, uncertainty, and independent review plan. |
| Compliance claim | A requirement was assessed against a specified authority. | Jurisdiction, applicable instrument, assessment date, evidence, and responsible reviewer. |

## Evidence hierarchy

1. Primary legal, regulatory, standards-body, manufacturer, utility, or laboratory record.
2. Versioned source specification, formally maintained protocol, or peer-reviewed study.
3. Project-controlled test output with reproducible inputs and documented environment.
4. Secondary explanation, industry summary, or design rationale.
5. Hypothesis, projection, estimate, or unvalidated implementation proposal.

Artifacts MUST label evidence at its actual hierarchy level.
A higher-level conclusion MUST NOT be inferred solely from a lower-level item.

## Source binding

Every substantive claim MUST contain:

- `claim_id`: stable local identifier.
- `claim_class`: one of the documented claim classes.
- `statement`: bounded plain-language assertion.
- `scope`: system, geography, equipment class, time range, and operating context.
- `source_ref`: stable source identifier and version or revision.
- `source_status`: standard, regulation, draft, study, repository convention, test record, or hypothesis.
- `assumptions`: conditions required for the statement to remain applicable.
- `limitations`: known exclusions and non-claims.
- `evidence_location`: repository-relative path or controlled evidence record.
- `review_status`: draft, reviewed, accepted-for-design, superseded, or withdrawn.
- `invalidation_conditions`: observations or changes that require reassessment.

## Design controls

Cyboquatic artifacts MUST:

- Operate fail-closed when a required safety, integrity, consent, or configuration invariant is not satisfied.
- Separate monitoring, advisory analysis, and physical actuation authority.
- Require explicit human authorization and equipment-specific safety interlocks for physical actuation.
- Preserve offline operation for the critical safety path.
- Minimize collection of personal, biometric, neural, companion-system, and location data.
- Keep governance references separate from machine authentication, authorization, and actuation credentials.
- Use purpose limitation, explicit retention periods, deletion procedures, and access logging for sensitive records.
- Provide accessible operator documentation, plain-language failure states, and a human fallback path.
- Record uncertainty and model limitations rather than presenting estimates as measurements.

## Evidence gates

A design claim may advance to `accepted-for-design` only when:

1. Its source scope matches the intended use.
2. The source version is recorded.
3. The project-specific adaptation is documented.
4. Automated tests cover the stated invariant where software implements it.
5. A designated reviewer accepts the residual-risk statement.

A performance claim may be published only when:

1. The acceptance criterion is declared before the test.
2. Test conditions and instrumentation are recorded.
3. Units, tolerances, and uncertainty are recorded.
4. Failures and exclusions are retained with successful runs.
5. The result names the tested equipment configuration and software revision.

An environmental claim using “carbon-negative,” “net-negative,” or equivalent language
may be published only when:

1. The functional unit is explicit.
2. The full declared life-cycle boundary is explicit.
3. The baseline and allocation method are explicit.
4. Measurement and estimation methods are distinguishable.
5. Sensitivity and uncertainty results are retained.
6. The claim is reviewed at the appropriate level for its intended audience.

## Non-substitution rule

A repository convention, an academic paper, an Internet-Draft, a simulation,
or a software test MUST NOT be represented as:

- a permit;
- a safety certification;
- a machinery commissioning record;
- an environmental impact finding;
- an identity verification;
- a consent record;
- an operational authorization; or
- a public eligibility determination.

## Review cadence

- Source references: review when a version changes or at least annually.
- Draft specifications: review when a new draft revision is published.
- Equipment interfaces: review before each commissioning stage and after material changes.
- Environmental calculations: review after each boundary, inventory, or operational change.
- Privacy and credential controls: review after key rotation, access-policy change, incident, or data-purpose change.

## Minimum artifact manifest

Each dated Cyboquatic artifact directory MUST include a manifest that identifies:

- date label and time basis;
- directory purpose;
- selected Phoenix anchor reference;
- artifact inventory;
- source references and their status;
- test commands and expected outcomes;
- safety boundaries and non-actuation statement;
- data classes, purpose, consent scope, retention period, and deletion procedure;
- reviewer role and review status;
- known limitations and next validation step.
