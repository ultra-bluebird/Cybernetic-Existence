# Biosemiotic Communication Channel Framework

## Purpose

This framework defines an information-theoretic and context-aware method for
studying ecological signals, cues, receiver responses, communication
reliability, and functional consequences.

It does not attribute human-like language, consciousness, intention, or moral
status to organisms or ecosystems. It does not use communication metrics for
human, community, landholder, species-worth, eligibility, or enforcement
ranking.

## Channel Model

\[
M
\rightarrow
X
\rightarrow
\widetilde X
\rightarrow
Y
\rightarrow
A
\rightarrow
F.
\]

Where:

- `M` is a documented sender or environmental state;
- `X` is emitted signal or cue;
- `X_tilde` is the signal after transport and noise;
- `Y` is receiver detection or response;
- `A` is receiver action;
- `F` is a documented ecological consequence.

Every study must define which links are directly observed and which are
modeled or inferred.

## Observed Information Transfer

\[
I_{\mathrm{obs}}(X;Y)
=
\sum_{x,y}
p(x,y)
\log_2
\frac{p(x,y)}{p(x)p(y)}.
\]

This measures observed statistical dependence between signal and receiver
response under an observed input distribution.

## Channel Capacity

\[
C_{X\to Y}
=
\max_{p(x)}
I(X;Y).
\]

Capacity is a theoretical maximum under a specified channel model. Do not
equate it with observed information transfer or claim near-capacity operation
without explicit channel estimation, uncertainty analysis, and replication.

## Context-Conditioned Communication

\[
I(X;Y\mid E,R,d,t).
\]

Where:

- `E` is environmental context;
- `R` is receiver condition;
- `d` is distance or transport context;
- `t` is temporal or phenological context.

All conditioning variables must be documented before analysis.

## Sender-State Information

\[
I(M;Y\mid Z).
\]

Use this quantity when the question concerns whether receiver behavior carries
information about sender condition or environmental state.

## Directed Predictive Information

\[
TE_{X\to Y}
=
I
\left(
X_t^{(k)};
Y_{t+1}
\mid
Y_t^{(\ell)}
\right).
\]

Transfer entropy is a directed predictive-dependence measure. It is not
causality proof and must be evaluated against shared-driver and sampling null
models.

## Signal Classification

Classify every studied interaction as one of:

- environmental_cue;
- signal_candidate;
- biological_signal;
- unresolved.

A biological-signal claim requires documented evolutionary and functional
evidence beyond statistical association.

## Communication-Change Comparison

For a declared reference and changed context:

\[
\Delta I
=
I(X;Y\mid Z,\text{reference})
-
I(X;Y\mid Z,\text{changed context}).
\]

A decrease in information transfer is a candidate reliability change. It does
not alone establish degradation or functional loss.

## Required Validation

- Compare against shuffled, surrogate, and shared-driver null models.
- Report sample size, estimator, binning or embedding, time resolution, and
  uncertainty.
- Test sensitivity to signal prevalence and receiver abundance.
- Measure or justify relevant transport noise and spatial context.
- Link communication metrics to a documented ecological outcome before making
  functional claims.
- Publish negative and mixed results.

## Governance Requirements

- Use minimum necessary ecological data.
- Exclude personal, household, biometric, medical, assistive-technology,
  neural, and identity data.
- Protect sensitive habitat and species-location information.
- Keep outputs as research and stewardship decision support.
- Require ecological and community review before external decision use.
