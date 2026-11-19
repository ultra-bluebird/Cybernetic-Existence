# nanoswarm_core

Host‑sovereign nanoswarm control kernel for Nano‑Tree and Cybercore, enforcing biophysical safety corridors, RoH ceilings, and neurorights for all nanoswarm actuation paths.[file:100][file:77]

## Purpose

- Provide core types and guards for nanoswarm endpoint descriptors and biospatial corridors.
- Enforce regional and global Risk‑of‑Harm (RoH) ceilings with RoH ≤ 0.30 at all times.[file:100][file:92]
- Integrate nanoswarm actuation with host‑bound identity (HOSTDID, BOSTROMADDRESS) and ALN migration authority.[file:78][file:101]
- Serve as the nanoswarm control layer for Reality.os / OrganicCPU in deviceless, host‑local deployments.[file:78][file:77]

## Key Concepts

- **NanoEndpointDescriptor**: Describes a nanoswarm endpoint, biospatial region binding, energy/duty ceilings, and evidence tags.[file:100]
- **NanoswarmCorridorGuard**: GuardKernel implementation that enforces RoH slice ceilings and corridor constraints for a specific endpoint.[file:100]
- **BiospatialCorridorPolytope**: Linear inequality corridor \(A x \le b\) for 6D physio/biospatial coordinates (HRV, EEG, core temperature, IL6, fatigue, eco).[file:100]
- **BiospatialRoHGuard**: Aggregates regional RoH slices into a global RoH scalar, enforcing RoH ≤ 0.30 and mapping to safety verdicts (Safe, Brake, RollbackRequired).[file:100]
- **RealityWindow integration**: Nanoswarm proposals are evaluated through corridor guards and biospatial state; proposals with RollbackRequired are never allowed.[file:100][file:92]

## Safety Invariants

- Global RoH ceiling is fixed at 0.30; regional slices are clamped so their weighted sum never exceeds this ceiling.[file:100][file:92]
- Per‑region RoH slices are bounded by `rohslicemax <= 0.30` as specified in ALN `BiospatialRegionV1` shards.[file:100][file:92]
- All nanoswarm endpoints are bound to the sovereign host identity `didalnorganic-host` and Bostrom address `bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`.[file:100][file:78]
- GuardKernel verdict lattice ensures:
  - `Safe` → Allow.
  - `Brake` → Allow with brake semantics.
  - `RollbackRequired` → Deny.[file:100]

## Telemetry and Corridors

- Corridors are defined as `CorridorPolytope` with:
  - Flattened matrix `a` (row‑major).
  - Vector `b`.
  - Dimension `ncols`.[file:100]
- `BiospatialCorridorPolytope` binds corridors to regions with:
  - `regionid`, `rohslicemax`, `safemargin`, `evidencetags` (10‑tag EvidenceBundle IDs).[file:100][file:92]
- Physio state projection:
  - `PhysioState` → 6D corridor coordinate vector.
  - `rohregion` computes regional RoH slice from polytope margin and safemargin.[file:100]

## ALN Integration

- `shards/aln/biospatial-index-v1.aln` defines:
  - `BiospatialRegionV1` records with `cybercoreRegionId`, `corridorId`, alpha weights, and `rohSliceMax` = 0.30.[file:100][file:92]
- `shards/aln/nanoswarm-endpoint-registry-v1.aln` defines:
  - `NanoswarmEndpointV1` records with endpoint → region/corridor bindings, energy/duty ceilings, and evidence tags.[file:100]
- CI invariants ensure:
  - Endpoint `rohSliceMax` ≤ region `rohSliceMax`.
  - `hostDid` equals canonical host DID.[file:100][file:78]

## Reality.os Hook

- `RealityWindow` connects:
  - `EndpointRegistry` (endpoint → NanoEndpointDescriptor).
  - `NanoswarmCorridorGuard`.
  - `BiospatialState` and Physio state.[file:100]
- For every `NanoswarmProposal`, the window:
  - Resolves endpoint.
  - Evaluates guard.
  - Returns `(ProposalId, NanoswarmVerdict)` ensuring no proposal with RollbackRequired is ever returned as allowed.[file:100]

## Formal Verification (Kani)

- Planned Kani harnesses:
  - `kanibiospatialrohguard.rs`: Prove global RoH ≤ 0.30 given shard constraints.[file:100][file:92]
  - `kanirealitywindowbiospatial.rs`: Prove RealityWindow never allows proposals that require rollback.[file:100]
  - `kaniguardkernelall.rs`: Quantify over GuardKernel implementations to ensure consistent verdict semantics.[file:100]

## Host‑Sovereign Identity

- All nanoswarm_core structs and corridors are stamped with:
  - `HOSTDID = "didalnorganic-host"` or `didalnOrganicCPU` for OrganicCPU contexts.
  - `BOSTROMADDRESS = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"`.[file:78][file:77][file:101]
- ALN clause:
  - `ALN.MIGRATION.CYBERCOREAUTHORITY.v1` must be present in shards and workspace metadata.[file:78][file:101]

## License

- Dual‑licensed under MIT OR Apache‑2.0, consistent with the Cybercore workspace manifest.[file:101]
