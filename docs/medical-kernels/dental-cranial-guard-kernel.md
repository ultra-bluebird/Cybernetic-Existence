title: DentalCranial Guard Medical Kernel Spec
version: 1.0.0
aln.fragment_id: DentalCranialGuardKernel.medical-kernel.v1.aln
host.did: did.cybercoreorganic-host
bostrom.address: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
migration.clause: ALN.MIGRATION.CYBERCORE_AUTHORITY.v1

---

## 1. Purpose and clinical surface

- Governs nanoswarm and device activity in dental and cranial regions, focusing on local thermal deltas and their contribution to CNS risk. [file:1][file:3]
- Enforces a monotone hazard lattice: higher temperature deltas can never yield more permissive guard verdicts. [file:1]
- Links dental thermal corridors to global CNS RoH and neurorights protections. [file:1][file:3][file:22]

Clinical reading:

- “Dental cranial safe” means local thermal changes stay within brake and veto thresholds, and the resulting CNS RoH remains below 0.30. [file:1][file:3]
- Monotonicity guarantee removes the possibility of “heat loopholes” where hotter states could appear numerically safer. [file:1]

---

## 2. State, inputs, outputs

Inputs: [file:1][file:3]

- Local temperature delta \(ΔT\) (Celsius) in dental/cranial region.
- RoH projection for CNS with current state vector and lifeforce.
- EvidenceBundle10 for this envelope.

Internal state:

- `DentalCranialHazardEnvelope` with:
  - `temp_delta_brake_c`
  - `temp_delta_veto_c`
  - `evidence: EvidenceBundle10` [file:1]

Outputs:

- `GuardOutcome { verdict, roh_projection, evidence }` where verdict is Allow, Brake, or Veto. [file:1]

---

## 3. Core equations and monotonicity proof

Decision rule: [file:1]

- If \(ΔT \ge temp\_delta\_veto_c\) → `SafetyVerdict::Veto`
- Else if \(ΔT \ge temp\_delta\_brake_c\) → `SafetyVerdict::Brake`
- Else → `roh_projection.verdict` (inherits from RoH kernel)

Monotonicity Kani harness: [file:1]

- For `t1 ≤ t2`, the severity function mapping \(ΔT → verdict\) is non‑decreasing in severity (Allow < Brake < HardStop < Veto). 

Clinical meaning:

- Increasing heat load cannot transform a Brake into an Allow; the guard is temperature‑monotone by construction and proof. [file:1]

---

## 4. Thresholds and guards

Example envelope thresholds (from harness): [file:1]

- `temp_delta_brake_c = 2.0`
- `temp_delta_veto_c = 4.0`

Clinical reading:

- Mild heating up to 2 °C above baseline is allowed if RoH remains safe.
- Moderate heating (2–4 °C) triggers Brake.
- Severe heating (≥ 4 °C) is always vetoed, independent of other axes. [file:1][file:3]

---

## 5. EvidenceBundle10 mapping

Canonical tags: [file:1][file:3][file:22]

- `TAG_THERMAL` — dental cranial thermal corridor definitions.
- `TAG_CORRIDOR_POLYTOPE` — mapping between local dental corridor and global CNS RoH. 
- `TAG_TWIN_PROOF` — where available, twin modeling of dental cranial heating and CNS impacts.
- `TAG_AUDIT_CONSENSUS` — calibration data and dental thermal safety studies.
- `TAG_LIFEFORCE` — coupling between repeated dental heating, systemic fatigue, and lifeforce. 

---

## 6. EvidenceBundle10 short hex sequence

Representative short hex IDs: [file:1][file:3]

- `TAG_THERMAL.short_hex = "2f8c6b44"`
- `TAG_CORRIDOR_POLYTOPE.short_hex = "0fd8a3e9"`

These ensure dental cranial hazards are formally tied into the CNS and RoH kernel corridors.

---

## 7. SQL discoverability

`schemata/master.sql`:

- `medical_kernel_specs` row:
  - `kernel_id = 'DentalCranialGuardKernel'`
  - `doc_path = 'docs/medical-kernels/dental-cranial-guard-kernel.md'`
  - `evidence_bundle10_required = TRUE`
  - `primary_tags = '{Thermal, CorridorPolytope, Lifeforce, TwinProof, AuditConsensus}'`
  - `mt6883_binding = 'cybernano-guards, dental-cranial envelopes'` [file:1][file:3]

`evidence_bundle10_registry`:

- `kernel_id = 'DentalCranialGuardKernel'`
- `bundle_registry_ref = 'dental.cranial.hazard.v1'` [file:1]

---

## 8. Clinical interpretation cheatsheet

