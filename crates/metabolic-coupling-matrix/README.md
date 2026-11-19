# metabolic-coupling-matrix

Rust crate that defines and applies a metabolic coupling matrix Λ to nanoswarm duty, density, and task allocation, ensuring that nanoswarm missions respect host metabolic budgets and Lifeforce corridors.

## Scope

- Represents metabolic couplings between:
  - Nanoswarm activity (density, duty, task modes).
  - Host metabolic axes (ATP usage, thermal load, immune activation, LifeforceChi).[file:103]
- Provides:
  - Construction of Λ from ALN shards.
  - Application of Λ in nanoswarm guards to adjust or veto missions.

## Key Guarantees

- RoH ≤ 0.30 preserved:
  - Λ feeds into RoH kernels as an additional axis, shrinking admissible duty when metabolic load approaches ceilings.[file:106]
- Biocompatibility:
  - Pain and fear corridors, biocompatibility-rating ≥ 0.57, and energy envelopes are encoded as constraints on the matrix entries.
- No rollbacks or capability reduction:
  - Matrix updates are tightening-only (entries increase coupling, never relax).
  - Capability floor ≥ 0.8 is maintained by design via Lifeforce envelopes.[file:103]

## Architecture

- Rust 2024, `rust-version = "1.85"`.
- Kani: `kani-verifier = "0.56.0"`.
- Dual-licensed: MIT OR Apache-2.0.
- Data:
  - `MetabolicCouplingMatrix` (Λ) as a fixed-size, host-specific matrix.
  - ALN shards:
    - `metabolic.coupling.host.v1.aln` with evidence-based entries.
- Guard integration:
  - Nanoswarm controllers call Λ to compute:
    - Expected metabolic impact of candidate assignments.
    - Scaling factors or veto decisions.

## Usage

- During mission planning:
  - Evaluate candidate nanoswarm duty against Λ and host budgets.
  - Reject or shrink plans whose metabolic projection exceeds corridor ceilings.
- Kani:
  - Prove Λ is positive and monotone with respect to duty.
  - Prove any guard using Λ respects RoH and energy caps for all admissible inputs.
