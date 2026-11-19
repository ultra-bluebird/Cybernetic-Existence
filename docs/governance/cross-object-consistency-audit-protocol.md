# Cross-Object Consistency Audit Protocol

## Purpose

This protocol audits research objects, specifications, policies, schemas, code,
and documentation for implementation blockers, authority leaks, scope
collisions, and semantic ambiguity.

It does not determine identity, private-system status, medical status,
psychological continuity, legal standing, institutional eligibility, or
external authority.

## Pass one: implementation blockers

Pass one identifies must-fix findings.

A blocker exists when two artifacts make incompatible claims in the same scope,
when a required dependency is absent, when a required output is not produced,
when a schema cannot carry a required policy field, or when an artifact creates
an authority path prohibited elsewhere.

Pass-one categories:

- contradiction;
- dependency_gap;
- scope_collision;
- authority_leak;
- privacy_boundary_violation;
- schema_contract_mismatch;
- lifecycle_gap;
- unresolved_precedence.

## Pass-one finding template

```text
[BLOCKER-###]

Artifacts:
- [artifact A]
- [artifact B]

Type:
- contradiction | dependency_gap | scope_collision | authority_leak |
  privacy_boundary_violation | schema_contract_mismatch | lifecycle_gap |
  unresolved_precedence

Shared scope:
- [exact operation, data class, actor, or state transition]

Evidence:
- A: [exact statement, field, invariant, or code location]
- B: [exact statement, field, invariant, or code location]

Conflict:
- [why both conditions cannot hold in the same scope]

Resolution options:
- precedence rule;
- scope separation;
- schema or artifact addition;
- explicit successor revision;
- reject one behavior;
- introduce review_required boundary.

Recommended resolution:
- [specific option and rationale]

Acceptance test:
- [deterministic test, schema validation, or policy assertion]
```

## Pass-two: semantic and dependency mapping

Pass two begins only after all pass-one blockers are resolved, accepted under
an explicit scope rule, or recorded as a reviewed exception.

Pass two maps:

- overloaded terms;
- nested concepts;
- adjacent concepts;
- hidden preconditions;
- implicit data dependencies;
- implicit authority assumptions;
- vocabulary migration needs;
- intentional ambiguity.

## Pass-two finding template

```text
[OVERLAP-###]

Term:
- [term]

Artifact A use:
- [meaning, scope, and evidence]

Artifact B use:
- [meaning, scope, and evidence]

Relationship:
- distinct | nested | adjacent | equivalent | ambiguous

Implicit dependency:
- [whether one artifact relies on another interpretation]

Action:
- glossary entry | scope qualifier | adapter contract | intentional ambiguity note |
  no action required
```

## Acceptance conditions

Pass one is complete only when no unresolved blocker remains for a shared
operation or scope.

Pass two is complete only when every materially overloaded term has a glossary
entry, explicit scope qualifier, or an intentional ambiguity note.

Pass-two analysis must not delay a pass-one blocker correction.
