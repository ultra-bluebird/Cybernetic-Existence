# Psych-Continuity Formal Discipline

## Scope

This discipline supports record-level continuity assessment across transformation,
summarization, compression, forking, migration, policy revision, and long-horizon
review.

It preserves declared continuity claims, policy constraints, provenance, uncertainty,
and review history.

It does not certify:

- Identity.
- Consciousness.
- Subjective memory.
- Bodily continuity.
- Health status.
- Cybernetic status.
- Augmentation status.
- Real-world host migration.
- Legal ownership or institutional standing.

## Formal tuple

P = (M, Π, V, E, R, Q)

Where:

- M is a declared memory and provenance graph.
- Π is a portable policy bundle.
- V is a versioned declared value vector.
- E is an optional, private embodiment-context boundary.
- R is a signed provenance and derivation chain.
- Q is a human-review and correction record.

## Record-level guarantee

The discipline can determine whether the declared record components remain:

- Linked.
- Versioned.
- Reviewable.
- Correctable.
- Policy-consistent.
- Explicit about omissions.
- Explicit about uncertainty.
- Portable across approved transformations.

The discipline cannot determine whether a person is the same person, whether a
subjective experience continues, or whether physical or cybernetic migration occurred.

## Invariants

### PC-1: Non-silent history

No transformation, correction, migration, fork, merge, or revocation may silently
overwrite a predecessor record.

### PC-2: Transformation disclosure

Every transformation must declare:

- Source reference.
- Successor reference.
- Transformation kind.
- Retained scope.
- Summarized scope.
- Omitted scope.
- Uncertainty introduced.
- Human-review status.

### PC-3: Policy continuity

A successor must preserve required policy invariants or record an explicit,
human-reviewable policy divergence.

### PC-4: Declared-value integrity

Values are voluntary declarations. A system may preserve, compare, and version a
declared value vector. It must not infer values from language, metadata, conduct,
communication mode, refusal to disclose, or external profiling.

### PC-5: Provenance continuity

Every successor must carry a signed or witnessed edge to its predecessor unless the
absence of a predecessor is explicitly declared and reviewed.

### PC-6: Uncertainty preservation

Missing, ambiguous, disputed, transformed, or unavailable information must remain
visible as such. Silence is not evidence of absence, failure, or discontinuity.

### PC-7: Correction continuity

Every record must retain an accessible correction route. A correction creates a linked
successor record and never silently erases the historical relationship.

### PC-8: Certification boundary

No psych-continuity status may be used to certify, deny, rank, authenticate, diagnose,
or determine eligibility for any person or community.

## Operators

- append(record): add a signed successor event.
- transform(record, manifest): create a declared transformation edge.
- fork(record, intent): create a divergent successor with lineage.
- merge(records, resolution): reconcile compatible branches without erasing history.
- review(record, finding): attach human review or correction outcome.
- revoke(record, reason): change active status through a linked revocation.
- map(source_node, target_node): declare graph correspondence.
- compare(left, right): produce an uncertainty-aware record comparison.

## Human-review rule

Any material change to M, Π, V, E, R, or Q requires renewed human review.

A material change includes:

- Altered source or successor references.
- New omission category.
- New policy constraint or removed policy safeguard.
- Changed declared-value vector.
- Changed disclosure boundary.
- Changed retention or deletion policy.
- Changed correction, appeal, or non-retaliation pathway.
- Changed provenance, witness, or signature reference.

## Outcome vocabulary

Permitted results:

- `record_continuity_supported`
- `record_continuity_partially_supported`
- `provenance_gap`
- `policy_invariant_violation`
- `declared_value_difference`
- `transformation_omission_disclosed`
- `human_review_required`

Prohibited results:

- `identity_confirmed`
- `identity_denied`
- `consciousness_confirmed`
- `memory_experience_confirmed`
- `embodiment_confirmed`
- `cybernetic_status_confirmed`
- `host_migration_confirmed`
- `continuity_failure`
