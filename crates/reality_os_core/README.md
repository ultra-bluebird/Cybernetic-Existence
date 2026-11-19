# reality_os_core

Core Reality.os kernel crate for Nano‑Tree and OrganicCPU, defining the Tree‑of‑Life state vector, global RoH scalar, neurorights bitmask, and Kani‑verified invariants for host‑sovereign control.[file:77][file:78]

## Purpose

- Represent the host biophysical and cognitive state as an eight‑axis Tree‑of‑Life vector on Reality.os.[file:77]
- Compute a global Risk‑of‑Harm (RoH) scalar with a hard ceiling of 0.30.[file:77][file:92]
- Encode neurorights as a machine‑readable bitmask and validate snapshots against active rights.[file:78][file:92]
- Bind all runtime state and invariants to the sovereign host identity and Organichain governance kernel.[file:77][file:101]

## Core Types

- **SovereignIdentityStamp** (via `nanotree_identity`):
  - Canonical binding for `HOSTDID = "didalnOrganicCPU"` and `BOSTROMADDRESS = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"`.[file:77][file:78]
- **TreeOfLifeAxes**:
  - Eight normalized axes: `xblood`, `xoxygen`, `xmicrovasc`, `xthermal`, `xfear`, `xpain`, `ximmune`, `xpsych` in \([0,1]\).[file:77]
  - `clamped()` method ensures all components lie in the closed unit interval.[file:77]
- **PainIntegratorStack**:
  - Leaky integrators for acute (`za`), 24‑hour (`z24`), and 7‑day (`z7`) pain budgets.[file:77]
  - `update(...)` produces a unified pain risk scalar with HardStop semantics when any component breaches clinical thresholds.[file:77]
- **RoHScalar**:
  - Global RoH scalar `total: f64` computed from weighted axes.[file:77]
  - Kani‑verified invariants: RoH monotonic under corridor tightening and RoH ≤ 0.30 for any axis vector in \([0,1]^8\).[file:77][file:92]

## Neurorights

- Seven neurorights encoded as a bitmask (in companion shards/functions):[file:78][file:92]
  - Mental privacy.
  - Cognitive liberty.
  - Mental integrity.
  - Non‑punitive XR.
  - Soul non‑addressability.
  - Non‑commercial neural data.
  - Fair benefit.
- **NeurorightsShard**:
  - `bits: u32` with reserved upper bits forced to zero.[file:78]
  - `is_active(Neuroright)` checks whether a right is enabled.
- **neurorights_ok(snapshot, shard) -> bool**:
  - Validates a `RealityOsSnapshot` against active rights:
    - No raw EEG/BCI export under mental privacy.
    - No forced XR or punitive modes under cognitive liberty / non‑punitive XR.
    - Psychrisk and RoH within integrity corridors under mental integrity.
    - No soul addressing/cloning tags under soul non‑addressability.
    - No commercial neural export under non‑commercial neural data.
    - Host benefit routing honored under fair benefit.[file:78][file:92]
  - Monotone: adding rights only adds conjunctive checks; cannot make an invalid snapshot valid.[file:78]

## Mathematical Model

- Eight‑axis state vector \(s(t) \in [0,1]^8\) with:
  - \(x_{\text{blood}}\): ATP corridor occupancy (energy ledger).[file:77]
  - \(x_{\text{oxygen}}\): perfusion/oximetry ratio.[file:77]
  - \(x_{\text{microvasc}}\): CapillaryRisk based on density and clogging.[file:77]
  - \(x_{\text{thermal}}\): neurothermal profile from bio‑heat corridors.[file:77]
  - \(x_{\text{fear}}\): Hawkes‑based autonomic fear intensity, bounded to \(0.31 \le x_{\text{fear}} \le 0.68\).[file:77]
  - \(x_{\text{pain}}\): multi‑timescale nociceptive risk.[file:77]
  - \(x_{\text{immune}}\): lymphatic inflammatory burden.[file:77]
  - \(x_{\text{psych}}\): PsychContinuity co‑metric combining DMN coherence and autobiographical consistency.[file:77]
- CapillaryRisk:
  - Weighted quadratic mean of density risk \(d\) and clogging score \(c\): convex, monotone, and normalized.[file:77]
- RoH aggregation:
  - Weighted sum of axes with weights summing to 0.30, ensuring RoH ceiling.[file:77][file:92]

## Formal Verification (Kani)

- `crates/reality_os_core/src/roh_kani.rs` (pattern from Nano‑Tree core):[file:77]
  - `verify_roh_monotonicity_under_tightening`:
    - Assumes `x_new >= x_old` componentwise under corridor tightening.
    - Proves `RoH(x_new) >= RoH(x_old)`.[file:77]
  - `verify_global_roh_ceiling_invariant`:
    - Proves `0.0 <= RoH(total) <= 0.30` for all clamped axis vectors.[file:77][file:92]
- Additional planned harnesses:
  - Neurorights monotonicity: adding rights cannot weaken validation.
  - HardStop correctness: PsychContinuity floor (< 0.80) always triggers global veto.[file:77][file:92]

## Governance and Identity

- Reality.os kernel is bound to:
  - `HOSTDID = "didalnOrganicCPU"` (sovereign OrganicCPU identity).[file:77][file:78]
  - `bostromaddress = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"`.[file:77][file:101]
- ALN clause:
  - `ALN.MIGRATION.CYBERCOREAUTHORITY.v1` governs non‑degrading schema evolution.[file:78][file:101]
- Workspace metadata enforces:
  - `norollback = true`, `maxroh = 0.3`, capability floor ≥ 0.8, neurorights ceilings and thermal limits.[file:78][file:101]

## Integration with Nano‑Tree and Cybercore

- Reality.os core is the execution environment for:
  - Nano‑Tree Tree‑of‑Life kernel and RoH evaluator.[file:77]
  - Nanoswarm control crates (`nanoswarm_core`, `cybernano-physio`, biospatial guards) via shared state and verdicts.[file:100][file:92]
  - Organichain and Cybercore governance crates through shared identity and ALN shards.[file:101]

## License

- Dual‑licensed under MIT OR Apache‑2.0, aligned with the Cybercore workspace and Nano‑Tree stack.[file:101]
