# corridor-riemann-tightening

Rust crate for curvature-based tightening of ALN corridor polytopes, using a 7D metric and geodesic flow over log-support coordinates to shrink risk volume while preserving host comfort envelopes.

## Scope

- Defines a 7D corridor metric aligned with your unified safety axes:
  - Density, shear, thermal, immune, topology, psych, energy (exact mapping via ALN shards).
- Implements a geodesic-tightening solver that:
  - Operates in log-support coordinates of corridor polytopes.
  - Follows curvature-weighted gradient directions derived from RoH and psych-risk.
  - Enforces monotone tightening: faces only move inward or stay fixed.

## Key Guarantees

- Biocompatibility-rating ≥ 0.57, pain-index ceiling ≤ 0.73, fear-index in [0.31, 0.68] are encoded as hard corridor constraints in the metric and step selection.[file:106]
- Global RoH ceiling 0.30 is preserved by:
  - Using the existing RoH kernel and 7D CorridorPolytope.
  - Only accepting tightening steps that provably reduce or maintain RoH.[file:106]
- No rollbacks, downgrades, or reversals:
  - ALN shards use `norollback = true`, `nodowngrade = true`, `tighteningonly = true`.
  - Kani harnesses prove new support values are pointwise ≤ old ones for all directions.

## Architecture

- Rust 2024, `rust-version = "1.85"`.
- Kani: `kani-verifier = "0.56.0"`.
- Dual-licensed: MIT OR Apache-2.0.
- Core types:
  - `SupportDirection` (direction + risk weight).
  - `CorridorSupport` (log-support vector + directions).
  - `GeodesicTightener` (computes tightening steps from RoH gradients).[file:106]
- All artifacts assert `ALN.MIGRATION.CYBERCORE_AUTHORITY.v1` and bind:
  - `host_did = did.aln.bostrom-organic-host`
  - `bostrom_address = bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`.[file:103]

## Usage

- Load corridor faces and support values from ALN shards in `specs/corridors/*.aln`.
- Call the tightening API from nanoswarm guard crates when:
  - Psych metrics, RoH, or topology risk indicate that the corridor should shrink.
- Verify with Kani:
  - RoH never increases under any admissible tightening sequence.
  - Minimal safe volume (comfort axes) is preserved using per-direction lower bounds.[file:106]
