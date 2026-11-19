title: Virtual Twin Medical Kernel Spec
version: 1.0.0
aln.fragment_id: VirtualTwinKernel.medical-kernel.v1.aln
host.did: did.cybercoreorganic-host
bostrom.address: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
migration.clause: ALN.MIGRATION.CYBERCORE_AUTHORITY.v1

---

## 1. Purpose and clinical surface

- Maintains a virtual physiological twin that simulates the host’s response under stricter RoH ceilings and corridors than the guard kernel. [file:1]
- Enforces “twin dominance”: any state accepted by the twin must also be inside the guards’ safe polytope; the twin must never authorize something the guard forbids. [file:1]
- Supports predictive planning and optimization while keeping all twin‑derived actions inside proven safety envelopes. [file:1][file:3]

Clinical reading:

- “Twin‑safe” means the simulated host remains safe under a more conservative RoH configuration than the runtime guard; this is a strong form of being “clinically boring.” [file:1]
- “Twin dominance proof” guarantees the twin cannot be mis‑tuned to allow more risk than production guards. [file:1]

---

## 2. State, inputs, outputs

Inputs:

- Current RoH `StateVector7` and lifeforce. [file:1][file:3]
- Candidate mission or envelope parameters (thermal, duty, IL6, material, etc.). [file:1]

Internal state:

- Twin RoH configuration `RoHKernelConfig_twin` with:
  - Identical weights but lower `roh_ceiling` than guard. [file:1]
  - Same lifeforce floor as guard. [file:1]

Outputs:

- Twin RoH scalar and `SafetyVerdict`.
- Twin polytope membership indicator for corridor analysis. [file:1]

---

## 3. Core equations and dominance proof

Twin configuration: [file:1]

- Guard config:
  - \(cfg_g = (\mathbf{w}, c_g, L_{\text{floor}})\)
- Twin config:
  - \(cfg_t = (\mathbf{w}, c_t, L_{\text{floor}})\)
  - \(c_t = 0.9 \cdot \min(c_g, RoH_{\text{GLOBAL}})\)

Twin dominance invariant (Kani harness): [file:1]

- If twin accepts state \(s\) (i.e., \(RoH_t(s) \le c_t\) and verdict not Veto) then `withinguard_polytope(s, cfg_g) == true`. 
- This ensures the twin’s safe set is a strict subset of the guard’s polytope.

Clinical meaning:

- Twin “green” zones imply guard “green or better,” never the reverse. [file:1]
- If the twin rejects an action, clinical pipelines must treat it as unsafe even if guard might nominally allow it (twin is stricter). [file:1]

---

## 4. Thresholds and guards

- Global RoH ceiling remains 0.30; twin ceiling is a strict fraction of guard ceiling (e.g., 0.90 · 0.30). [file:1][file:3]
- Twin polytope and guard polytope share the same axes and Lyapunov function. [file:3]
- Any adjustment to twin parameters must be monotone‑tightening relative to guard; CI and Kani proofs validate this. [file:1]

Clinical reading:

- Twin corridor upgrades can only *tighten* safety (reduce \(c_t\) or weights), never loosen them to accommodate more aggressive missions. [file:1][file:3]

---

## 5. EvidenceBundle10 mapping

Canonical tags: [file:1][file:3]

- `TAG_TWIN_PROOF` — explicit Kani proof artifact that twin safe region ⊂ guard safe region.
- `TAG_CORRIDOR_POLYTOPE` — shared polytope definition between twin and guard.
- `TAG_ATP_MARGIN`, `TAG_THERMAL`, `TAG_IL6`, `TAG_HRV` — axes used in twin simulation.
- `TAG_AUDIT_CONSENSUS` — review of twin configuration and its risk parameters.

Twin oracle crate must require a full EvidenceBundle10 with `TAG_TWIN_PROOF` for any optimization‑driven actuation. [file:1]

---

## 6. EvidenceBundle10 short hex sequence

Representative short hex IDs: [file:1]

- `TAG_TWIN_PROOF.short_hex = "24f8d9c1"`
- `TAG_CORRIDOR_POLYTOPE.short_hex = "0fd8a3e9"`

These must be present in the evidence bundle whenever twin projections inform mission or guard decisions.

---

## 7. SQL discoverability

`schemata/master.sql`:

- `medical_kernel_specs` row:
  - `kernel_id = 'VirtualTwinKernel'`
  - `doc_path = 'docs/medical-kernels/virtual-twin-kernel.md'`
  - `evidence_bundle10_required = TRUE`
  - `primary_tags = '{TwinProof, CorridorPolytope, AtpMargin, Thermal, Il6, Hrv, AuditConsensus}'`
  - `mt6883_binding = 'state-vector-roh-kernel, twin-oracle crate'` [file:1][file:3]

`evidence_bundle10_registry`:

- `kernel_id = 'VirtualTwinKernel'`
- `bundle_registry_ref = 'twin.polytope.dominance.v1'` [file:1]

---

## 8. Clinical interpretation cheatsheet

- Twin acceptance is a *stronger* guarantee than guard acceptance; use it to sign off on aggressive or experimental missions only when both agree. [file:1]
- Any mismatch where twin rejects and guard would allow must default to twin veto, not the other way around. [file:1]
