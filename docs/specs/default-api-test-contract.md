# Augmented-Hub Default API Test Contract

## Test naming

Use:

- `returns_observe_when_*`
- `holds_for_review_when_*`
- `rejects_when_*`
- `does_not_accept_*`
- `does_not_emit_*`
- `preserves_*`
- `requires_*`

## Required tests for every public API

1. Valid non-sensitive input.
2. Missing required source or provenance.
3. Unknown or expired evidence.
4. Missing uncertainty where uncertainty is required.
5. Missing review owner where review is required.
6. Prohibited identity, biometric, credential, device, health, or neural-data field.
7. Actuation, firmware, or physical-control semantics.
8. Deterministic repeat execution.
9. Output contains `nonActuating: true`.
10. Output contains `identityNeutral: true`.

## Required tests for risk and corridor APIs

1. RoH above 0.30 returns `HOLD_FOR_REVIEW` or `REJECT`.
2. A less protective corridor evolution is rejected.
3. Missing input remains unknown and never defaults to zero.
4. Incomplete evidence bundle cannot support a stronger claim.
5. A completed boundary cannot omit method, provenance, uncertainty, or reviewer.
6. An unresolved contradiction cannot become an accepted conclusion.
