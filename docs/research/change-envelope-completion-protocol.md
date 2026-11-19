# Material Change and Continuity Envelope Completion Protocol

Protocol version: 1

## Scope

Complete and integrate:
- Material-change review gate.
- Private continuity envelope.

## Planned files

| Topic | Source | Test |
|---|---|---|
| Material-change review | kotlin/continuity/MaterialChangeGate.kt | tests/kotlin/continuity/MaterialChangeGateTest.kt |
| Continuity envelope | kotlin/continuity/PrivateContinuityEnvelope.kt | tests/kotlin/continuity/PrivateContinuityEnvelopeTest.kt |

Package: augmentedhub.continuity

## Dependencies

Shared foundation, standards, registry, and applicable test patterns.

Domain scaffolding:
- MaterialChangeFacets.
- EnvelopeSchema.

## Exact sequence

### Establish the baseline

- Obtain the exact prior source and schema versions.
- Record unresolved defects and integration corrections.
- Identify actual storage and deployment boundaries.
- Do not infer source availability from a session marker.

### Implement material-change review

- Enumerate every required facet.
- Bind each review to the prior and proposed artifact/facet commitments.
- Require a disposition for unchanged as well as changed facets.
- Treat changed artifacts with unchanged facets as unclassified changes.
- Preserve rejected, duplicate, conflicting, and expired evidence.
- Require a new review after the proposal changes.
- Return review findings, not deployment credentials.
- Preserve prior accessible operation during review.

### Implement the envelope

- Use selected portable preferences.
- Use the closed approved-context vocabulary for this schema version.
- Preserve fixed exclusions and import rules.
- Reject unknown fields, weakened rules, unsupported versions, duplicates,
  malformed encoding, and trailing data.
- Produce a preview/import candidate rather than automatic application.
- Permit selective removal without extending expiry.
- Do not imply that import expiry deletes existing copies.
- Keep transfer approval separate from encoding.

### Deliver tests

Material-change tests:
- Missing facets and mismatched artifact bindings.
- Changed proposal after approval.
- Unclassified changes.
- Rejections, duplicates, stale records, and expired context.
- No deployment authority.

Envelope tests:
- Exact round trip.
- Selective omission.
- Missing or altered exclusions/import rules.
- Unsupported version and malformed encoding.
- Future-issued and expired envelope.
- No credential use or automatic import.

### Complete integration notes

- Identify trusted commitment construction and review authentication.
- Explain atomic baseline comparison at deployment/application boundaries.
- Document cross-device time trust.
- Document retention, backup, and copy ownership.
- Keep arbitrary private prose outside the closed schema.

### Close the batch

- Supply both complete sources and both tests.
- Provide formulas, limits, integration, and design assessments.
- Update ledger, registry, and traceability.
- State compilation and integration evidence precisely.
- End with the fixed session-state declaration.

## Exit levels

Delivery complete:
Two sources, two tests, and required notes supplied.

Local validation complete:
Exact assembled files compile and tests execute.

Integration qualified:
Actual storage, import, review, and deployment boundaries evaluated.

Deployment approved:
Separate accountable approval; not inferred from this protocol.
