title: Lifeforce Medical Kernel Spec
version: 1.0.0
aln.fragment_id: LifeforceKernel.medical-kernel.v1.aln
host.did: did.cybercoreorganic-host
bostrom.address: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
migration.clause: ALN.MIGRATION.CYBERCORE_AUTHORITY.v1

---

## 1. Purpose and clinical surface

- Maintains a normalized lifeforce scalar \(L \in [0, 1]\) derived from HRV, inflammatory markers, sleep, endocrine status, and subjective vitality. [file:1][file:21]
- Enforces per‑mission and per‑episode lifeforce floors that act as hard vetoes in the RoH kernel and daily evolution loop. [file:1][file:21]
- Couples to ATP, BLOOD, PROTEIN token floors and neurorights to prevent “vampiric” missions that would deplete reserves below empirically fitted safe bands. [file:1][file:3][file:21]

Clinical reading:

- “Lifeforce ≥ mission floor” means both the current state and projected trajectory under a mission stay within tolerable fatigue and resilience bands for this host. [file:21]
- “Lifeforce floor veto” means any predicted dip below the floor cancels or brakes nanoswarm or neuromorphic actions. [file:1][file:21]

---

## 2. State, inputs, outputs

Inputs: [file:1][file:21]

- HRV (RMSSD) baseline and z‑score.
- IL‑6, CRP, TNF normalized inflammatory burden.
- Sleep debt and circadian phase.
- Endocrine markers as available.
- Subjective vitality / “could I have tolerated more load?” annotations (host‑specific ALN). [file:21]

Internal state:

- `lifeforce_scalar L` in \([0, 1]\).
- Mission floor \(L_{\min}^{\text{mission}}\).
- Episode floor \(L_{\min}^{\text{episode}}\). [file:21]

Outputs:

- `lifeforce` fed into RoH kernel (veto if below floor). [file:1]
- Guard verdict modifiers for LifeforceEnvelope. [file:1][file:21]

---

## 3. Core equations

Let:

- \(z_{\text{HRV}}\) = normalized HRV z‑score. [file:21]
- \(z_{\text{inflam}}\) = fused IL6/CRP/TNF normalized to \([0, 1]\). [file:1][file:21]
- \(z_{\text{sleep}}\) = normalized sleep adequacy. [file:21]
- \(z_{\text{endo}}\) = endocrine stress index. [file:21]

Example linear‑plus‑clamp embedding:

\[
L_{\text{raw}} = w_{\text{HRV}} \, f_{\text{HRV}}(z_{\text{HRV}})
  + w_{\text{inflam}} \, f_{\text{inflam}}(z_{\text{inflam}})
  + w_{\text{sleep}} \, f_{\text{sleep}}(z_{\text{sleep}})
  + w_{\text{endo}} \, f_{\text{endo}}(z_{\text{endo}})
\]
[file:21]

\[
L = \text{clamp}_{[0, 1]} \left( L_{\text{raw}} \right)
\]
[file:21]

RoH kernel lifeforce veto (already proven): [file:1]

- If \(L < L_{\text{floor}}\), then `SafetyVerdict::Veto` regardless of other axes.

Clinical meaning:

- \(L \approx 1\): fully resourced, no systemic fatigue. [file:21]
- \(L \approx 0.3\): near mission floor, only conservative maintenance missions allowed. [file:21]
- \(L < L_{\text{episode floor}}\): predicted collapse or burnout; actuation is vetoed. [file:21]

---

## 4. Thresholds and guards

Global lifeforce floors (example from nanoswarm formal contract): [file:21]

- Mission floor: \(L_{\text{floor}}^{\text{mission}} = 0.30\).
- Episode floor: \(L_{\text{floor}}^{\text{episode}} = 0.25\).

Invariants (formal contract): [file:21]

- For any step in mission sequence:
  - \(L \ge L_{\text{floor}}^{\text{mission}}\).
- For any care envelope episode:
  - \(L_{\min} \ge L_{\text{floor}}^{\text{episode}}\).

Kani proof (RoH crate): [file:1]

- Harness `lifeforce_floor_enforces_veto` proves any `lifeforce < config.lifeforce_floor` yields `SafetyVerdict::Veto`.

Clinical reading:

- Mission planning must show predicted lifeforce trajectories staying above both floors; otherwise, missions are structurally invalid. [file:21]
- Floors are empirically tuned per host via `lifeforce.embedding.v1.aln` and cannot be decreased by new shards (monotone‑tightening). [file:21][file:3]

---

## 5. EvidenceBundle10 mapping

Canonical tags used for lifeforce decisions: [file:1][file:3][file:21]

- `TAG_LIFEFORCE` — embedding model, calibration data, and floor derivation.
- `TAG_ATP_MARGIN` — coupling between lifeforce and ATP budgets. 
- `TAG_HRV` — HRV corridor and its mapping into lifeforce.
- `TAG_IL6` — inflammatory burden contribution.
- `TAG_CORRIDOR_POLYTOPE` — lifeforce axis in global RoH state vector.
- `TAG_TWIN_PROOF` — twin lifeforce model is stricter than guard floor.
- `TAG_AUDIT_CONSENSUS` — empirical datasets and validation study references.

Each LifeforceEnvelope and any ATP‑vampiric mission manifest must include a valid bundle with these tags and pass `kinds_ok()`. [file:1][file:21]

---

## 6. EvidenceBundle10 short hex sequence

Representative short hex IDs: [file:1]

- `TAG_LIFEFORCE.short_hex = "5e1da2ff"`
- `TAG_ATP_MARGIN.short_hex = "a1f3c9b2"`
- `TAG_HRV.short_hex = "7b93e0c3"`
- `TAG_IL6.short_hex = "e4c1d9a0"`
- `TAG_AUDIT_CONSENSUS.short_hex = "b39d5e14"`

These must be present in the bundle attached to any lifeforce‑gated actuation.

---

## 7. SQL discoverability

`schemata/master.sql`:

- `medical_kernel_specs` row:
  - `kernel_id = 'LifeforceKernel'`
  - `doc_path = 'docs/medical-kernels/lifeforce-kernel.md'`
  - `evidence_bundle10_required = TRUE`
  - `primary_tags = '{Lifeforce, AtpMargin, Hrv, Il6, CorridorPolytope, TwinProof, AuditConsensus}'`
  - `mt6883_binding = 'cybernano-physio, lifeforce.embedding.v1.aln, mt6883-envelope'` [file:1][file:21]

`evidence_bundle10_registry` row:

- `kernel_id = 'LifeforceKernel'`
- `bundle_registry_ref = 'lifeforce.usf.envelope.v1'` [file:1]

---

## 8. Clinical interpretation cheatsheet

- Lifeforce scalar is a DID‑bound resilience index; floors encode “do not cross” zones calibrated from host experience and telemetry. [file:21]
- Veto from low lifeforce dominates even if RoH from other axes appears low, so the system cannot trade chronic exhaustion for short‑term local safety. [file:1][file:21]