- Dental and cranial heating are treated as CNS‑critical; guards are provably monotone in temperature and anchored into CNS RoH and neurorights corridors. [file:1][file:3][file:22]
- EvidenceBundle10 guarantees that local decisions always carry full CNS context and proof artifacts. [file:1][file:3]

---

# Layered config for population vs host‑specific medicine

## 1. Layered config model

Layers (in order of application): [file:1][file:3][file:21][file:22]

- Population defaults:
  - ALN shards like `.acute.v1.aln` and `.chronic.v1.aln` define universal safety floors and RoH 0.30 ceiling. [file:1][file:3]
- Environment overrides:
  - Site‑specific or device‑specific envelopes (e.g., Phoenix ICU vs lab zone), constrained to be *tighter or equal* to population defaults. [file:3]
- Host ALN shards:
  - DID‑bound shards for this host (`host.did` + `bostrom.address`) can *further tighten* corridors but may not weaken any universal floor. [file:3][file:21]

Invariants:

- For any corridor parameter \(p\), we must have:
  - \(p_{\text{host}} \subseteq p_{\text{env}} \subseteq p_{\text{pop}}\) in the sense of corridor narrowing (e.g., lower ceilings, higher floors). [file:3][file:22]
- Global RoH ceiling 0.30 is universal; no layer may raise it. [file:1][file:3]

Clinical meaning:

- Population rules set non‑derogable safety baselines; environment and host layers may only introduce *more protection* or *more individualization*, never less. [file:3][file:22]

---

## 2. Rust loader enforcement (non‑weakening) with Kani

Rust loader pattern (conceptual): [file:1][file:3][file:21][file:22]

- Loader reads:

  - `PopConfig` from population ALN shards.
  - `EnvConfig` from environment shards (optional).
  - `HostConfig` from host ALN bundle. 

- Merges them into `EffectiveConfig` with checks:

  - For each scalar ceiling \(c\): `c_effective ≤ c_pop`.
  - For each floor \(f\): `f_effective ≥ f_pop`.
  - For RoH: `roh_ceiling_effective ≤ 0.30` (already proven). [file:1][file:3]

- Any violation causes loader failure; configs that would weaken safety floors are unrepresentable at runtime. [file:3][file:22]

Kani harness obligations:

- Prove that the merge function is monotone‑tightening:

  - For all valid `PopConfig`, `EnvConfig`, `HostConfig`, the result never increases ceilings or decreases floors. [file:1][file:22]
- Tie proofs to ALN shards:

  - Use shard fields for `toolchainmin`, `roh_ceiling`, `lifeforce_floor`, `token floors` as inputs to the harness. [file:3][file:21][file:22]

Clinical meaning:

- Even if ALN shards or environment files are misconfigured or maliciously edited, loader+Kani guarantees they cannot produce an effective config that weakens any universal or host‑bound safety invariant. [file:1][file:3][file:22]

---

## 3. SQL anchoring for layered config

In `schemata/master.sql` add or extend: [file:3][file:21][file:22]

- Table `clinical_corridor_layers`:

  - `layer_id` ENUM: `population`, `environment`, `host`.
  - `shard_ref` TEXT (ALN shard id).
  - `host_did` TEXT (NULL for population).
  - `bostrom_address` TEXT (NULL for population).
  - `roh_ceiling` NUMERIC.
  - `lifeforce_floor` NUMERIC.
  - `token_floor_blood` NUMERIC.
  - `non_weakening_invariant` BOOLEAN DEFAULT TRUE.

- Table `kernel_layer_binding`:

  - `kernel_id` TEXT.
  - `population_shard_ref` TEXT.
  - `environment_shard_ref` TEXT.
  - `host_shard_ref` TEXT.
  - Foreign keys into `clinical_corridor_layers`.

This schema lets you query, for any kernel (MaterialHazard, Lifeforce, Twin, ATP, MT6883, DentalCranial), which ALN shards define its population defaults, environment tightening, and host‑specific tightening, and verify that non‑weakening holds across all layers. [file:3][file:21][file:22]

---

## 4. EvidenceBundle10 and layered config

- Each EvidenceBundle10 tag must point to a shard whose context explicitly states its layer (`population`, `environment`, `host`) and host binding. [file:1][file:3][file:21]
- Build‑time checks:

  - Ensure every medical action’s EvidenceBundle10 only references shards whose effective parameters are consistent with the non‑weakening merge. [file:1][file:22]

Clinical reading:

- EvidenceBundle10 becomes the provenance spine not only for metrics and thresholds, but also for which layer (population/env/host) supplied each threshold, preserving full clinical context and sovereignty. [file:1][file:3][file:21][file:22]
