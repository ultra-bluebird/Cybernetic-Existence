# nanoswarm-bio

> Biocompatibility, tissue risk, and biospatial envelopes for sovereign nanoswarm control under mk-bluebird/nanorobotics.[file:44][file:42]

## Purpose

- Encode nanoswarm biocompatibility as typed Rust structs:
  - Material families (`NanoswarmMaterialFamily`).[file:44]
  - Tissue bins (`TissueClass`).[file:44]
  - Hydrodynamic and thermal coefficients (`HydroThermoCoefficients`).[file:44]
  - Per-tissue risk profiles (`TissueRiskProfile`).[file:44]
- Provide a canonical `BiocompatibilityProfile` and `NanoswarmStateVector`:
  - Allowlists / ceilings per tissue corridor.
  - RoH multipliers and density ceilings.[file:44]
- Implement a `roh_with_biocompat` function:
  - Maps baseline swarm RoH into a biocompatibility-aware RoH.[file:44]
  - Returns `None` for disallowed tissue or density breaches, enabling hard stops in guards.[file:44]

## Design constraints

- Rust edition: `2024`, `rust-version = "1.85"`.[file:44]
- License: `MIT OR Apache-2.0`.[file:44]
- No unsafe code; no rollbacks or downgrades.
- `serde` and `serde_json` for portable telemetry.[file:44]
- `kani-verifier = "0.67.0"` for basic invariants on RoH and envelopes.[file:44]

## Module overview

### `material`

- Defines `NanoswarmMaterialFamily`:
  - `GoldColloid`, `IronOxide`, `SilicaPorous`, `LipidNanocarrier`, `PolymerPegylated`, `CarbonDot`.[file:44]
- Used by biocompatibility profiles and state vectors.

### `tissue`

- Defines `TissueClass` organ bins:
  - `CortexGray`, `CortexWhite`, `Hippocampus`, `Brainstem`, `PeripheralNerve`, `Myocardium`, `Pulmonary`, `Hepatic`, `Renal`, `Splenic`, `BoneMarrow`, `Muscle`, `Subcutaneous`.[file:44]
- Matches your organ corridor and biospatial indexing shards.[file:42][file:44]

### `profile`

- `HydroThermoCoefficients`:
  - `radius_nm`, `drag_coeff`, `thermal_coupling`.[file:44]
- `TissueRiskProfile`:
  - `allowed`: tissue corridor allowlist.
  - `max_density`: normalized swarm density ceiling.
  - `roh_multiplier`: ≥ 1.0 risk multiplier for material–tissue pairing.[file:44]
- `LiteratureTag`:
  - `shorthex` (evidence tag).
  - `description` (brief text).[file:44]
- `BiocompatibilityProfile`:
  - `family`: material family.
  - `hydro_thermo`: hydrodynamic/thermal coefficients.
  - `tissue_profiles`: `(TissueClass, TissueRiskProfile)` tuples.
  - `literature_tags`: hex-tagged evidence anchors.[file:44]

### `state`

- `NanoswarmStateVector`:
  - `material_family`: nanoswarm material family.
  - `tissue`: tissue corridor.
  - `density`: normalized swarm density.
  - `actuation_intensity`: duty amplitude summary.
  - `base_roh`: baseline dynamic RoH before multipliers.[file:44]
- `roh_with_biocompat(state, profile) -> Option<f32>`:
  - Returns `None` if:
    - Tissue is disallowed (`allowed == false`), or
    - `density > max_density` for that tissue.[file:44]
  - Otherwise:
    - Computes \( \text{RoH} = \text{base\_roh} \times \text{roh\_multiplier} \times \text{intensity} \) with `roh_multiplier ≥ 1.0`.[file:44]
  - Designed to plug into:
    - `LifeforceNanoswarmAdapterV1` and organ guards for RoH ≤ 0.30 enforcement.[file:44]

## Binary: `nanoswarm-bio-json-debug`

- Path: `src/bin/nanoswarm-bio-json-debug.rs`.[file:44]
- Use-case:
  - Read JSON input containing:
    - `NanoswarmStateVector`.
    - `BiocompatibilityProfile`.[file:44]
  - Compute `roh_with_biocompat`.
  - Emit JSON with the resulting RoH or `null` for disallowed/unsafe states.

### Example JSON input

```json
{
  "state": {
    "material_family": "GoldColloid",
    "tissue": "Renal",
    "density": 0.3,
    "actuation_intensity": 0.5,
    "base_roh": 0.1
  },
  "profile": {
    "family": "GoldColloid",
    "hydro_thermo": {
      "radius_nm": 80.0,
      "drag_coeff": 0.6,
      "thermal_coupling": 0.4
    },
    "tissue_profiles": [
      {
        "0": "Renal",
        "1": {
          "allowed": true,
          "max_density": 0.5,
          "roh_multiplier": 1.2
        }
      }
    ],
    "literature_tags": [
      {
        "shorthex": "c3f5a1d7",
        "description": "Gold colloid renal perfusion study"
      }
    ]
  }
}
```

Run:

```bash
cargo run --bin nanoswarm-bio-json-debug -- ./input.json
```

The output JSON can be wired into higher-level guards and ALN shards to validate per-tissue RoH behavior before integrating with real nanoswarm controllers.[file:44]

## Kani proofs

- `src/kani/roh_kani.rs`:
  - Asserts:
    - `roh_with_biocompat` never returns negative RoH.[file:44]
    - Disallowed tissue or density breaches produce `None`, suitable for hard-stop semantics.[file:44]
- Run:

```bash
cargo kani --package nanoswarm-bio
```

These harnesses provide basic, composable guarantees that material–tissue biocompatibility and density ceilings are respected before RoH is passed into global nanoswarm or organ guards.[file:44][file:42]

## Integration points

- `crates/nanoswarm-shared-control`:
  - Uses `NanoswarmStateVector` and `BiocompatibilityProfile` to modulate barrier functions and UnifiedSafetyAxes.[file:44]
- `cybernano-guard` and organ guards:
  - Feed `roh_with_biocompat` into RoH ceiling checks (≤ 0.30) per tissue corridor.[file:44][file:42]
- ALN shards:
  - `aln.nanoswarm.material-biocompatibility.v1.aln` (future) to bind:
    - Material family.
    - TissueClass.
    - Evidence tags.
    - RoH multipliers and density ceilings.[file:44]

This crate is intentionally minimal and compile-ready, giving you a dedicated nanoswarm biocompatibility layer that can be extended with richer evidence, corridor polytopes, and Kani proofs without changing public interfaces.[file:44][file:42]

---

### Progress tracker

- Next artifacts that can build on `nanoswarm-bio`:
  - `crates/cybernano-guard/src/biocompat_guard.rs` connecting `roh_with_biocompat` into existing RoH guards.[file:44]
  - ALN shard for material–tissue profiles and evidence bundles.
- Missing data:
  - Empirical RoH multipliers per material–tissue pairing.
  - Tissue-specific `max_density` based on microfluidic and in-vivo experiments.[file:44]
