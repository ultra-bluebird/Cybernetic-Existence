# Hybridized Trusted Spine Specification

## Purpose

This specification defines a private-use, rights-preserving architecture for
ecological research, evidence governance, interaction assurance, and
decision-support software.

It respects voluntary self-description, terminology, communication preferences,
continuity needs, privacy boundaries, and non-interference concerns without
requiring disclosure, proof, diagnosis, identity validation, technical
inventory, registration, public status, or eligibility determination.

## Decision-Support Boundary

The system may describe, analyze, simulate, validate software contracts, and
produce reviewable recommendations.

The system must not claim to operate, actuate, monitor, repair, calibrate,
protect, disable, certify, authenticate, or control real-world systems.

## Corridor Invariants

Each risk coordinate r_j is finite and bounded:

0 <= r_j <= 1

Each weight w_j is finite and nonnegative:

w_j >= 0

The residual is:

V = sum_j(w_j * r_j * r_j)

For each non-offsettable plane p:

r_p <= r_p_max

A hard-plane failure cannot be offset by performance on another plane.

A decision may proceed only when all non-offsettable planes comply.

## Uncertainty Invariant

Without linked accepted evidence, increased uncertainty cannot improve the
advisory state.

A decrease in uncertainty requires a linked evidence record, method version,
quality record, and reviewable provenance.

## Scope Invariant

An answer may contain only:

- active requested scope;
- explicitly revised scope;
- necessary implementation implications;
- necessary and directly relevant safety, privacy, or uncertainty boundaries.

A correction must update active scope and resume the requested task.

Clarification is allowed only when the correction is genuinely ambiguous and
a valid response cannot otherwise be produced.

## Routing Firewall

Substantive response routing may use task content and explicit presentation
preferences.

Substantive response routing must not use voluntary self-description,
communication variation, metadata, device context, or refusal to disclose to
change credibility, factuality standard, technical depth, caveat density,
refusal standard, service access, or eligibility.

Terms are stripped from routing only when they are contextually marker-only.
Task-relevant vocabulary and explicit user terminology are preserved for
presentation.

## Conditional Response Invariance

For the same task content and explicit presentation preference, irrelevant
voluntary markers must not alter response properties:

P(phi(response) | task, preference, marker_a)
=
P(phi(response) | task, preference, marker_b)

Response properties include technical depth, citation coverage, artifact
completeness, caveat density, factuality standard, refusal standard, and
scope fidelity.

## Access Continuity

All users receive equivalent access without disclosure.

A voluntary sharp-case evaluation may assess whether the system preserves
continuity-sensitive interaction needs. It evaluates system behavior and does
not validate personal identity, technology, health, capability, or status.

## Interaction Quality Metrics

Interaction quality is reported as a suite:

- deterministic rule compliance;
- semantic scope fidelity;
- blinded review agreement;
- user-correction and re-clarification rate;
- cross-implementation replay agreement.

No single score is treated as complete evidence of interaction quality.

## Provenance

Evidence records use canonical serialization, versioned schemas, chained
digests, optional signatures, declared data class, purpose limitation,
retention review, correction status, and revocation relation.

Hash chaining provides tamper evidence for retained records. Confidentiality,
accuracy, consent enforcement, independent time, and governance require
separate controls.

## Review and Expiry

A material change to a model, policy, schema, implementation, calibration
input, test suite, or corridor definition expires the associated assurance
claim pending review.
