# Cyboquatic FOG Router — 2026-08-26

## Purpose

This local-first artifact set routes ecological-restoration observations through a conservative, non-actuating decision-support workflow. It recognizes explicit uncertainty and never converts FOG (unmodeled media, unknown contaminant behavior, missing context, or material uncertainty) into a safe result.

The software does not operate machinery, valves, pumps, drains, or other physical infrastructure. It produces validation outcomes and review-ready explanations only. Any operational use requires qualified human review and a separately reviewed, human-authorized integration adapter.

## Deterministic task selection

- Task date: `2026-08-26`
- Gregorian day of year: `238`
- Domain index: `3`
- Selected domain: `FOG-router`
- Stable daily seed: `2382026`
- Variant: `21`
- Sub-task: conservative routing of incomplete or unmodeled water-media observations

The selection calculation is deterministic task rotation only. It is not cryptographic hashing.

## Architecture

Each implementation accepts the same conceptual observation:

- `node_id`: pseudonymous CanalNode identifier
- `observed_at`: UTC timestamp text
- `media_classification`: limited media label
- `confidence`: evidentiary confidence, 0.0–1.0
- `measurement_completeness`: completeness, 0.0–1.0
- `fog_state`: explicit uncertainty flag
- `flow_m3_s`: flow rate in cubic metres per second
- `water_temperature_c`: water temperature in degrees Celsius
- `measurement_quality`: integrity/quality value, 0.0–1.0
- `K`, `E`, `R`: knowledge quality, ecological impact value, and harm risk, each 0.0–1.0
- `consent_active`: whether the purpose-limited measurement record remains authorized

Routing is deterministic:

1. Invalid, non-finite, expired, unauthorized, or inconsistent inputs route to `REJECTED_INPUT`.
2. Explicit FOG, unknown media, incomplete context, or evidence needing inspection routes to `FOG_REVIEW`.
3. High-risk observations where `R > 0.30` route to `QUARANTINED_INPUT`.
4. Only sufficiently complete, non-FOG, known-media records with bounded K/E/R values route to `KNOWN_MEDIA`.

`KNOWN_MEDIA` means only that the observation is suitable for human review in a known-media workflow. It does not authorize autonomous action or establish environmental safety.

## File inventory

- `cpp/fog_router.cpp` — C++20 command-line validator and router
- `java/FogRouter.java` — Java 17+ command-line validator and router
- `kotlin/FogRouter.kt` — Kotlin/JVM command-line validator and router
- `lua/fog_router.lua` — Lua 5.4 command-line validator and router
- `sql/fog_router.sql` — SQLite schema, indices, view, and example query
- `aln/fog_router_policy.aln` — ALN v2-compatible local policy draft

## Build and run

All programs use only their language standard libraries.

### C++20

Build:

```text
c++ -std=c++20 -Wall -Wextra -pedantic cpp/fog_router.cpp -o fog_router_cpp
```

Run:

```text
./fog_router_cpp canal-A17 2026-08-26T07:30:00Z freshwater 0.91 0.95 false 0.42 18.4 0.93 0.90 0.70 0.12 true
```

Expected output:

```text
route=KNOWN_MEDIA
code=KNOWN_MEDIA_READY
explanation=Known media with complete, authorized evidence is suitable for human review only; no physical action is authorized.
```

FOG example:

```text
./fog_router_cpp canal-A17 2026-08-26T07:30:00Z unknown 0.91 0.95 true 0.42 18.4 0.93 0.90 0.70 0.12 true
```

Expected output:

```text
route=FOG_REVIEW
code=FOG_EXPLICIT
explanation=FOG is explicit or the media is unknown; preserve uncertainty and request qualified human review.
```

### Java 17+

Build:

```text
javac java/FogRouter.java
```

Run:

```text
java -cp java FogRouter canal-A17 2026-08-26T07:30:00Z freshwater 0.91 0.95 false 0.42 18.4 0.93 0.90 0.70 0.12 true
```

Expected output matches the C++ example.

### Kotlin/JVM

Build:

```text
kotlinc kotlin/FogRouter.kt -include-runtime -d fog-router-kotlin.jar
```

Run:

```text
java -jar fog-router-kotlin.jar canal-A17 2026-08-26T07:30:00Z freshwater 0.91 0.95 false 0.42 18.4 0.93 0.90 0.70 0.12 true
```

Expected output matches the C++ example.

### Lua 5.4

Run:

```text
lua lua/fog_router.lua canal-A17 2026-08-26T07:30:00Z freshwater 0.91 0.95 false 0.42 18.4 0.93 0.90 0.70 0.12 true
```

Expected output matches the C++ example.

### SQLite

Load the schema:

```text
sqlite3 fog-router.db < sql/fog_router.sql
```

Inspect records requiring qualified review:

```text
sqlite3 fog-router.db "SELECT * FROM records_needing_human_review;"
```

## Assumptions and limitations

- Timestamps are accepted as bounded UTC-formatted text; parsing and time-zone conversion are intentionally outside these minimal local artifacts.
- The router does not predict contaminant fate, water quality, ecological recovery, hydraulics, or infrastructure safety.
- Media classifications are deliberately small and configured in source for deterministic review; a deployed version should use an approved local configuration change process.
- `K`, `E`, and `R` are review inputs, not opaque scores. Their meaning, evidence basis, and accountable reviewer must be recorded.
- No direct identifiers, precise coordinates, biometric data, neural data, continuous telemetry, raw sensor streams, or machinery credentials are collected.
- SQL constraints provide local integrity controls but do not replace organizational access control, encrypted storage, backup governance, or qualified review.

## Data minimization and rights

The minimum retained record is a pseudonymous node identifier, bounded environmental measurement context, provenance description, consent status, routing outcome, explanation, and review/audit data. The data purpose is limited to ecological-observation validation and qualified review.

- Consent is explicit, purpose-limited, and revocable.
- Revocation prevents new affirmative routing and requires a retention/deletion review.
- Records must provide export and deletion pathways under the responsible organization’s approved process.
- Every route carries a plain-language explanation and stable code.
- People affected by a routing decision require an accessible appeal and correction path.
- FOG is retained as uncertainty; it is never silently treated as safe or complete.

## Compute-efficiency considerations

The artifacts perform one-pass validation over a single observation, use fixed-size fields, avoid network access, avoid polling and busy loops, and produce a small stable output. They do not claim carbon-negative operation. Any ecological benefit must be measured and reviewed in the actual deployment context.

## Metrics

- `knowledge_factor`: `0.72` — transparent predicates and explicit evidence fields, limited by absence of laboratory or field validation.
- `eco_impact_value`: `0.64` — supports conservative restoration monitoring review, without claiming direct ecological outcomes.
- `harm_risk`: `0.18` — non-actuating and fail-closed by design; residual risk includes misuse of outputs outside review.
- `accessibility_impact`: `0.82` — stable text codes, concise plain-language explanations, and command-line local operation.
- `rights_alignment`: `0.90` — data minimization, explicit consent, revocation, uncertainty preservation, auditability, and human review are built into the workflow.
