# Privacy Batch Completion Protocol

Protocol version: 1

## Scope

Complete and integrate:
- Privacy-preserving research trace.
- Gaze-data minimization.
- Local scene-processing boundary.
- Scene-data minimization for wayfinding.

This protocol does not itself deliver those implementations or authorize
modification of prior files.

## Planned source layout

| Topic | Source | Test |
|---|---|---|
| Research trace | kotlin/privacy/ResearchTrace.kt | tests/kotlin/privacy/ResearchTraceTest.kt |
| Gaze alternatives | kotlin/privacy/GazeMinimization.kt | tests/kotlin/privacy/GazeMinimizationTest.kt |
| Local boundary | kotlin/privacy/LocalProcessingBoundary.kt | tests/kotlin/privacy/LocalProcessingBoundaryTest.kt |
| Wayfinding minimization | kotlin/privacy/WayfindingMinimization.kt | tests/kotlin/privacy/WayfindingMinimizationTest.kt |

Package: augmentedhub.privacy

## Required existing foundation

- ResultState and CommonResult.
- Bounds.
- RedactedContent.
- Evidence markers.
- Guarded monotonic clock where elapsed time exists.
- Synthetic fixture vocabulary.
- Notice/state registry.
- Negative, stale/error, boundary, and adapter patterns as applicable.

## Required scaffolding

- TraceEvidenceClass.
- GazeAlternativeContract.
- LocalBoundaryInventory.
- WayfindingTaskMatrix.

## Exact sequence

### Baseline intake

- Identify the exact earlier source being extended or consolidated.
- If it is absent, request the necessary source rather than reconstructing it.
- Record existing defects, integration corrections, and limitations.
- Do not claim tests were previously executed.

### Contract review

- Confirm shared vocabulary and schema versions.
- Classify each public input and retained value.
- Declare time basis, retention, and error behavior.
- Identify applicable test categories and explicit non-applicable cases.

### Research trace implementation

- Return an evidence class per finding.
- Keep classification separate from execution outcome.
- Support only explicitly registered replay procedures.
- Preserve unsupported and restricted findings in the report.
- Do not promote synthetic replay to empirical reproduction.
- Retain recipes and approved parameters rather than private observations.
- Define trace-store ownership and expiry separately from metadata validation.

### Gaze-alternative implementation

- Bind task outcome, configuration, environment, and alternative.
- Review focus, preselection, confirmation, and recovery.
- Preserve failed and conflicting records.
- Do not request an explanation of why gaze is avoided.
- Keep an ordinary task's non-gaze pathway independent of gaze acquisition.
- Do not treat declarations as actual sensor inspection.

### Local-boundary implementation

- Include the mandatory component inventory.
- Require current context-bound inspection records.
- Review additional undiscovered paths explicitly.
- Separate report evaluation from operating-system enforcement.
- Preserve accessibility while reviewing caches and diagnostics.
- Do not use a passing result as an execution credential.

### Wayfinding implementation

- Classify the requested outcome before selecting data.
- Prefer semantic route access without capture.
- Require reviewed upstream acquisition for sensor-derived checkpoints.
- Keep pose/reference evidence transient.
- Require separate safety review for obstacle avoidance and egress validity.
- Do not retain movement history by default.

### Test delivery

For each source, supply a complete runnable test file.

At minimum cover:
- Invalid and excessive input.
- Missing, stale, expired, duplicate, and conflicting evidence.
- Out-of-scope evidence or data classes.
- Hidden gaze dependencies.
- Unknown boundary components or undocumented paths.
- Silent wayfinding task escalation.
- Clock faults where timing exists.
- No external-action authority.
- No sensitive content in diagnostic representation.

### Integration and reporting

For each topic provide:
- Direct answer.
- Model/formula with units.
- Complete source.
- Complete tests.
- Adapter and storage responsibilities.
- Known limitations.
- Preliminary design assessment with explicit basis.

Then:
- Update file ledger.
- Register domain schemas and vocabulary versions.
- Update red-team dispositions.
- Declare compilation and integration status separately.
- End with the fixed session-state block.

## Exit conditions

Delivery complete:
All four sources, four tests, and required notes are supplied.

Local validation complete:
The exact assembled source compiles and all applicable tests execute.

Integration qualified:
Actual storage, boundary enforcement, assistive technology, and runtime
behavior have been evaluated.

Deployment approval:
Separate accountable decision; never inferred from this protocol.

## Restrictions

No raw participant, gaze, neural, companion, or private scene data is required
to deliver the synthetic reference implementation.

No automatic capture, transfer, export, or hardware command.
