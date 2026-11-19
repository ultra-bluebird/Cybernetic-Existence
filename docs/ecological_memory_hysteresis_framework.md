# Ecological Memory and Hysteresis Framework

## Purpose

This framework defines a reproducible approach for studying path dependence,
legacy effects, hysteresis, recovery, and operational reversibility in
ecological systems.

It does not establish a universal definition of ecological irreversibility,
ecosystem health, restoration success, or conservation priority.

## State-Dependent Memory Model

\[
\frac{dx}{dt}
=
f(x(t),u(t),\varepsilon(t)).
\]

\[
\varepsilon(t)
=
\int_0^\infty
K(s)g(x(t-s),u(t-s))\,ds.
\]

Where:

- `x(t)` is a documented ecosystem-state vector;
- `u(t)` is an external forcing variable or forcing vector;
- `K(s)` is the memory kernel;
- `g(...)` maps prior state and forcing into a memory-relevant modifier;
- `ε(t)` is a history-dependent ecological feedback variable.

## Required Kernel Properties

Every kernel specification must document:

- sign behavior;
- normalization or amplitude convention;
- support or tail behavior;
- time unit;
- estimation method;
- uncertainty treatment;
- ecological mechanism represented;
- identifiability limitations.

Do not infer a kernel solely from an observed lag without documenting
alternative mechanisms such as unmeasured forcing, dispersal delay, slow state
variables, observation delay, or structural model error.

## Effective Memory Horizon

For a nonnegative normalized kernel:

\[
K(s)\ge0,
\qquad
\int_0^\infty K(s)\,ds=1.
\]

Define retained-memory mass:

\[
M(T)
=
\int_T^\infty K(s)\,ds.
\]

For tolerance \(0<\delta<1\):

\[
T_{\mathrm{mem}}(\delta)
=
\inf
\left\{
T\ge0:
M(T)\le\delta
\right\}.
\]

`T_mem(δ)` is an effective memory horizon. It is not automatically a recovery
time or a hysteresis length.

## Hysteresis Measurement

For a documented forward and reverse forcing protocol:

\[
A_{\mathrm{hys}}
=
\int_{u_{\min}}^{u_{\max}}
\left\|
x_\uparrow(u)
-
x_\downarrow(u)
\right\|_W\,du.
\]

The weighted state norm and forcing protocol must be published with every
reported hysteresis value.

A nonzero hysteresis area indicates path dependence for the specified model,
forcing cycle, state representation, and observation window. It does not by
itself prove permanent or universal irreversibility.

## Operational Reversibility

With reference state \(x_{\mathrm{ref}}\), reversal time \(t_r\), tolerance
\(\eta\), and observation horizon \(T\), recovery is observed when:

\[
\exists t\in[t_r,t_r+T]:
\left\|
x(t)-x_{\mathrm{ref}}
\right\|_W
\le\eta.
\]

For sustained recovery:

\[
\sup_{s\in[t,t+\Delta]}
\left\|
x(s)-x_{\mathrm{ref}}
\right\|_W
\le\eta.
\]

Claims of irreversibility must specify the forcing protocol, reference state,
measurement uncertainty, spatial boundary, observation horizon, and recovery
criterion.

## Required Competing Explanations

Every memory or hysteresis analysis must assess whether observed path
dependence could instead arise from:

- unobserved or incompletely reversed forcing;
- multiple locally stable states;
- slow unmeasured state variables;
- spatial dispersal limitation;
- seasonal or phenological mismatch;
- observation lag;
- data aggregation;
- sampling bias;
- structural model misspecification.

## Governance Requirements

- Use minimum necessary ecological data.
- Protect sensitive habitat-location information.
- Do not use recovery or irreversibility metrics to rank communities,
  landholders, people, or access to services.
- Do not treat modelled persistence as proof of ecosystem value.
- Require ecological and community review before external decision use.
- Publish uncertainty, negative findings, and alternative explanations.
