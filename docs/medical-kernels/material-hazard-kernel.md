# docs/medical-kernels/material-hazard-kernel.md

title: MaterialHazardKernel Medical Kernel Spec
version: 1.0.0
aln.fragment_id: MaterialHazardKernel.medical-kernel.v1.aln
host.did: did.cybercoreorganic-host
bostrom.address: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
migration.clause: ALN.MIGRATION.CYBERCORE_AUTHORITY.v1

---

## 1. Purpose and clinical surface

- Computes a scalar material risk index for nanoswarm materials and device classes and feeds the `material` component of the 7‑D RoH kernel. [file:1][file:3]
- Enforces that more toxic materials, higher density, or higher RF/thermal output can only increase or leave unchanged the risk weight (monotone hazard). [file:1][file:3]
- Couples to neurorights and soul guardrail veto so that a high material risk can never override augmentation continuity and mental privacy floors. [file:1][file:22]

Clinical reading:

- “Material risk ≤ threshold” means the chosen nanomaterial, coatings, and RF profile are acceptable for the planned tissue corridor under RoH ≤ 0.30. [file:1][file:3]
- “Monotone material risk” means any future shard tightening or data update can only *raise* the estimated risk of a given material, never lower it, so safety floors cannot silently weaken. [file:1][file:3]

---

## 2. State, inputs, outputs

- Inputs:
  - `MaterialClass` (e.g., catalytic, structural, carrier). [file:1]
  - Empirical toxicity index \(T \in [0, 1]\) from ALN biocompatibility shards. [file:1][file:3]
  - Clearance half‑life \(t_{1/2}\) or normalized clearance index \(C \in [0, 1]\). [file:1][file:3]
  - RF / thermal emission profile from `RFPathLossModel.sai` and thermal envelopes. [file:3]
- Internal state:
  - `BiocompatibilityProfile` with fields `toxicity_index`, `clearance_index`, `thermal_gain`, `rf_gain`. [file:1]
- Outputs:
  - Scalar material risk weight \(R_{\text{mat}} \in [0, 1]\) for the RoH kernel’s `material` axis. [file:1]
  - EvidenceBundle10 tags bound to nanoswarm material evidence. [file:1][file:3]

---

## 3. Core equations

Let:

- \(T\) = toxicity index in \([0, 1]\). [file:1]
- \(C\) = clearance safety index in \([0, 1]\), where higher is safer (faster clearance). [file:1]
- \(H\) = normalized thermal/RF hazard in \([0, 1]\). [file:3]
- \(w_T, w_C, w_H\) = weights for toxicity, clearance, and thermal/RF. [file:1]

Then:

- Clearance penalty \(P_C = 1 - C\). [file:1]
- Material risk:
  \[
  R_{\text{mat}} = \min\left(1,\; w_T \, T + w_C \, P_C + w_H \, H \right)
  \]
  [file:1][file:3]

Monotonicity requirement:

- If \(T_2 \ge T_1\), \(C_2 \le C_1\), and \(H_2 \ge H_1\) then \(R_{\text{mat},2} \ge R_{\text{mat},1}\). [file:1]
- Kani harness `biocompatibility_monotone_with_toxicity` proves that increasing `toxicity_index` cannot decrease `risk_weight`. [file:1]

Clinical meaning:

- \(R_{\text{mat}} \approx 0\): material behaves like inert carrier in this tissue corridor. [file:1]
- \(R_{\text{mat}} \approx 1\): material is at or beyond acceptable toxicity or heating limits; RoH kernel will push overall RoH toward ceiling and guards will brake or veto. [file:1][file:3]

---

## 4. Thresholds and guards

- Global RoH ceiling: \(RoH_{\max} = 0.30\); material risk contributes one axis to this ceiling. [file:1][file:3]
- Corridor‑specific material ceilings derived from `TokenFloor` and `BiospatialRegion`:
  - CNS corridors: stricter weights via `AlphaWeight` (`criticalitytier = CNS‑Vital`). [file:3]
- Guard invariants:
  - Any increase in toxicity, residence time, or RF/thermal output cannot reduce the material risk weight (Kani proof). [file:1]
  - Soul guardrail veto must be applied after material risk, so neurorights floors dominate even for “safe” materials. [file:22]

Clinical reading:

- Changing to a “stronger” or more energetic material can never be justified by a lower numerical risk; the kernel forbids such down‑weighting. [file:1]
- CNS‑adjacent use is evaluated under the tightest material corridor, coupled with global RoH 0.30, so cranial uses are always the most conservative. [file:3]

---

## 5. EvidenceBundle10 mapping

Canonical tag bindings for MaterialHazardKernel decisions:

- `TAG_NANOSWARM_MATERIAL` — biocompatibility data, toxicity, clearance. [file:1][file:3]
- `TAG_THERMAL` — RF/thermal heating coupling to CNS and organ Tsafe polytopes. [file:3]
- `TAG_CORRIDOR_POLYTOPE` — material axis in corridor polytope \(A x \le b\). [file:3]
- `TAG_TWIN_PROOF` — virtual twin shows stricter material risk ceilings than guards. [file:1]
- `TAG_AUDIT_CONSENSUS` — peer‑reviewed materials data and lab certificates. [file:1][file:22]

Each GuardOutcome that depends on material risk must embed a full EvidenceBundle10 and pass `kinds_ok()`. [file:1]

---

## 6. EvidenceBundle10 short hex sequence

Representative short hex IDs (already present in your registry; listed here for kernel traceability): [file:1][file:3]

- `TAG_NANOSWARM_MATERIAL.short_hex = "6ac2f9d9"`
- `TAG_THERMAL.short_hex = "2f8c6b44"`
- `TAG_CORRIDOR_POLYTOPE.short_hex = "0fd8a3e9"`
- `TAG_TWIN_PROOF.short_hex = "24f8d9c1"`
- `TAG_AUDIT_CONSENSUS.short_hex = "b39d5e14"`

These IDs must appear in the EvidenceBundle10 attached to any MaterialHazardKernel decision path.

---

## 7. SQL discoverability

Schemata anchor:

- File: `schemata/master.sql`
- Table: `medical_kernel_specs`

Recommended rows for MaterialHazardKernel:

- `kernel_id = 'MaterialHazardKernel'`
- `doc_path = 'docs/medical-kernels/material-hazard-kernel.md'`
- `evidence_bundle10_required = TRUE`
- `primary_tags = '{NanoswarmMaterial, Thermal, CorridorPolytope, TwinProof, AuditConsensus}'`
- `mt6883_binding = 'nanorobotics-core.materials, rfpathlossmodel'` [file:1][file:3]

Evidence bundle cross‑link:

- Add to `evidence_bundle10_registry`:
  - `kernel_id = 'MaterialHazardKernel'`
  - `bundle_registry_ref = 'evidence.default.bundle10.v1'`
  - `tags_hex = ARRAY['6ac2f9d9','2f8c6b44','0fd8a3e9','24f8d9c1','b39d5e14']` [file:1]

---

## 8. EvidenceBundle10 tag usage (clinical)

Clinical interpretation per tag for this kernel: [file:1][file:3][file:22]

- NanoswarmMaterial — “We have up‑to‑date, DID‑bound toxicity and clearance data for this exact material class.”
- Thermal — “RF and thermal envelopes for this material in this organ are within Tsafe polytope bounds.”
- CorridorPolytope — “This kernel’s material risk is derived from the same RoH polytope as other corridors.”
- TwinProof — “The virtual twin’s stricter material model never authorizes anything the guard would forbid.”
- AuditConsensus — “Independent labs and governance anchors confirm the material evidence chain.”
