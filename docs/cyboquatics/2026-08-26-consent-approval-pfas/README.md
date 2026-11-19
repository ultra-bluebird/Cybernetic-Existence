# Consent Revocation, External Approval, and PFAS Review

This artifact set implements advisory-only decisions. It does not operate valves, pumps, gates, motors, chemicals, trains, buses, or any other physical device.

## Consent Revocation Pathway

A revocation applies to a specific consent subject, data class, purpose, and scope. The local processor must complete these steps in order:

1. Validate that the revocation request identifies the consent record and purpose without demanding unrelated identity, neural, biometric, or device data.
2. Change the consent state to `REVOKED`.
3. Immediately stop new collection, inference, sharing, and other processing under that consent scope.
4. Locate active records, queued work, local caches, derived records, and registered downstream recipients connected to that scope.
5. Freeze queued processing and prevent re-use for the revoked purpose.
6. Create an export package when requested and technically feasible without exposing other people’s data.
7. Run retention review. Delete data that no longer has an independently documented retention basis; preserve only the minimum required audit evidence.
8. Notify registered downstream processors through a revocation notice containing the minimum necessary scope information.
9. Create a minimized audit event that records the event type, scope reference, timestamps, and completion state, but not raw neural, biometric, environmental, or identity data.
10. Provide an accessible correction, appeal, and human-support route.

A revocation must never cause loss of essential civic, health, mobility, water, sanitation, accessibility, or community services.

## External-Action Approval Gate

An automated component may calculate, describe, log, and prepare a human-readable approval packet. It may not authorize, transmit, or execute a physical valve change.

A proposed valve change remains `HUMAN_APPROVAL_REQUIRED` unless all of the following are present:

- A qualified human approver identifier.
- A current qualification record scoped to the asset and action class.
- A separate, documented approval for the exact target valve and exact requested change.
- A timestamp, expiry time, purpose, risk review, and accessible explanation.
- Independent safety interlock and site-procedure verification.
- An audit record.

Even when all fields are present, this artifact returns only `APPROVAL_PACKET_COMPLETE`. A separately governed, safety-certified control system and qualified human must perform any physical action.

## PFAS Residual Corridor

Use consistent concentration units for observed value, modeled value, and uncertainty.

`residual = abs(observed_concentration - modeled_concentration) / uncertainty`

The observation is `PFAS_REVIEW_REQUIRED` when:

- `residual > 1.0`
- `harm_risk_r > 0.30`
- Any value is non-finite.
- `uncertainty <= 0`.
- Required sample provenance, analytical method, calibration, or chain-of-custody evidence is absent.

Otherwise it is `PFAS_WITHIN_SCREENING_CORRIDOR`.

This is a screening result, not a prediction of safety, exposure, compliance, remediation success, or contaminant fate. PFAS occurrence and analytical coverage vary by compound, medium, location, and method; the result must retain those uncertainties.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.89 | Explicit state transitions, bounded residual, provenance checks |
| eco_impact_value | 0.82 | Prevents inappropriate reuse and false fate-confidence claims |
| harm_risk | 0.12 | Human-only external approval and fail-closed review |
| accessibility_impact | 0.91 | Revocation, export, correction, appeal, and support path |
| rights_alignment | 0.97 | Revocable consent, purpose limitation, minimization, and oversight |
