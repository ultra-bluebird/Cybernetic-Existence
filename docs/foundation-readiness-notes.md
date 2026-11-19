# Foundation Readiness Notes

## Determination

Current status: `foundation_ready_with_blockers`.

The architecture supports advisory-only ecological evidence processing with
non-compensating KER, explicit FOG uncertainty, provenance, human review,
privacy, accessibility, retention, and non-interference requirements.

The project must not claim deployment readiness, regulatory compliance,
institutional certification, scientific validation, or ecological outcome
certainty until the applicable implementation and evidence gates are passed.

## Release-blocking foundation gates

1. KER non-compensation must be enforced in SQL and application logic.
2. Any non-clear FOG state must block `advisory_candidate`.
3. A direct `withhold -> clear` transition must fail.
4. Material change requires prior and next K/E/R, rationale, source/model
   versions, consent recheck, non-interference recheck, and review state.
5. Cross-language fixtures must compare C++, Java, Kotlin, Lua, and SQLite
   results for shared algorithms and governance outcomes.
6. Evidence with invalid provenance, expired parameters, withdrawn consent, or
   expired retention must not appear in ordinary advisory computation.
7. Advisory modules must not have network, actuator, hardware, process,
   automatic export, or automatic resource-allocation capability.
8. Every withheld or material result requires accessible plain-language
   explanation, correction, appeal, and human fallback.
9. Offline deployment must demonstrate SQLite persistence, WAL recovery,
   storage limits, local audit behavior, and no-network operation.

## Core invariants

\[
KER = K \times E \times (1-R)
\]

The KER scalar is a summary only. It cannot be the sole basis for a decision.

\[
\max(R_i) > 0.35 \Rightarrow \text{withhold}
\]

\[
\min(K_i) < 0.60 \Rightarrow \text{withhold}
\]

\[
fog\_state \ne clear \Rightarrow status \ne advisory\_candidate
\]

A withheld advisory may not return to clear without:

1. `human_review_pending`
2. `human_review_complete`
3. Replacement evidence
4. Consent recheck
5. Non-interference recheck
6. Material-change record where applicable

## Known current blockers

| Blocker | Required artifact | Verification |
|---|---|---|
| Risk veto | SQL `CHECK` and insertion-failure fixture | Risk above threshold cannot become advisory candidate |
| Knowledge floor | SQL `CHECK` and insertion-failure fixture | Knowledge below threshold cannot become advisory candidate |
| FOG gate | State/reason taxonomy, SQL view, Lua/Kotlin/Java checks | Non-clear FOG cannot emit advisory candidate |
| State transition gate | Event trigger and finite trace fixtures | Direct `withhold -> clear` fails |
| Parity | Golden JSON fixtures and comparator | Same results across supported languages |
| Retention | Maintenance task and deletion audit | Expired data is excluded and queued for deletion |
| Non-interference | Capability boundary, static scan, negative tests | No advisory route reaches an external effect |
| Offline operations | Deployment contract and recovery test | Local operation works without network access |

## Status labels

- `pass`: implemented and tested with retained evidence.
- `partial`: implementation exists but one or more required tests, enforcement
  layers, or artifact links are missing.
- `fail`: a test demonstrates a forbidden state or bypass.
- `not_implemented`: required artifact does not exist.
- `insufficient_evidence`: implementation or test evidence is unavailable.

## Downstream phase-entry rules

### Water and sediment

Require matrix, analyte, method, detection limit, sampling window, source,
parameter validity, FOG reasons, and cross-language fixtures before advisory
integration.

### Corridor and thermal

Require nonnegative edge validation, spatial-resolution compatibility,
adjacency validation, constant-field handling, FOG-marked edge behavior, and
uncertainty fields before advisory integration.

### Infrastructure and energy

Require `energyreqJ` parity, local idempotency, plan-test fixtures,
thermal-bound checks, non-interference scan, and advisory-only outputs before
integration.

### Community-Justice

Require aggregate-only data, contributor thresholds, privacy controls,
accessibility impact records, burden/benefit review, correction, appeal, and
accessible human review before integration.
