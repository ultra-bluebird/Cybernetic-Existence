# Domain Evidence Matrix Template

## Scope

This template defines the minimum metadata required before an input is used in a shade, water, or green-infrastructure formula.

A record meeting a source-class requirement is not automatically fit for use. It must also satisfy unit, provenance, freshness, calibration, uncertainty, privacy, accessibility, and purpose-compatibility requirements.

## Required matrix columns

| Input variable | Definition | Unit | Permitted source classes | Minimum quality threshold | Provenance requirements | Freshness behavior | Calibration status | Spatial compatibility | Temporal compatibility | Missing-value behavior | Zero-quality behavior | Uncertainty method | Active-use status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `example_input` | Plain-language definition | Declared SI or domain unit | Controlled source-class list | Documented value in the canonical registry | Creator, collection method, collection time, transformation history, license or authority, purpose | Explicit decay or expiry rule | `calibrated`, `not_calibrated`, `not_applicable`, or `unknown` | Declared CRS, resolution, and spatial-match rule | Observation interval and permitted time mismatch | `insufficient_evidence` | `insufficient_evidence` | Declared interval, distributional, scenario, or qualitative method | `eligible`, `needs_review`, or `blocked` |

## Universal evidence rules

- Missing required input: `insufficient_evidence`.
- Zero-quality input: `insufficient_evidence`.
- Unknown provenance for a required input: `needs_review` or `insufficient_evidence`, according to the metric registry.
- Expired calibration for a calibration-dependent input: `needs_review` or `insufficient_evidence`.
- Unit mismatch: `blocked` until a documented, lossless conversion is completed.
- Spatial or temporal incompatibility: `blocked` unless an approved uncertainty adjustment and compatibility rule applies.
- Conflicting protected records: `preserve_both_require_review`.
- Sensitive raw records: remain local-only unless a purpose-specific approved release class permits otherwise.

## Freshness model

For an input with elapsed age \( t \), documented validity interval \( T \), and domain-specific decay parameter \( \lambda \), report freshness separately from source quality:

\[
f(t) =
\begin{cases}
1 & \text{when } t \leq T \\
\exp(-\lambda(t - T)) & \text{when } t > T
\end{cases}
\]

The system must retain the original age, validity interval, and decay parameter. It must not replace freshness with a hidden composite score.

A freshness function does not make expired information current. If a required input reaches a metric-specific minimum freshness boundary, active use becomes `needs_review` or `insufficient_evidence`.
