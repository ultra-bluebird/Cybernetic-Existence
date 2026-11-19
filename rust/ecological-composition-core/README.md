# ecological-composition-core

`ecological-composition-core` provides small, deterministic Rust primitives for
evaluating whether multiple ecological model contracts may be composed under
bounded-gain, assurance-state, domain, purpose, privacy, and hard-corridor
requirements.

The crate is intended for private-use ecological research and decision support.
It does not operate, monitor, repair, calibrate, certify, protect, or control
real-world systems.

## Scope

The crate evaluates:

- Model assurance-state inheritance.
- Input-domain compatibility.
- Schema, purpose, and privacy compatibility.
- Hard-plane corridor compliance.
- Conservative normalized gain bounds.
- A sufficient row-sum condition for small-gain screening.
- Composition outcomes that preserve uncertainty and failure states.

The crate does not:

- Estimate ecological parameters.
- Infer species presence, health, identity, or eligibility.
- Establish causal relationships from model composition.
- Replace local calibration or held-out validation.
- Authorize external actions.
- Convert private self-description into a model feature or status.

## Mathematical model

For model residuals:

\[
\mathbf{V}
=
[
V_1,
V_2,
\dots,
V_n
]^\top
\]

the composition contract assumes a bounded relation:

\[
\dot{V}_i
\le
-d_iV_i
+
\sum_{j=1}^{n}
\lambda_{ij}V_j
+
u_i
\]

where:

- \(d_i > 0\) is the local dissipation margin.
- \(\lambda_{ij} \ge 0\) is an upper bound on cross-model amplification.
- \(u_i\) is external disturbance or unresolved uncertainty.

Let:

\[
D
=
\operatorname{diag}
(
d_1,
d_2,
\dots,
d_n
)
\]

and:

\[
G
=
D^{-1}\Lambda
\]

A standard small-gain target is:

\[
\rho(G)
<
1-\eta
\]

where \(\rho(G)\) is the spectral radius and \(\eta\in(0,1)\) is a required
stability margin.

This crate implements a conservative sufficient precheck:

\[
\rho(G)
\le
\lVert G\rVert_\infty
=
\max_i
\sum_jG_{ij}
\]

Therefore:

\[
\max_i
\sum_j
\frac{\lambda_{ij}}{d_i}
\le
1-\eta
\]

is sufficient for the crate to return a bounded-gain composition result.

Failure of this row-sum test means the composition is unresolved. It does not
prove the physical system is unstable.

## Decision outcomes

| Outcome | Meaning |
|---|---|
| `ExploratoryOnly` | At least one component is exploratory, preliminary, or calibrated but not independently validated for advisory use |
| `AdvisoryOnly` | Components support a bounded decision-support output but not a corridor-gated output |
| `CorridorGated` | All components are corridor-gated and composition compatibility checks pass |
| `Indeterminate` | Gain screening cannot establish the required margin |
| `Rejected` | Schema, purpose, privacy, domain, or hard-plane constraints fail; or a component is qualified, suspended, or expired |

A composed model inherits the most conservative assurance state of its
components:

\[
\operatorname{AssuranceState}
\left(
\bigcirc_i M_i
\right)
=
\min_{\preceq}
\operatorname{AssuranceState}(M_i)
\]

## Integration contract

Callers must validate and preserve the following before composition:

- Input and output schema versions.
- Units and valid ranges.
- Spatial and temporal support.
- Data class and purpose scope.
- Privacy class and disclosure restrictions.
- Evidence provenance and model version.
- Calibration, validation, and uncertainty status.
- Hard-plane corridor results.
- Gain-bound estimation method and uncertainty margin.

The `gains` array uses row-major ordering:

\[
[
\lambda_{11},
\lambda_{12},
\dots,
\lambda_{1n},
\lambda_{21},
\dots,
\lambda_{nn}
]
\]

For a two-model composition:

```text
[
  lambda_11, lambda_12,
  lambda_21, lambda_22
]
```

The row-sum bound for row \(i\) is:

\[
\sum_{j=1}^{n}
\frac{\lambda_{ij}}{d_i}
\]

## Usage

```rust
use ecological_composition_core::{
    compose,
    AssuranceState,
    CompositionInputs,
};

let decision = compose(CompositionInputs {
    residuals: &[0.12, 0.08],
    dissipation: &[1.0, 1.0],
    gains: &[
        0.10, 0.05,
        0.04, 0.12,
    ],
    model_states: &[
        AssuranceState::ValidatedAdvisory,
        AssuranceState::ValidatedAdvisory,
    ],
    schemas_compatible: true,
    purposes_compatible: true,
    privacy_compatible: true,
    all_inputs_in_domain: true,
    hard_planes_compliant: true,
    required_small_gain_margin: 0.10,
})?;

assert_eq!(
    decision,
    ecological_composition_core::CompositionDecision::AdvisoryOnly
);

# Ok::<(), ecological_composition_core::CompositionError>(())
```

## Build and test

```bash
cargo build
cargo test
```

Run linting when the repository toolchain is available:

```bash
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
```

## Assurance requirements

A caller must not interpret a successful composition result as a proof that a
real-world ecosystem, canal, watershed, sensor network, or restoration project
is safe or stable.

`CorridorGated` means only that the declared model contracts satisfy this
crate's input checks, assurance-state rules, hard-plane compliance flag, and
conservative normalized gain precheck for the supplied values.

A caller must return an indeterminate or review-required result when:

- A component is out of domain.
- Gain bounds are unavailable or not locally calibrated.
- Schema, purpose, or privacy classes do not match.
- A required hard plane fails.
- A model is qualified, suspended, or expired.
- The conservative small-gain bound fails.
- Material changes invalidate an upstream assurance record.
- Input units, time support, spatial support, or provenance are unclear.

## Security and privacy

- Validate all values as finite and within declared ranges before use.
- Keep sensitive observations and precise ecological locations outside this
  crate's public composition inputs.
- Do not include household telemetry, individual identity data, private device
  data, health data, or inferred demographic attributes.
- Use only declared, purpose-compatible, privacy-compatible model contracts.
- Preserve evidence provenance and material-change records in the repository's
  SQL evidence ledger.
- Treat all external model outputs, files, URLs, and metadata as untrusted
  until independently validated.

## License

Licensed under either of:

- MIT License
- Apache License, Version 2.0

at the user's option.
