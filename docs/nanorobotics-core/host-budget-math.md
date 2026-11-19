# HostBudget Mathematics & Corridor Normalization

## Purpose
Define the biophysical constraints governing nanoswarm scheduling, duty cycles, and upgrade admissibility.

## Dimensionless Utilization Ratios
For a candidate operation with resource demands:
- Energy: `E_req` (Joules)
- Protein: `P_req` (mg)
- Duty fraction: `D_req` (0.0–1.0)
- Thermal delta: `ΔT_req` (°C)

Given host maximums `E_max`, `P_max`, `D_max`, `ΔT_max`:

```
u_E = E_req / E_max
u_P = P_req / P_max
u_D = D_req / D_max
u_T = ΔT_req / ΔT_max
```

## Corridor Normalization Function
Maps utilization to normalized risk coordinates `r ∈ [0.0, 1.0]` using corridor thresholds:

```
r(x) = 0.0              if x ≤ safe_max
r(x) = 1.0              if x ≥ hard_max
r(x) = (x - safe_max) / (hard_max - safe_max)  otherwise
```

## Residual Risk Calculation
Aggregate quadratic risk metric:
```
V_t = Σ (w_j * r_j²)
```
Where `w_j` are configurable weights per corridor dimension.

## Admissibility Invariant
An operation is admissible only if:
1. `V_after ≤ V_before`
2. `r_j ≤ max_r_axis` for all corridors `j`
3. All evidence bundles are complete (exactly 10 unique, allowed tags).
