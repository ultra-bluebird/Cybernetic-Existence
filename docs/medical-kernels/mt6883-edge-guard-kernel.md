title: MT6883 Edge Guard Medical Kernel Spec
version: 1.0.0
aln.fragment_id: Mt6883EdgeGuardKernel.medical-kernel.v1.aln
host.did: did.cybercoreorganic-host
bostrom.address: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
migration.clause: ALN.MIGRATION.CYBERCORE_AUTHORITY.v1

---

## 1. Purpose and clinical surface

- Governs neuromorphic MT6883 device envelopes (EEG, thermal, duty) used in brain‑adjacent nanoswarm and BCI pipelines. [file:3][file:8]
- Enforces per‑region thermal and duty corridors, neurorights floors, and RoH ceilings using MT6883 telemetry as inputs to the RoH kernel. [file:3][file:8]
- Ensures MT6883‑level decisions cannot weaken central RoH, lifeforce, or neurorights invariants. [file:3][file:8]

Clinical reading:

- “Edge guard safe” means MT6883 device operation (power, duty, thermal) remains within host‑bound brain corridors and neurorights constraints. [file:8]
- Violations trigger Brake/Veto, not parameter relaxation. [file:3][file:8]

---

## 2. State, inputs, outputs

Inputs from MT6883 tables (from brainidentity mapping): [file:8]

- Global and per‑region thermal headroom (baseline vs current cortical temperatures).
- Global and per‑region BCI duty ceilings and rolling averages.
- Global neuromorph APU duty ceilings.
- Neurovascular coupling capacity per region.
- Neurorights margin floor, EEG safety bands, cognitive load envelopes. [file:8]

Internal state:

- `BrainSpecs` struct carrying these fields. [file:8]
- `Mt6883Envelope` capturing current device telemetry. [file:3]

Outputs:

- Local RoH projection for CNS, including thermal and neuromorph duty axes. [file:3][file:8]
- Guard verdicts for MT6883 workloads (Allow, Brake, Veto). [file:3][file:8]

---

## 3. Core equations

Thermal constraints (CNS polytope): [file:3]

\[
A x \le b
\]

with:

- \(x = (\rho, T_{\text{core}}, T_{\text{surf}}, IL6, CRP, TNF)\)
- Bounds:

  - \(T_{\text{core}}^{\min} \le T_{\text{core}} \le T_{\text{core}}^{\max}\) (e.g., 36.0–37.9 °C).
  - \(T_{\text{surf}}^{\min} \le T_{\text{surf}} \le T_{\text{surf}}^{\max}\) (e.g., 35.0–38.2 °C). [file:3]

Duty constraints (BrainSpecs): [file:8]

- BCI duty per region:

  - \(d_{\text{BCI,cur}}^{(r)} \le d_{\text{BCI,max}}^{(r)}\)

- Neuromorph duty per region:

  - \(d_{\text{neu,cur}}^{(r)} \le d_{\text{neu,max}}^{(r)}\)

Neurorights margin floor: [file:8]

- `neurorights_margin_floor` and pain/fear indices must remain within allowed bands.

Clinical meaning:

- MT6883 workloads must maintain cortical temperature and duty cycles within safe corridors tuned per region and NVC capacity; these feed the RoH kernel’s thermal and neuromorphic axes. [file:3][file:8]

---

## 4. Thresholds and guards

- Global RoH ceiling: 0.30 (CNS critical). [file:3]
- Region‑specific headroom from `region_temp_headroom_c` and duty ceilings. [file:8]
- Neurorights margin floor cannot be crossed; operations that would do so are vetoed. [file:3][file:8][file:22]

Guards:

- Brake on approaching thermal or duty ceilings.
- Veto when exceeding any region’s corridor, RoH ceiling, or neurorights margin. [file:3][file:8]

Clinical reading:

- Brain‑adjacent compute behaves like a medical device envelope, not a general GPU; clinical corridors take precedence over performance. [file:3][file:8]

---

## 5. EvidenceBundle10 mapping

Canonical tags: [file:1][file:3][file:8][file:22]

- `TAG_THERMAL` — CNS thermal polytopes.
- `TAG_HRV` and `TAG_LIFEFORCE` — coupling between cognitive load, HRV, and lifeforce.
- `TAG_NEURORIGHTS` — neurorights floors and no‑non‑consensual modulation clause.
- `TAG_CORRIDOR_POLYTOPE` — CNS corridor polytope for RoH.
- `TAG_TWIN_PROOF` — where twin CNS models constrain MT6883 decisions.
- `TAG_AUDIT_CONSENSUS` — clinical and legal neurorights references.

---

## 6. EvidenceBundle10 short hex sequence

Representative short hex IDs: [file:1][file:3][file:8][file:22]

- `TAG_THERMAL.short_hex = "2f8c6b44"`
- `TAG_NEURORIGHTS.short_hex = "d0174aac"`
- `TAG_HRV.short_hex = "7b93e0c3"`

These tags must appear in the bundle for any MT6883‑driven decision affecting RoH, lifeforce, or neurorights.

---

## 7. SQL discoverability

`schemata/master.sql`:

- `medical_kernel_specs` row:
  - `kernel_id = 'Mt6883EdgeGuardKernel'`
  - `doc_path = 'docs/medical-kernels/mt6883-edge-guard-kernel.md'`
  - `evidence_bundle10_required = TRUE`
  - `primary_tags = '{Thermal, Hrv, Lifeforce, Neurorights, CorridorPolytope, TwinProof, AuditConsensus}'`
  - `mt6883_binding = 'mt6883-envelope, docs/mt6883-brain-identity-mapping.md'` [file:3][file:8]

`evidence_bundle10_registry`:

- `kernel_id = 'Mt6883EdgeGuardKernel'`
- `bundle_registry_ref = 'cns.mt6883.guard.v1'` [file:3][file:8]

---

## 8. Clinical interpretation cheatsheet

- MT6883 is treated as a medical subsystem; any compute plan that would violate CNS corridors or neurorights is structurally invalid. [file:3][file:8][file:22]
- EvidenceBundle10 ensures device‑level decisions are always justified by up‑to‑date host‑bound ALN shards. [file:1][file:3][file:8]
