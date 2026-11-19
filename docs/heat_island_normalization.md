# Heat-Island Differential Normalization

## Base quantity

For hex h and reference hex r:

`DeltaT_hi(h, r) = T_surface(h) - T_surface(r)`

Each surface temperature is an area-weighted zonal mean over the retained part of
the cell, calculated from pixels that meet a declared quality-mask policy:

`T_surface(h) = sum_j(A_j * T_j) / sum_j(A_j)`

where `A_j` is the in-cell area represented by valid pixel j.

## Area comparability

Unequal hex area is handled by area-weighted aggregation before comparison.
Do not divide temperature by hex area, NDVI, or impervious fraction.

Temperature is already an intensive quantity. Dividing it by a land-cover fraction
changes its physical interpretation and causes unstable values near zero.

## Land-cover adjustment model

Let:

- `NDVI_h` be the area-weighted mean normalized difference vegetation index;
- `I_h` be the area-weighted impervious-surface fraction in `[0, 1]`;
- `A_h` be retained hex area in square metres;
- `s(h)` be an optional spatial or basin-stratum term;
- `t(h)` be a matched acquisition-time stratum.

Fit a robust weighted model across valid anchors:

`T_surface(h) = beta_0 + beta_N * NDVI_h + beta_I * I_h + beta_NI * NDVI_h * I_h + s(h) + t(h) + epsilon_h`

Use the retained area, quality weight, and uncertainty as weights:

`w_h = A_h * q_h / sigma_h^2`

where:

- `q_h` is the valid-pixel proportion in `(0, 1]`;
- `sigma_h^2` is the declared temperature-estimation variance.

Define the normalized contrast:

`DeltaT_adj(h, r) = DeltaT_hi(h, r) - beta_N(NDVI_h - NDVI_r) - beta_I(I_h - I_r) - beta_NI(NDVI_h I_h - NDVI_r I_r)`

This compares the observed heat differential after adjusting for observed vegetation
and imperviousness. It does not assert causality.

## Reference cohort

A reference hex MUST:

- have the same sensor acquisition window or a documented temporal correction;
- use the same quality-mask policy;
- be in the same declared terrain, elevation, and basin stratum where feasible;
- have valid NDVI and impervious-fraction coverage;
- not be a partial boundary cell unless the analysis declares it;
- be selected before inspecting the target cell's temperature outcome.

Use either one declared reference hex or a weighted reference cohort:

`T_surface(reference) = sum_k(w_k * T_surface(k)) / sum_k(w_k)`

The same weights and quality rules apply to reference cells.

## Limitations

NDVI and imperviousness are useful covariates but do not alone capture albedo,
shade, irrigation, building geometry, soil moisture, elevation, wind, atmospheric
conditions, or sensor-view effects. Normalized contrasts must retain uncertainty,
source date, quality flags, and model revision.
