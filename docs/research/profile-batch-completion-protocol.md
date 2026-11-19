# Profile and Terminology Batch Completion Protocol

Protocol version: 1

## Scope

Complete and integrate:
- Host-defined interface profile portability.
- Protected terminology continuity.
- Interface-only psych-continuity preference preservation.

## Planned source layout

| Topic | Source | Test |
|---|---|---|
| Profile portability | kotlin/continuity/ProfilePortability.kt | tests/kotlin/continuity/ProfilePortabilityTest.kt |
| Terminology continuity | kotlin/continuity/TerminologyContinuity.kt | tests/kotlin/continuity/TerminologyContinuityTest.kt |
| Interface fidelity | kotlin/continuity/InterfaceContinuity.kt | tests/kotlin/continuity/InterfaceContinuityTest.kt |

Package: augmentedhub.continuity

## Dependencies

Shared foundation and applicable test patterns.

Scaffolding:
- PreferencePortabilitySchema.
- TerminologyDiffProtocol.
- PsychContinuityBoundary.

## Exact sequence

### Baseline and authority

- Obtain the exact prior implementation being changed.
- State whether work is consolidation, extension, or correction.
- Preserve prior user terminology and preferences.
- Do not claim private-system verification.

### Profile portability

- Use the portable/local-only/forbidden field classification.
- Export only explicitly selected portable fields.
- Reject prohibited fields rather than silently accepting them.
- Keep local pairing and assistive configuration separate.
- Provide strict versioned decoding if wire transport is implemented.
- Produce an import candidate and preview, not automatic application.
- Make absence of a profile compatible with ordinary service access.
- Do not create an authentication or eligibility token.

### Terminology continuity

- Preserve exact literal text.
- Distinguish rewording, insertion, deletion, and reordering.
- Bind corrections to exact expected wording.
- Use explicit migration for sequence changes.
- Return NOT_ESTABLISHED for unknown positions.
- Do not infer term correspondence from similarity.
- Bind reviewed application to the current baseline.
- Retain historical/correction metadata without unnecessary private content.

### Interface continuity

- Evaluate presentation, terminology, pacing, drafts, and correction.
- Reject requests for diagnosis, emotional state, competence, fatigue,
  cognitive load, or internal psychological evaluation.
- Keep reported fidelity distinct from independently tested interface behavior.
- Preserve correction and assistance during update review.

### Tests

Supply one complete test file per source.

Include:
- Selective export and omission.
- Unknown fields and unsupported versions.
- Malformed encodings and trailing content where decoding exists.
- Exact Unicode and protected-term preservation.
- Wrong expected wording and unknown positions.
- Insert/delete/reorder behavior.
- Stale baseline and mismatched review binding.
- Mixed interface/personal assessment requests.
- Duplicate and expired evidence.
- Redacted diagnostic output.
- No credential or external-action use.

### Integration

- Specify actual profile store and application transaction boundaries.
- Explain where draft durability and kiosk handover are implemented.
- Identify cross-session review and time requirements.
- Do not claim that in-memory references survive restart.
- Do not claim that clearing a string erases all copies.

### Batch close

- Provide integration notes and limitations per topic.
- Label design estimates as estimates.
- Update file ledger and version registry.
- Update traceability.
- Report tests supplied versus executed.
- End with the fixed session-state format.

## Exit conditions

Delivery, local validation, integration qualification, and deployment approval
remain separate levels.

Completing the reference code does not establish psychological continuity,
identity certification, or real private-system operation.
