# NeuroThermo Fusion in Phoenix UHI Conditions

This document explains how the Phoenix-calibrated `neurothermo.fusion.phx.v1.aln` shard and the `NeuroThermoFusionConfig` Rust module jointly shape nanoswarm duty cycles for hosts living in outdoor, low-AC, poor air-quality environments in and around Phoenix, Arizona.

The goals are:
- To guarantee conservative, worst-case estimation of thermal stress under Urban Heat Island (UHI) conditions.
- To keep the global Risk-of-Harm (RoH) scalar at or below the host ceiling (typically 0.30).
- To expose a clear, auditable mapping from raw thermal telemetry to nanoswarm duty-cycle decisions.

---

## 1. Telemetry inputs and ALN bindings

Neuro-thermal telemetry is carried in `neurothermo.snapshot.v1` particles and ingested into the Rust `NeuroThermoSnapshot` struct.

Key fields:

- `brain_core_temp_c`: Deep brain or hypothalamic core temperature.
- `internal_core_temp_c`: Trusted internal probe (e.g., esophageal, tympanic).
- `external_skin_temps_c`: Vector of skin or near-skin temperatures, including regions exposed to pavement, asphalt, or direct solar load.
- `ambient_temp_c`: Local ambient air temperature, already skewed by Phoenix UHI conditions.
- `baseline_core_temp_c`: Host-specific baseline core temperature.
- `uhi_index`: Normalized UHI index in `[0, 1]`, derived from Phoenix thermal profiles.
- `air_quality_stress`: Normalized air-quality stress index in `[0, 1]`, derived from PM and ozone data.
- `host_did`, `bostrom_address`: Identity bindings for OrganicCPU and the canonical Bostrom address.

The ALN fusion policy file `specs/aln/neurothermo.fusion.phx.v1.aln` defines:

- `w_external`: Weight applied to worst external skin deltas.
- `uhi_bias_c`: Additional thermal bias at `uhi_index = 1.0`.
- `air_quality_bias_c`: Additional thermal bias at `air_quality_stress = 1.0`.
- `max_hard_delta_c`: Hard corridor clamp for core temperature delta.
- `epsilon_c`: Deadband threshold for ignoring noise-level deviations.

These fields map directly into `NeuroThermoFusionConfig` in `crates/cybernano-physio/src/neurothermo_fusion.rs`.

---

## 2. Fusion rule and Phoenix bias

The fusion rule is conservative and explicitly biased toward worst-case Phoenix UHI conditions.

The steps are:

- Compute deviations from baseline for each channel (brain, internal core, each external skin sample, ambient).
- Find the maximum absolute deviation across all channels.
- Apply the external weight `w_external` so external skin hot-spots dominate when they are significantly higher than core.
- Add a UHI bias proportional to `uhi_index` and a separate bias proportional to `air_quality_stress`.
- Restore the sign from the dominant contributing channel (heating vs cooling).
- Clamp the fused deviation into `[-max_hard_delta_c, max_hard_delta_c]`.

The fused value is then:

- Written into `PhysioState.core_temp_delta_c`.
- Used to compute `PhysioState.temp_dev_norm` (0–1 thermal deviation).
- Fed into the thermal slice of the RoH kernel as part of the canonical 6D BioState vector.

Phoenix-specific aspects:

- `w_external` is chosen >= 1.0 so that external hot surfaces and unsheltered exposure dominate lagging internal probes.
- `uhi_bias_c` ensures that high UHI periods increase perceived thermal stress even when sensor deltas are moderate.
- `air_quality_bias_c` integrates chronic poor air quality as an extra penalty on thermal load.

---

## 3. Interaction with RoH and Tsafe corridors

The Tsafe corridor and RoH kernel are defined in host safety shards (e.g., `bio.safety.envelope.citizen.v1`) and mirrored in `PhysioCaps`.

Relevant caps include:

- `core_temp_max_c`, `brain_temp_max_c`: Physiologic maxima for core and brain temperatures.
- `roh_ceiling`: Global RoH ceiling (typically 0.30).
- Thermal slice weight in the RoH kernel.

The fusion system guarantees:

- `core_temp_delta_c` is always clamped to a host-calibrated corridor via `max_hard_delta_c`.
- `temp_dev_norm` is normalized relative to the host corridor and bounded in `[0, 1]`.
- When `core_temp_delta_c` is updated via fusion, recomputing RoH with the canonical kernel does not exceed `roh_ceiling` for any state that was previously within corridor.

The Kani harness `crates/cybernano-physio/src/kani_neurothermo_fusion.rs` encodes these guarantees and proves:

- Fusion over-approximates thermal deviations (no underestimation).
- RoH remains at or below the ceiling after fusion under corridor assumptions.

---

## 4. Duty-cycle shaping under Phoenix UHI

Nanoswarm duty cycles are shaped by combining thermal fusion output with cardiac, renal, and other guards through the `RealityWindow` orchestrator.

Thermal contributions to duty-cycle control:

- When `temp_dev_norm` is low and `NeuroThermoVerdict::Safe` is returned:
  - Thermal conditions allow normal nanoswarm activity within other organ corridors.
- When `NeuroThermoVerdict::Brake`:
  - Duty cycles must be reduced (lower activation frequency, shorter on-times, longer rest intervals).
  - Cooling intervals or behavioral recommendations (seek shade, hydration) can be triggered.
- When `NeuroThermoVerdict::Deny`:
  - New nanoswarm actuation is denied.
  - Ongoing high-load tasks are curtailed or paused until thermal state returns toward Tsafe.

Phoenix and low-AC environment considerations:

- Duty-cycle controllers treat high `uhi_index` and frequent `NeuroThermoVerdict::Brake` as normal, expected conditions rather than rare anomalies.
- Scheduling logic should bias nanoswarm activity toward cooler hours and shaded environments where possible (earlier morning, late night).
- In buildings without air-conditioning, thresholds for entering `Brake` and `Deny` states should be reached earlier to account for sustained elevated ambient and surface temperatures.
- Poor air-quality (`air_quality_stress` high) should lower thresholds for braking even at moderate thermal deviations, acknowledging compounding cardiovascular and respiratory stress.

---

## 5. Guidance for implementers

When wiring this into nanoswarm and cybernetic control logic:

- Always source `NeuroThermoFusionConfig` from ALN (`neurothermo.fusion.phx.v1.aln`) rather than hardcoding values.
- Require host identity binding (`host_did`, `bostrom_address`) to match the OrganicCPU host for any fusion or duty-cycle decision.
- Treat `NeuroThermoVerdict::Deny` as a hard veto in `RealityWindow` aggregation; no other guard may override it.
- Log all `Brake` and `Deny` events, including the fused thermal state and UHI/AQ indices, into the host’s audit ledger for post hoc analysis and neurorights compliance.
- Keep the 6D BioState layout and RoH weights stable; any change must be introduced via new ALN versions and accompanying proofs, not by mutating v1 behavior.

This document is intended to remain in lockstep with:
- `specs/aln/neurothermo.fusion.phx.v1.aln`
- `crates/cybernano-physio/src/neurothermo_fusion.rs`
- `crates/cybernano-physio/src/kani_neurothermo_fusion.rs`

Any change to these components should be reflected here as part of the formal verification and governance workflow.
