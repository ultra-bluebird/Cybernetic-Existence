title: ATP Scheduler Medical Kernel Spec
version: 1.0.0
aln.fragment_id: AtpSchedulerKernel.medical-kernel.v1.aln
host.did: did.cybercoreorganic-host
bostrom.address: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
migration.clause: ALN.MIGRATION.CYBERCORE_AUTHORITY.v1

---

## 1. Purpose and clinical surface

- Manages ATP budgets for organs and tissues, ensuring nanoswarm and neuromorphic workloads never exceed safe metabolic ceilings. [file:1][file:3]
- Couples BLOOD and LIFEFORCE token floors to ATP usage and enforces non‑exceedance via formal Kani harnesses. [file:1][file:3]
- Provides ATP margin tags into EvidenceBundle10 and participates in vampiresafe mission vetos. [file:1][file:21]

Clinical reading:

- “ATP spend ≤ max daily” means the planned mission will not drive tissues into ischemic or over‑drained states. [file:1]
- “ATP ceiling monotone” means changes to corridor definitions can only lower or maintain ceilings, never raise them. [file:1]

---

## 2. State, inputs, outputs

Inputs: [file:1][file:3]

- Organ masses (heart, muscle, etc.).
- Current ATP expenditure per organ.
- Planned ATP cost for missions.
- BLOOD and LIFEFORCE token states. [file:3][file:21]

Internal state:

- `AtpTissueEnergyCorridor` with function `max_daily_atp_joules(heart_mass_g, muscle_mass_g)`. [file:1]
- Per‑organ daily and mission budgets.

Outputs:

- `atp_margin` scalar for EvidenceBundle10 (residual fraction of budget). [file:1]
- Guard verdict Brake/Veto on over‑budget missions. [file:1]

---

## 3. Core equations and proof

Max ATP per day for given anatomy: [file:1]

\[
E_{\max} = f_{\text{ATP}}(m_{\text{heart}}, m_{\text{muscle}})
\]

Constraint:

\[
E_{\text{spent,today}} \le E_{\max}
\]

Kani harness `atp_daily_ceiling_monotone` proves:

- For any `heart_mass_g ∈ [0,1000]`, `muscle_mass_g ∈ [0,50000]`, and `spent_today ≥ 0`, the corridor’s `max_daily_atp_joules` bound is never violated by allowed schedules. [file:1]

Clinical meaning:

- Schedulers cannot authorize workloads that exceed physiologically safe daily ATP use given host anatomy; this remains true under all valid parameterizations captured by Kani. [file:1]

---

## 4. Thresholds and guards

- Global per‑upgrade RoH Delta ceiling: `roh_delta ≤ 0.30` enforced in `UpgradeManifest.validate`. [file:1]
- ATP scheduler guard:

  - Veto if `spent_today + mission_cost > E_max`.
  - Brake if approaching `E_max` within a defined safety margin (e.g., > 80% of budget). [file:1]

- Lifeforce coupling:

  - If lifeforce below floor, ATP‑intensive missions are vetoed regardless of ATP margin. [file:1][file:21]

Clinical reading:

- ATP budgets protect against systemic fatigue, ischemia, and organ overuse; lifeforce provides an additional veto layer independent of pure ATP math. [file:1][file:21]

---

## 5. EvidenceBundle10 mapping

Canonical tags: [file:1][file:3][file:21]

- `TAG_ATP_MARGIN` — explicit ATP budget and margin calculations.
- `TAG_LIFEFORCE` — coupling between ATP usage and lifeforce depletion.
- `TAG_BIOSPATIAL/TOKEN_FLOOR` (via BLOOD floors) — ensures ATP missions respect perfusion floors. 
- `TAG_CORRIDOR_POLYTOPE` — ATP axis in RoH kernel state.
- `TAG_AUDIT_CONSENSUS` — validation studies and lab data.

Any `UpgradeManifest` that changes ATP budgets must include an EvidenceBundle10 with these tags and pass `kinds_ok()`. [file:1]

---

## 6. EvidenceBundle10 short hex sequence

Representative short hex IDs: [file:1][file:3]

- `TAG_ATP_MARGIN.short_hex = "a1f3c9b2"`
- BLOOD token floors evidence tags (from `TokenFloor.sai`) start with `"c1b0b1.."`.

These IDs ensure ATP decisions are tied to both energetic and perfusion constraints.

---

## 7. SQL discoverability

`schemata/master.sql`:

- `medical_kernel_specs` row:
  - `kernel_id = 'AtpSchedulerKernel'`
  - `doc_path = 'docs/medical-kernels/atp-scheduler-kernel.md'`
  - `evidence_bundle10_required = TRUE`
  - `primary_tags = '{AtpMargin, Lifeforce, CorridorPolytope, AuditConsensus}'`
  - `mt6883_binding = 'atp-consumption-bounds, bioscale-upgrade-store'` [file:1][file:3]

`evidence_bundle10_registry`:

- `kernel_id = 'AtpSchedulerKernel'`
- `bundle_registry_ref = 'atp.tissue.energy.corridor.v1'` [file:1]

---

## 8. Clinical interpretation cheatsheet

- ATP scheduler is the metabolic ledger; no mission may run if it would overspend the daily budget or violate lifeforce and BLOOD floors. [file:1][file:3][file:21]
- Floors and budgets are DID‑bound and monotone‑tightened; no manifest or shard can raise them beyond empirically proven safe levels. [file:1][file:3]
