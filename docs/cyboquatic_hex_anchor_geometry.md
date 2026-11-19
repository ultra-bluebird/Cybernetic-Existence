# Cyboquatic Hex-Anchor Geometry and Corridor Calibration

## Purpose

This specification defines local, peer-verifiable topology and metric-consistency
checks for Phoenix-region restoration-corridor anchors.

It supports offline validation of declared corridor adjacency. It does not establish
property boundaries, legal access rights, survey authority, equipment authorization,
or real-world actuation permission.

## Minimal anchor primitive set

A hex anchor is valid only when all fields below are present.

| Primitive | Type | Purpose |
|---|---|---|
| `anchor_id` | stable text | Locally unique anchor reference. |
| `grid_id` | stable text | Declares the discrete hex-grid namespace and resolution. |
| `cell_q` | signed integer | Axial hex coordinate q. |
| `cell_r` | signed integer | Axial hex coordinate r. |
| `basin_crs` | text | Declared local basin coordinate reference. |
| `center_x_m` | finite real | Coordinate x in metres in the declared basin CRS. |
| `center_y_m` | finite real | Coordinate y in metres in the declared basin CRS. |
| `edge_index` | integer in [0, 5] | Canonical directional index for an asserted shared edge. |
| `neighbor_anchor_id` | stable text | Peer anchor claimed to share that edge. |
| `corridor_id` | stable text | Named logical drainage or restoration corridor. |
| `geometry_revision` | positive integer | Revision used for anti-rollback validation. |
| `evidence_hex` | text | Reference to the selected Phoenix evidence anchor. |

## Hex axial neighbor rule

For an anchor at `(q, r)`, valid neighbor coordinate deltas are:

- `(1, 0)`
- `(1, -1)`
- `(0, -1)`
- `(-1, 0)`
- `(-1, 1)`
- `(0, 1)`

A claimed neighbor is topologically consistent if and only if its axial coordinate
difference equals the delta for the declared `edge_index`, and the neighbor
reciprocally declares the opposite edge.

Opposite edge mapping:

- `0 ↔ 3`
- `1 ↔ 4`
- `2 ↔ 5`

## Corridor edge agreement

Two peers A and B agree on a shared corridor edge only when:

1. `A.grid_id = B.grid_id`.
2. `A.corridor_id = B.corridor_id`.
3. `B.cell_q - A.cell_q` and `B.cell_r - A.cell_r` equal the axial delta for A's edge.
4. B declares A as its neighbor on the opposite edge.
5. Both records use the same `geometry_revision`.
6. Neither record is withdrawn or superseded.
7. A local validator independently recomputes the predicates from both records.

No central service is required. A peer receives the relevant signed or
content-addressed assertions, verifies their integrity using its agreed local trust
policy, and recomputes the discrete predicate.

## Affine-invariant residual

Let `e_i = d_i - d_hat_i` be the residual of segment i.

For a collection of residuals, estimate or declare a positive-definite distance-error
covariance matrix `Sigma_d`. The whitened residual is:

`R_affine = (1 / N) * sum_i (e_i^T Sigma_d^-1 e_i)`

For scalar along-corridor distances:

`R_affine = (1 / N) * sum_i ((d_i - d_hat_i)^2 / sigma_i^2)`

where `sigma_i^2` is the uncertainty expressed in the same physical distance unit as
the measurement.

The invariant requirement is not achieved by an arbitrary scalar weight alone.
It requires that uncertainty transform with the coordinate transformation. Under an
invertible affine map `x' = A x + b`, use the induced metric:

`G' = (A^-1)^T G A^-1`

or equivalently propagate covariance:

`Sigma' = A Sigma A^T`.

When corridor distance is computed as physical arclength after a declared local
metric transformation, the scalar uncertainty-normalized residual remains invariant
under a mere re-expression of the same basin geometry.

## Calibration acceptance rule

A corridor calibration run is accepted only if:

- each segment has a positive finite uncertainty;
- each predicted and measured length is finite and non-negative;
- each accepted segment maps to a validated shared edge;
- `R_affine` is less than or equal to the declared corridor threshold;
- no segment exceeds its declared maximum normalized residual;
- all geometry records share one declared basin CRS and geometry revision.

The threshold is a local engineering parameter and is not evidence of environmental,
surveying, machinery-safety, or regulatory conformance without the relevant
project-specific review and measurements.
