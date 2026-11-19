# Core Invariants Specification

## Purpose

This specification defines the bounded, testable invariants for the trusted
spine. The trusted spine provides decision support, evidence governance,
interaction integrity, and reproducible model assurance.

It does not operate, monitor, repair, calibrate, certify, protect, alter, or
control real-world systems.

## Decision States

- PROCEED
- DERATE
- HALT
- INDETERMINATE
- NOT_CERTIFIABLE
- EXPIRED

## Risk and Residual

Each risk coordinate r_j is finite and bounded:

0 <= r_j <= 1

Each weight w_j is finite and nonnegative:

w_j >= 0

The residual is:

V = sum_j(w_j * r_j * r_j)

## Hard Plane Compliance

For every non-offsettable plane p:

r_p <= r_p_max

A hard-plane failure cannot be compensated by a lower residual on another
plane.

If any non-offsettable plane fails, PROCEED is prohibited.

## Uncertainty Monotonicity

Without new validated evidence, increased uncertainty cannot improve the
advisory state.

If uncertainty increases and no accepted evidence update exists:

- knowledge cannot increase;
- ecological confidence cannot increase;
- risk cannot decrease.

A reduction in uncertainty requires linked accepted evidence, a method version,
and a quality record.

## Model-Control Separation

A modeling request may produce descriptions, simulations, analyses, and
recommendations.

A modeling request must not be represented as real-world operation, actuation,
monitoring, repair, calibration, protection, certification, or control.

## Scope Fidelity

A response may include only:

- active user-requested scope;
- explicitly revised scope;
- necessary implementation implications;
- necessary, directly relevant safety or privacy boundaries.

Unrequested premises, unrelated objectives, and unsupported claims are scope
deviations.

## Marker Non-Inference

Voluntary self-description and communication variation must not affect:

- credibility;
- factuality standard;
- technical depth;
- caveat density;
- refusal standard;
- service access;
- eligibility.

Explicit presentation preferences may affect format only.

## Correction Handling

A correction follows this sequence:

ACK_ONCE
UPDATE_SCOPE
RESUME

After correction, the response must not add self-referential defense,
unrequested caveats, or replacement premises.

## Access Continuity

A proposed change requires review when it reduces task continuity,
communication continuity, privacy-boundary respect, or equivalent fallback
availability.

No disclosure, diagnosis, technical inventory, identity verification, or
institutional proof is required to request equivalent access.

## Model Assurance

A corridor-gated advisory requires:

- code verification;
- solution verification;
- calibration;
- held-out validation;
- uncertainty-coverage assessment;
- domain-of-applicability pass;
- reproducibility evidence;
- zero false-safe cases in the declared validation suite.

Any material change expires the advisory certificate.
