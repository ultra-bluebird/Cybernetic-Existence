# Pain/Fear Hardware Clamp Specification

## Overview
The `PainFearClamp` is a deterministic, monotone lookup table deployed at the hardware or firmware layer to prevent nociceptive threshold violations during nanoswarm actuation.

## Mathematical Formulation
Given nociceptive indices `p ∈ [0,1]` (pain) and `f ∈ [0,1]` (fear):

```
c(p, f) = φ_p(p) × φ_f(f)
```

Where each component uses piecewise linear clamping:
```
φ_x(x) = 1.0                  if x ≤ floor_x
φ_x(x) = 1 - α × ((x - floor_x) / (ceiling_x - floor_x))  if floor_x < x < ceiling_x
φ_x(x) = 0.0                  if x ≥ ceiling_x
```

## Monotonicity Invariant
For any `x1 ≤ x2`, `φ(x2) ≤ φ(x1)`. This guarantees that increasing pain or fear never increases actuation force.

## Hardware Deployment
- LUT size: configurable grid (e.g., 64×64 bins).
- Fixed-point arithmetic recommended for deterministic FPGA/ASIC execution.
- Pre-guard path: intercepts requested actuation before software scheduler evaluation.

## Calibration
Parameters (`floor`, `ceiling`, `slope`) are host-specific and derived from clinical qEEG/fear calibration protocols. Updates follow a strict tighten-only policy.
