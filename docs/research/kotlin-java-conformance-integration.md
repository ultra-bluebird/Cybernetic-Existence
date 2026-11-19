# Kotlin and Java Conformance Integration

## Purpose

The Kotlin and Java conformance engine evaluates local research inputs against the Augmented-Hub metric registry and governance requirements.

The engine supports advisory planning, maintenance review, evidence-quality review, accessibility barrier review, heat-resilience planning, sensor-alignment assessment, ecological infrastructure research, and safe automation governance.

The engine does not authorize physical actions, deny services, score people, identify people, infer disability, infer health, infer augmented or cybernetic status, or require continuous connectivity.

## Local-first operation

The engine reads local metric registry entries, policy manifests, documentation CSV headers, and explicitly selected non-sensitive environmental columns.

Sensitive records remain local-only. The engine must minimize columns before reading CSV values and must not emit raw rows, identities, private coordinates, health information, neural information, assistive-technology information, augmented-status information, or device identifiers.

## Policy order

The conformance engine applies this order:

1. Block prohibited person-level, eligibility, identity, biometric, behavioral, and cybernetic-status requests.
2. Validate that the metric registry entry retains all required governance protections.
3. Validate evidence completeness, freshness, compatibility, calibration, and conflict state.
4. Preserve metric-specific protective states such as insufficient evidence, calibration review, reduced automation, and fail-safe mode.
5. Apply accessibility, privacy, consent, rights-alignment, and human-review gates non-compensatorily.
6. Return an advisory-only conformance result with an accessible explanation and a review path.

No high score can override a failed protected gate.

## Supported results

| Result | Meaning |
|---|---|
| `INFORMATIONAL_ONLY` | A non-consequential explanation or classification with no planning recommendation |
| `ADVISORY_ONLY` | A bounded research or planning result that retains uncertainty and review requirements |
| `ELIGIBLE_FOR_PLANNING_USE` | Evidence may inform planning only after all declared protected gates pass; it is not service authorization |
| `NEEDS_REVIEW` | Evidence or protected conditions require accessible human review |
| `INSUFFICIENT_EVIDENCE` | Required evidence is missing, incompatible, stale beyond its valid limit, uncalibrated, or too uncertain |
| `CONFLICTED` | Records cannot be reconciled automatically and must preserve both sides for review |
| `LOCAL_ONLY` | Information must remain on the local device or approved local environment |
| `BLOCKED_BY_POLICY` | The requested use is prohibited |

## Build and tests

When the repository includes a Gradle wrapper and the Kotlin toolchain is already available, run:

```sh
./gradlew -p kotlin/conformance test
```

When the wrapper or required local build tool is not available, do not install tools. Preserve the source and test artifacts for the next configured build environment.

Do not run Cargo commands for this conformance module.

## Expected inputs

- Metric registry entries under `schemas/governance/metric_registry_entries/`
- Community-observation schema under `schemas/evidence/`
- Local conformance-policy manifest
- Existing local documentation CSV files under `docs/`
- Explicit, non-sensitive calculation inputs
- Declared policy and semantic versions

## Expected output

Each output includes:

- Metric name and semantic version
- Policy-manifest version
- Advisory output class
- Evidence state
- Release class
- Reason codes
- Uncertainty summary
- Accessible explanation
- Human-review indication
- Explicit confirmation that no person assessment, identity resolution, cybernetic-status assessment, automated service decision, or physical action was authorized
