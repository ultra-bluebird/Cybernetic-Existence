# nanoswarm-material-ml

`nanoswarm-material-ml` is a Candle-based machine-learning crate that predicts biocompatible nanoswarm materials from molecular dynamics (MD) features, aligned with Organichain `rohvalue` and immune activation corridors.

It is **non-actuating** and governance-first: it suggests candidate materials but does not deploy them. Actual nanoswarm missions remain governed by Organichain and ALN shards.

---

## Purpose

- Ingest MD-derived features for nanoswarm surface coatings:
  - Surface charge density (`sigma_surf`).
  - Hydrophobicity index (`hydrophobicity`).
  - Elastic modulus (`elastic_modulus`).
  - Optional extras: roughness, zeta potential, ligand density.
- Learn to predict:
  - Normalized Organichain `rohvalue_norm` (risk-of-harm / corridor fit).
  - Normalized immune activation (`immune_activation_norm`).
- Provide a selection score:
  - \( J(x) = w_R \cdot \hat{R}_{\text{oh}}(x) - w_I \cdot \hat{I}_{\text{immune}}(x) \),
    with \(w_R, w_I > 0\) chosen under Organichain governance.

This helps identify nanoswarm materials that are **high capability, low immune activation**, while keeping RoH and biocompatibility corridors intact.

---

## Data and features

Training data is expected in:

- `data/md/nanoswarm_material_features.csv`

with columns:

- `sigma_surf`
- `hydrophobicity`
- `elastic_modulus`
- `roughness`
- `zeta_potential`
- `ligand_density`
- `rohvalue_norm`
- `immune_activation_norm`

Each row is loaded into:

- `MaterialFeatures`
- `MaterialTargets`
- combined `MaterialSample`.

The `rohvalue_norm` and `immune_activation_norm` labels are derived from the Organichain RoH ledger and immune assays, normalized into [0,1] corridors.

---

## Model and training

The core model is:

- `MaterialPredictor`:
  - Shared encoder: MLP with `hidden_dim` and `hidden_layers`.
  - Two heads:
    - `roh_head` → `rohvalue_norm` prediction.
    - `immune_head` → `immune_activation_norm` prediction.

Training scaffold:

```rust
let config = ModelConfig {
    input_dim: 6,
    hidden_dim: 64,
    hidden_layers: 2,
    roh_head_dim: 1,
    immune_head_dim: 1,
};

let model = train_material_predictor(&samples, &config, epochs, lr)?;
```

Loss objective:

- \(\mathcal{L} = \lambda_R \cdot \text{MSE}(\hat{R}_{\text{oh}}, R_{\text{oh}}) + \lambda_I \cdot \text{MSE}(\hat{I}_{\text{immune}}, I_{\text{immune}})\),
  with \(\lambda_R, \lambda_I > 0\) configured via governance.

---

## Selection and corridors

After training:

- Use `selection_score(roh_pred, immune_pred, w_r, w_i)` to rank candidate materials.
- Apply corridor filters:
  - `rohvalue_norm` must map to RoH ≤ 0.30.
  - `immune_activation_norm` must keep biocompatibility ≥ 0.57.

Only materials that satisfy these corridors and yield high selection scores are surfaced to CyberFS AI surfaces and Organichain governors.

---

## Training CLI and model weights

A simple training CLI is provided (Python or Shell-wrapped):

- `scripts/train_nanoswarm_material_ml.py`:

  - Loads `data/md/nanoswarm_material_features.csv`.
  - Calls into a Rust binary or FFI wrapper that uses `train_material_predictor`.
  - Writes model weights to `models/nanoswarm_material_ml_weights.json`.

Model weights are then indexed in:

- `cyberfs-core/models/nanoswarm_material_ml_weights.json`

for readonly access by AI tools (`ai_nanoswarm_material_predict`) and governance audits.

---

## Safety and verification

- Kani harness `material_features_tensor_harness` ensures feature tensors are constructed within safe envelopes and finite ranges.
- ALN shard `aln/NanoswarmMaterialPredictor.v1.aln` binds:
  - The crate and training pipeline.
  - MD data sources and Organichain RoH ledger.
  - Neurorights and corridor invariants.

This ensures the pipeline stays governance-bound, non-actuating, and aligned with Organichain’s sovereign corridors.
