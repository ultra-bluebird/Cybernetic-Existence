# sacrifice-zone-envelope

`crates/sacrifice-zone-envelope` defines **Sacrifice Zone envelopes** for hazardous-material regions and binds them to the existing 7D corridor geometry and nanoswarm guard stack in `cybercore-category` and `nanorobotics-cbf-guards`.[^sz1][^sz2]

A **Sacrifice Zone** is a spatial region with persistent hazardous loads (chemical, radiological, or nanomaterial) where:

- Nanoswarms may **detox, sequester, or immobilize** hazardous materials.
- Host biophysical corridors and RoH ceiling (≤ 0.30) must remain enforced.[^sz1]
- Capabilities and neurorights cannot be downgraded, in line with DevicelessGuardKernel invariants.[^sz2]

This crate is **pure, non‑actuating**: it defines envelopes, metrics, and model structs that other crates use to decide whether proposed nanoswarm missions in hazardous regions are admissible.

## Design goals

- Mirror the canonical 7D corridor geometry used by `CorridorPolytope7D` and `CorridorMonoidalCorridor`.[^sz1]
- Provide **host-bound**, DID‑anchored Sacrifice Zone descriptors with ALN migration authority tokens.
- Supply **metrics over hazardous-material load** that feed into RoH and materialrisk axes.
- Integrate smoothly with `nanorobotics-cbf-guards::BarrierGuard` without duplicating actuation logic.[^sz1]

## Core concepts

- `SacrificeZoneId` — stable identifier for each zone, suitable for ALN corridor registries.
- `SacrificeZoneEnvelope` — geometry, hazard-class metadata, and corridor polytope for a zone.
- `HazardMetrics` — aggregate hazardous‑material metrics normalized 0–1 for RoH/materialrisk mapping.
- `SacrificeZoneModel` — compact per‑zone snapshot combining envelope, metrics, and current RoH proxy.

## Files

- `src/lib.rs` — crate entry, exports, and high‑level helpers.
- `src/model.rs` — core structs (`SacrificeZoneEnvelope`, `SacrificeZoneModel`).
- `src/metrics.rs` — hazardous‑material metrics and mapping functions.
- `src/main.rs` — minimal CLI to inspect and validate Sacrifice Zone envelopes (for debugging / audits).

## Integration

- Upstream ALN shard suggestion:
  - `Cybercore/specs/aln/sacrifice-zone-envelope.v1.aln`
  - Binds `SacrificeZoneId`, corridor polytope coefficients, and hazard evidence bundles to this crate’s fields.
- Guard integration:
  - `nanorobotics-cbf-guards` can import `SacrificeZoneModel` and `HazardMetrics` when building `CorridorRiskBundle` for missions inside Sacrifice Zones.[^sz1]

## License

Dual-licensed under MIT or Apache-2.0.
