# Verification Coverage Map

This shard tracks which RoH-, Tsafe-, and energy-related invariants are covered by Kani proofs and how they connect to ALN specs and Rust modules.

## Scope

- Metabolic power envelope → ATPnorm → RoH corridors.
- Dental/cranial hazard → StateVectorNBiohost → RoH monotonicity.
- Core StateVectorN RoH convex risk mapping (thermal, ATP, psych, biofilm, motion).

All artifacts assert:

- `ALN.MIGRATION.CYBERCORE_AUTHORITY.v1`
- `hostdid = OrganicCPU`
- `bostrom_address = bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`

---

## MetabolicPowerEnvelope → RoH invariants

- ALN spec:
  - `specs/aln/MetabolicPowerEnvelope.v1.aln.json`
- Rust core:
  - `crates/nanorobotics-core/src/metabolic_power.rs`
  - `crates/nanorobotics-core/src/rohfromstatevectorbiohost.rs`
- Kani harness:
  - `crates/nanorobotics-guards/src/kani/metabolic_power_corridor.rs`

### Invariants

- IV-MET-1 (Safe metabolic corridor)

  - Statement:
    - For all physiologically admissible `MetabolicSnapshot` and `MetabolicPowerEnvelope`:
      - If `ATPnorm ≥ 0.8` and all other axes `≤ 0.8`,
      - Then `RoH(StateVectorNBiohost) ≤ 0.3` under `RoHWeights::default_conservative`.
  - Enforcement:
    - `roh_bounded_in_safe_metabolic_corridor` proof in `metabolic_power_corridor.rs`.
  - Dependencies:
    - ALN normalization constraints for `ATPnorm` (MetabolicPowerEnvelope).
    - Convex `R_ATP(ATPnorm) = (1 - ATPnorm)^2` inside `rohfromstatevectorbiohost.rs`.

- IV-MET-2 (Metabolic crisis critical band)

  - Statement:
    - For all admissible `MetabolicSnapshot`:
      - If `ATPnorm ≤ 0.3` (crisis),
      - Then `RoH(StateVectorNBiohost) ≥ 0.7` even when other axes are nominal.
  - Enforcement:
    - `roh_critical_in_metabolic_crisis` proof in `metabolic_power_corridor.rs`.
  - Intended use:
    - Drives SovereigntyKernel clamps and ExcursionState transitions when ATP collapses.

---

## DentalCranialEnvelope → RoH monotone tightening

- ALN spec:
  - `specs/aln/DentalCranialEnvelope.v1.aln.json`
- Rust core:
  - `crates/nanorobotics-core/src/telemetry_dental.rs`
  - `crates/nanorobotics-core/src/rohfromstatevectorbiohost.rs`
- Guards:
  - `crates/nanorobotics-guards/src/hazard_kernel_dental.rs`
- Kani harness:
  - `crates/nanorobotics-guards/src/kani/state_vector_roh.rs`

### Invariants

- IV-DEN-1 (Dental hazard monotone in RoH)

  - Statement:
    - For any fixed `StateVectorNBiohost` and RoH weights:
      - Increasing dental hazard telemetry (thermal, pressure, duty) cannot decrease RoH.
  - Enforcement:
    - `dental_extended_roh` in `hazard_kernel_dental.rs` (monotone fold-in).
    - `roh_critical_when_any_axis_saturates` in `state_vector_roh.rs` ensures RoH responds critically when any axis (including dental-mapped thermal/motion) saturates.

- IV-DEN-2 (Dental axis within safe corridor)

  - Statement:
    - For conservative `DentalCranialTelemetry` (small ΔT, low pressure, safe duty) and other axes ≤ 0.8, RoH remains ≤ 0.3.
  - Current status:
    - Covered indirectly via `roh_bounded_when_axes_conservative` in `state_vector_roh.rs` where dental contributions are folded into `tnorm`/`motionnorm`.
  - Future refinement:
    - Add explicit harness `dental_safe_corridor_keeps_roh_bounded` once Phoenix dental thermal/pressure corridors are parameterized.

---

## StateVectorNBiohost RoH function

- ALN spec:
  - `specs/aln/StateVectorN.biohost-extended.v1.aln`
  - `specs/aln/RoH.fromStateVectorN.biohost-extended.v1.aln`
- Rust core:
  - `crates/nanorobotics-core/src/rohfromstatevectorbiohost.rs`
  - `crates/nanorobotics-core/src/statevectorbiohost.rs`
- Kani harness:
  - `crates/nanorobotics-core/src/kani/state_vector_roh_biohost.rs` (planned)
  - `crates/nanorobotics-guards/src/kani/metabolic_power_corridor.rs`
  - `crates/nanorobotics-guards/src/kani/state_vector_roh.rs`

### Invariants

- IV-ROH-1 (Safe corridor convex bound)

  - Statement:
    - If all normalized axes `≤ 0.8`, then `RoH ≤ 0.3` under conservative weights.
  - Enforcement:
    - `roh_bounded_when_axes_conservative` in `state_vector_roh.rs`.

- IV-ROH-2 (Single-axis criticality)

  - Statement:
    - If any axis hits worst case (1.0) while others are admissible, RoH ≥ 0.7.
  - Enforcement:
    - `roh_critical_when_any_axis_saturates` in `state_vector_roh.rs`.

- IV-ROH-3 (Psych pipeline consistency)

  - Statement:
    - Within conservative psych corridors, `PsychosisRisk` → `Psychnorm` → RoH still respects `RoH ≤ 0.3`.
  - Enforcement:
    - `crates/psychcaps-core/src/kani/psychosisrisk.rs` (psych scalar monotonicity, safe corridor).
    - `crates/nanorobotics-guards/src/kani/psychpipeline.rs` (full psych pipeline → RoH).

---

## CI integration

- All Kani harness files listed above must be wired into Cybercore CI:

  - `kani --enable-unstable --harness roh_bounded_in_safe_metabolic_corridor ...`
  - `kani --enable-unstable --harness roh_critical_in_metabolic_crisis ...`
  - Existing RoH and psych pipeline harnesses.

- Merge policy:

  - Any change to:
    - `specs/aln/MetabolicPowerEnvelope.v1.aln.json`
    - `specs/aln/DentalCranialEnvelope.v1.aln.json`
    - `specs/aln/StateVectorN.biohost-extended.v1.aln`
    - `crates/nanorobotics-core/src/rohfromstatevectorbiohost.rs`
    - `crates/nanorobotics-core/src/metabolic_power.rs`
    - `crates/nanorobotics-core/src/telemetry_dental.rs`
  - MUST re-run the Kani harness set above and pass all invariants before landing.

---

## Next coverage targets

- Add grid-based, correlated physiological corridors (Tsafe, ATP, psych) into a dedicated RoH harness:

  - `crates/nanorobotics-guards/src/kani/roh_harness_correlated.rs`

- Extend this map with:

  - ROZL18 post-excursion recovery state machine harness.
  - ROZL19 data-pipeline uncapping Kani proofs.
  - ROZL20 Tsafe-bounded optimization termination proofs.
