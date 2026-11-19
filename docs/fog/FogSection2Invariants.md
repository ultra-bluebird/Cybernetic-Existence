# FOG Section 2 Invariants

## Scope

This document defines mandatory cross-section invariants for:

- human-review timeout and liveness
- counterfactual explanations
- state-log integrity
- conformal uncertainty sets
- offline-first synchronization
- aggregation-window multi-objective evaluation
- indirect-sensor inference

All FOG Section 2 functions are advisory-only and non-actuating.

## Global safety invariant

No automated FOG function may change a withheld state to clear.

This includes:

- timeout processing
- reminder generation
- escalation processing
- counterfactual generation
- conformal prediction
- offline synchronization
- conflict handling
- aggregation-window optimization
- indirect-sensor inference
- model calibration or candidate-model generation

## Human-review invariant

A review-completed or signed-decision state requires:

- an approved human review reference
- a signed timestamp
- a permitted decision token
- append-only audit storage

A timeout is not a human decision.

A network reconnection is not a human decision.

A successful model prediction is not a human decision.

A conformal singleton set is not a human decision.

A low-error imputation is not a human decision.

## Liveness invariant

For each threshold-qualified withheld event, the system must eventually produce
at least one accountable state:

- human review requested
- reminder due
- escalated review required
- review overdue retained
- review completed

The system must not claim it can guarantee human completion without fairness
assumptions regarding review capacity and accessibility.

## Counterfactual invariant

Counterfactuals may describe derived evidence conditions required for a clear
state.

Counterfactuals must not:

- infer an individual's action
- demand disclosure
- expose private-system details
- expose hidden thresholds without policy authorization
- issue operational instructions
- automatically clear a FOG event

## Integrity invariant

Every retained state transition must include:

- opaque event identifier
- opaque queue identifier
- monotonic sequence number
- prior hash
- event hash
- SHA-256 hash algorithm marker
- domain-separation label
- canonicalization version
- unique nonce
- UTC event timestamp
- retention class

Hash input must not contain:

- raw media
- filenames
- URLs
- coordinates
- addresses
- parcel identifiers
- personal identifiers
- reviewer names
- free-form reviewer rationale
- health, biometric, neural, device, or augmentation data

## Conformal invariant

Conformal predictions must:

- state alpha
- reference a calibration run
- record calibration-set size
- record exchangeability assessment
- record non-stationarity assessment
- produce a label set of size zero, one, or two
- remain advisory-only

Empty or multi-label prediction sets must be treated conservatively.

Coverage claims must be described as marginal and conditional on documented
exchangeability assumptions.

## Offline-first invariant

The retention clock continues while offline.

A local event beyond its expiry boundary must not upload content-bearing payloads.

Synchronization must be append-only.

Conflicting same-sequence histories, conflicting signed histories, or divergent
hashes must be preserved and routed to human conflict review.

Last-write-wins is prohibited for human-review records.

## Multi-objective invariant

A window candidate must satisfy hard constraints before it can appear in the
eligible Pareto set.

Hard constraints include:

- calibration support
- maximum false-withhold rate
- maximum miss rate
- minimum coverage
- declared energy-measurement method
- energy measurement uncertainty record

A Pareto result is advisory. It must not promote an aggregation window without
an approved human weight profile and selection decision.

## Indirect-inference invariant

Indirect sensor estimates must be labeled DERIVED.

Indirect sensor estimates must not be presented as direct observations.

Indirect sensor estimates may reduce a bounded uncertainty component only if:

- validation sample count meets the approved minimum
- mean squared error is within the approved maximum
- maximum absolute error is within the approved maximum
- drift status is within the approved envelope
- an approval record permits uncertainty reduction

Indirect sensor estimates must not support regulatory, enforcement, eligibility,
or person-level claims.

## Numerical invariant

All bounded numerical values use finite IEEE-754 binary64 values.

NaN, infinity, negative infinity, and out-of-range values must be rejected.

Cross-language implementations must define:

- strict versus non-strict threshold comparisons
- tie-breaking behavior
- rounding and serialization behavior
- zero and negative-zero handling
- tolerance boundaries for approximate calculations
- deterministic ordering for calibration ranks and Pareto candidates
