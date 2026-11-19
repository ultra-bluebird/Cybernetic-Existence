# Runtime, Portability, Offline, and Tracking Completion Protocol

Protocol version: 1

## Scope

Complete and integrate:
- Runtime capability negotiation.
- Spatial-feature semantic portability.
- Offline task continuity.
- Tracking-loss degradation.

## Planned files

| Topic | Source | Test |
|---|---|---|
| Capability negotiation | kotlin/interoperability/RuntimeNegotiation.kt | tests/kotlin/interoperability/RuntimeNegotiationTest.kt |
| Semantic portability | kotlin/interoperability/SpatialPortability.kt | tests/kotlin/interoperability/SpatialPortabilityTest.kt |
| Offline continuity | kotlin/interoperability/OfflineContinuity.kt | tests/kotlin/interoperability/OfflineContinuityTest.kt |
| Tracking degradation | kotlin/interoperability/TrackingDegradation.kt | tests/kotlin/interoperability/TrackingDegradationTest.kt |

Package: augmentedhub.interoperability

## Dependencies

Shared foundation and validation patterns.

Domain scaffolding:
- CapabilityEvidenceMatrix.
- SemanticPortabilityRecord.
- OfflineTaskClasses.
- TrackingTransitionContract.

## Exact sequence

### Baseline and task contracts

- Identify exact source files and runtime contexts.
- Define essential outcomes independently of spatial rendering.
- Establish shared command and semantic task boundaries.

### Capability negotiation

- Require enabled, task-test, permission, reference, and expiry evidence.
- Distinguish support from current usability.
- Allow explicit reference-context non-applicability only for nonspatial features.
- Select only reviewed pathways.
- Keep a separately qualified nonspatial fallback.
- Invalidate evidence after relevant session, permission, or dependency changes.

### Semantic portability

- Transfer task meaning, units, context, source review, and uncertainty.
- Do not transfer or reuse source anchor handles by default.
- Require destination semantic review and local placement rebinding.
- Preserve exact action meaning.
- Keep transfer/import separate from encoding or candidate creation.

### Offline continuity

- Distinguish current content from historical content.
- Qualify local read, edit, cancel, and assistance-information tasks.
- Never label local preparation as remote submission, live update,
  or responder contact.
- Define cache expiry, eviction, restart, and draft ownership.
- Preserve work during reconciliation.
- Require fresh review when content, recipient, or authority changes.
- Do not silently transmit after reconnection.

### Tracking degradation

- Clear placement and pending spatial selection on loss.
- Preserve independent semantic task state.
- Require fresh reference evidence and explicit recovery approval.
- Reject stale revisions.
- Make repeated loss/stop handling idempotent.
- Enforce freshness before spatial use.
- Do not restore prior selections on recovery.

### Deliver tests

- Unsupported, missing, stale, denied, and conflicting capability evidence.
- Destination review missing or bound to another record.
- Source anchor reuse attempts.
- Cache loss, historical/current mismatch, and remote-task mislabeling.
- Tracking loss, reference change, stale acknowledgement, and clock fault.
- Selection cancellation and no resubmission.
- Actual adapter scripts for success, failure, silence, and stale revision.

### Integration and batch close

- Specify runtime invalidation, renderer, storage, and reconciliation adapters.
- Test actual nonspatial and assistive pathways.
- Supply four complete sources and four tests.
- Update ledger, registry, traceability, and session state.
- Keep delivery, local validation, integration, and deployment distinct.
