# Environmental Evidence and Social Duty Completion Protocol

Protocol version: 1

## Scope

Complete and integrate:
- Environmental evidence presentation.
- Social-duty acceptance auditing.

## Planned files

| Topic | Source | Test |
|---|---|---|
| Environmental presentation | kotlin/governance/EnvironmentalOverlay.kt | tests/kotlin/governance/EnvironmentalOverlayTest.kt |
| Social duties | kotlin/governance/SocialAcceptanceAudit.kt | tests/kotlin/governance/SocialAcceptanceAuditTest.kt |

Package: augmentedhub.governance

## Dependencies

Shared foundation and validation patterns.

Domain scaffolding:
- EvidenceFieldSet.
- SocialDutyAudit.

## Exact sequence

### Environmental presentation

- Require quantity, compatible unit, kind, period, production time,
  source, uncertainty, and method review.
- Keep extended notes optional and bounded.
- Preserve measurement/model/scenario distinctions.
- Label future model periods and historical measurements explicitly.
- Do not infer source truth from field presence.
- Do not infer restoration success from one value.
- Preserve essential information in accessible nonspatial output.
- Keep action recommendations outside unsupported evidence.

### Social-duty audit

- Audit all six required system duties.
- Do not accept person scoring, identity verification, or community scoring.
- Preserve voluntary self-description without making it a credential.
- Keep private CyberRank layers separate from public reporting.
- Do not target a higher voluntary-identification rate.
- Preserve violations and unresolved evidence.
- Keep correction, appeal, assistance, and ordinary service available.
- Publish only separately approved, minimized system findings.

### Deliver tests

Environmental:
- Missing fields, incompatible units, malformed periods, future production time.
- Model/measurement/scenario confusion.
- Stale and historical presentation.
- Invalid optional notes.
- Nonvisual preservation of meaning and uncertainty.

Social duties:
- Missing, duplicate, conflicting, expired, and violated duty evidence.
- Out-of-scope personal or community assessment.
- Matched service cases with irrelevant voluntary markers.
- No public personal status or identity-score output.

### Integration

- Specify source-method and uncertainty review responsibilities.
- Test actual presentation comprehension and assistive outputs.
- Define grievance, correction, and remedy pathways.
- Distinguish system findings from reported experiences.
- Do not claim universal social acceptance from a service audit.

### Batch and session close

- Supply both complete sources and tests.
- Update the full scoped ledger.
- Register all new transported/persisted schemas and vocabulary versions.
- Update every open red-team disposition.
- Report compilation, tests, integration, and unresolved limits.
- End with the fixed session-state declaration.

## Final completion boundary

The sequence is delivery-complete only after actual constituent artifacts
are supplied. Deployment qualification remains separate.
