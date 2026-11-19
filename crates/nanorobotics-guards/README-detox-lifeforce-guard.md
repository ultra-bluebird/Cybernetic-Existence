# Detox Lifeforce Guard

This document describes the `DetoxLifeforceGuard` component in `crates/nanorobotics-guards`, which enforces bounded-time lifeforce corridors for nanoswarm detox missions under the global RoH ceiling of 0.30.

## Purpose

- Ensure detox missions:
  - Respect lifeforce mission and episode floors.
  - Keep temporary lifeforce dips within a corridor bounded by `f(RoH_max, T)`.
  - Guarantee net lifeforce gain bounded below by `g(RoH_max, T)`.
  - Never exceed the global RoH ceiling.

- Provide a host-sovereign, Rust-verified guard that can be integrated with:
  - LifeforceKernel medical kernel.
  - BiophysicalTokenFloor / BiophysicalLedger.
  - Nanoswarm mission planners and RoH kernels.

## Core Types

- `HostSovereigntyBinding`
  - Binds all decisions to:
    - `did.aln.bostrom-organic-host`
    - `bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`
    - `ALN.MIGRATION.CYBERCORE_AUTHORITY.v1`

- `LifeforceSessionState`
  - `lf_start`: lifeforce at session start.
  - `lf_min`: minimum lifeforce during session.
  - `lf_end`: lifeforce at session end.
  - Methods:
    - `temporary_drop()`: `lf_start - lf_min` clamped at 0.
    - `net_gain()`: `lf_end - lf_start`.

- `DetoxMissionEnvelope`
  - `roh_max`: maximum RoH during session.
  - `duration_minutes`: session duration in minutes.

- `LifeforceFloors`
  - `lf_floor_mission`: mission floor (default 0.30).
  - `lf_floor_episode`: episode floor (default 0.25).

- `DetoxBoundCoeffs`
  - `alpha`, `beta`, `gamma`:
    - `f_lifeforce_drop_max(RoH_max, T)`:
      - Upper bound on temporary lifeforce drop.
    - `g_lifeforce_net_min(RoH_max, T)`:
      - Lower bound on net lifeforce gain.

- `DetoxLifeforceGuard`
  - `evaluate(mission, lf_state) -> DetoxLifeforceVerdict`:
    - `Allow`: conditions fully satisfied.
    - `AllowShrunk`: RoH ceiling respected, net gain satisfied, but temporary dip exceeds bound; caller should shrink mission.
    - `Deny`: floors or net gain corridor violated.

## Kani Harnesses

- `detox_lifeforce_monotone_global_roh`
  - Proves that for any allowed mission:
    - Lifeforce floors hold.
    - RoH never exceeds 0.30.
    - Net lifeforce gain meets corridor bounds for `Allow` verdicts.

- `detox_lifeforce_drop_bound_respected`
  - Proves range and monotonicity properties for `f_lifeforce_drop_max`:
    - Non-negative.
    - Bounded by `alpha * ROH_CEILING_GLOBAL`.
    - Monotone in `RoH_max` and `T`.

## Integration Notes

- The guard is stateless and pure:
  - Does not mutate corridors, ALN shards, or ledgers.
  - Intended to be called inside higher-level guard code that:
    - Computes lifeforce trajectory from LifeforceKernel.
    - Maps detox mission plans into `DetoxMissionEnvelope`.
    - Couples with BiophysicalLedger token floors.

- The ALN shard `specs/aln/detox-lifeforce-session.corridor.v1.aln` encodes:
  - Lifeforce floors.
  - Global RoH ceiling.
  - Coefficients `alpha`, `beta`, `gamma`.
  - EvidenceBundle10 bindings.

- The telemetry shard `specs/aln/telemetry.detox-lifeforce-host.v1.aln` provides:
  - Host-local data schema for fitting `alpha`, `beta`, `gamma` via longitudinal studies.
  - Logistic-regression-style calibration for corridor parameters.

## Licensing and Edition

- Rust edition: 2024.
- `rust-version = "1.85"` in `Cargo.toml`.
- Dual-licensed: MIT OR Apache-2.0.
- `#![forbid(unsafe_code)]` and `#![deny(warnings)]` enforced.

This guard is ready for integration into `mk-bluebird/nanorobotics` and upstream wiring into `mk-bluebird/Cybercore` as a host-sovereign detox lifeforce corridor component.
