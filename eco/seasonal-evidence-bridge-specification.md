# Seasonal Evidence Bridge with Rights-Gated Release

## Build summary

A testable coupled specification in which continuous ecological dynamics produce evidence, while a separate governance state machine determines what that evidence supports and which actions are authorized.

## Status and scope

This document specifies research behavior and acceptance requirements. It does not claim that implementation code has been completed, numerical experiments have been run, or Phoenix-specific ecological outcomes have been established.

Synthetic examples, literature-derived parameters, fitted parameters, and observations must remain distinguishable throughout the workflow.

The system has two connected but distinct layers:

1. An ecological layer modeling exposure, resources, interactions, and recovery.
2. A governance layer evaluating evidence, accessibility, privacy, and permission.

Their connection is an evidence package—not a shared ranking of ecosystems and people.

## 1. Two-layer architecture

Represent ecological dynamics, observations, and governance transitions separately:

\[
\frac{d\mathbf z}{dt}
=
f\!\left(\mathbf z(t),\mathbf u(t),\boldsymbol\theta(t)\right),
\]

\[
\mathbf y_k
\sim
p\!\left(
\mathbf y_k
\mid
\mathbf z(t_k),\boldsymbol\psi,\mathcal E_k
\right),
\]

\[
r_{n+1}
=
\delta\!\left(r_n,\mathcal V_n,\mathcal A_n\right).
\]

Definitions:

- \(\mathbf z\): ecological states.
- \(\mathbf u\): environmental forcing.
- \(\boldsymbol\theta\): ecological parameters.
- \(\mathbf y_k\): observations.
- \(\boldsymbol\psi\): observation-error and detectability parameters.
- \(\mathcal E_k\): survey effort.
- \(r_n\): research-workflow state.
- \(\mathcal V_n\): validation and review findings.
- \(\mathcal A_n\): action-specific authorization.

The governance transition \(\delta\) does not modify organism physiology, authenticate a person's identity, or determine entitlement to assistance. It determines the permitted use of a research result.

The architecture is a hybrid system: continuous ecological dynamics operate alongside discrete review and authorization transitions.

### Operating principles

- Preserve distinctions between physical cooling, exposure-memory decay, resource renewal, population recovery, and observation probability.
- Retain evidence classes through every transformation and released claim.
- Preserve ecological state across seasonal transitions.
- Block consequential external effects when authority is missing or unresolved.
- Keep explanation, correction, appeal, and appropriately labeled local exploration accessible.
- Do not require identity, neural, medical, biometric, or private companion-system information for ecological analysis or ordinary access.
- Preserve accessibility supports during blinded review.
- Keep scientific confidence separate from permission to act.
- Treat CyberRank as private, voluntary project vocabulary and governance context—not a public ranking, diagnosis, eligibility test, or certification.

## 2. Seasonal interpolation without ecological resets

Define smooth seasonal weights:

\[
w_s(t)=
\frac{
1+\cos\!\left(2\pi[d(t)-d_s]/Y\right)
}{2},
\qquad
w_w(t)=1-w_s(t).
\]

Here:

- \(d(t)\): fractional day-of-year.
- \(Y\): year length in days.
- \(d_s\): fitted center of the warm-season regime.

These weights describe seasonal position. They are not weather observations or proof of a sinusoidal biological response.

For positive parameter values:

\[
\theta(t)
=
\theta_s^{\,w_s(t)}
\theta_w^{\,w_w(t)}.
\]

For dimensional clarity, use a reference quantity with the same units:

\[
\theta(t)
=
\theta_{\mathrm{ref}}
\exp\left[
w_s(t)\ln\frac{\theta_s}{\theta_{\mathrm{ref}}}
+
w_w(t)\ln\frac{\theta_w}{\theta_{\mathrm{ref}}}
\right].
\]

The logarithms operate on dimensionless ratios.

Use seasonal interpolation only where parameter variation has an empirical or explicitly hypothesized biological basis. Do not alter fixed traits merely to obtain a desired outcome.

Measured weather remains the preferred environmental forcing.

### Optional acclimation state

Calendar position and response to recent conditions are different mechanisms.

Where delayed adjustment is justified, introduce:

\[
\frac{da_i}{dt}
=
\frac{a_i^\star(t)-a_i(t)}{\tau_{a,i}},
\]

where:

- \(a_i^\star\): hypothesized target acclimation state.
- \(\tau_{a,i}>0\): adjustment time.
- \(a_i\): acclimation state.

A candidate parameter coupling is:

\[
T_{H,i}(t)
=
T_{H,i}^{\mathrm{base}}
+
\beta_i a_i(t).
\]

This is an optional research hypothesis, not an established physiological law.

At seasonal boundaries:

\[
\mathbf z(t^+)=\mathbf z(t^-),
\]

unless a separately documented event introduces a real discontinuity.

A change of month must not restore resources, erase disturbance memory, or replenish populations.

## 3. Environmental exposure and recovery

Keep wet-bulb temperature separate from organism-level thermal exposure:

\[
T_w(t)
=
\mathcal P[T_a(t),q(t),p(t)],
\]

\[
T_{e,i}(t)
=
\mathcal M_i[
T_a(t),T_r(t),u(t),q(t),
\text{habitat},\text{traits}
].
\]

Each performance curve must declare its temperature variable.

### Urban thermal anomaly

For a consistently defined temperature quantity:

\[
A(t)
=
T_{\mathrm{urban}}(t)
-
T_{\mathrm{reference}}(t),
\]

\[
\frac{dA}{dt}
=
-\frac{A}{\tau_U}
+
F_A(t).
\]

Definitions:

- \(\tau_U>0\): urban-anomaly relaxation time, hours.
- \(F_A\): unresolved or modeled forcing, degrees Celsius per hour.

Surface-temperature and air-temperature anomalies must remain separate unless an explicit observation model connects them.

### Heat and cold closure

\[
b_{H,i}(t)
=
\frac{1}{
1+\exp[-k_{H,i}(T_{e,i}(t)-T_{H,i}(t))]
},
\]

\[
b_{C,i}(t)
=
\frac{1}{
1+\exp[k_{C,i}(T_{e,i}(t)-T_{C,i}(t))]
}.
\]

Define thermal opportunity:

\[
g_{T,i}(t)
=
[1-b_{H,i}(t)]
[1-b_{C,i}(t)].
\]

These functions are model scores unless calibrated as probabilities.

### Exposure memory

\[
q_{H,i}(t)
=
\max[0,T_{e,i}(t)-T_{H,i}(t)],
\]

\[
\frac{dD_i}{dt}
=
q_{H,i}(t)
-
\frac{D_i(t)}{\tau_{D,i}}.
\]

With time in hours:

- \(q_{H,i}\): degrees Celsius of exceedance.
- \(D_i\): degree-hours.
- \(\tau_{D,i}>0\): exposure-memory decay time, hours.

Urban cooling time \(\tau_U\) and exposure-memory decay time \(\tau_{D,i}\) are separate parameters.

For piecewise-constant exceedance:

\[
D_{i,n+1}
=
D_{i,n}e^{-\Delta t/\tau_{D,i}}
+
q_{H,i,n}\tau_{D,i}
\left(
1-e^{-\Delta t/\tau_{D,i}}
\right).
\]

Use this exact update as a reference test for numerical implementations.

### Recovery-window calculation

After an adverse event ends, suppose \(q_{H,i}=0\):

\[
D_i(t_0+h)
=
D_i(t_0)e^{-h/\tau_{D,i}}.
\]

For \(D_i(t_0)>D_{\mathrm{target}}>0\):

\[
h_{\mathrm{clear},i}
=
\tau_{D,i}
\ln\left(
\frac{D_i(t_0)}{D_{\mathrm{target}}}
\right).
\]

If \(D_i(t_0)\le D_{\mathrm{target}}\), the required duration is zero.

Compare available suitable hours with \(h_{\mathrm{clear},i}\).

The target level must be labeled as fitted, operationally defined, or synthetic—not presented as a universal biological threshold.

Environmental cooling does not automatically restore depleted resources, reduced populations, or interaction opportunity.

## 4. Interaction opportunity and lighting

Define:

\[
g_{ij}(t)
=
g_{\mathrm{phen},ij}(t)
\sqrt{g_{T,i}(t)g_{T,j}(t)}
g_{L,i}(t)g_{L,j}(t).
\]

Here:

- \(g_{\mathrm{phen},ij}\in[0,1]\): phenological overlap.
- \(g_{L,i}\in[0,1]\): usable opportunity under modeled lighting conditions.

Keep lighting and thermal exposure as separate inputs. Do not convert lux directly into temperature.

Record lighting spectrum, intensity, timing, direction, and measurement support where available.

### Test the lighting aggregation rule

If both partners receive the same factor:

\[
g_{L,i}g_{L,j}=g_L^2.
\]

This may represent two distinct constraints, or it may double-count a shared limitation.

Compare candidate hypotheses:

\[
g_{L,ij}^{\mathrm{product}}
=
g_{L,i}g_{L,j},
\]

\[
g_{L,ij}^{\mathrm{bottleneck}}
=
\min(g_{L,i},g_{L,j}),
\]

or:

\[
g_{L,ij}
=
\mathcal L_{ij}
(
\text{spectrum},
\text{intensity},
\text{timing},
\text{habitat}
).
\]

Document the selected rule and its uncertainty.

### Separate suitability from attraction and redistribution

A factor in \([0,1]\) cannot represent an increase above reference opportunity.

Where spatial redistribution is relevant:

\[
c_{ij}(x,t)
=
c_{ij,0}
g_{ij}(x,t)
\omega_{ij}(x,t),
\]

where \(\omega_{ij}\ge0\) describes relative encounter overlap and may exceed one.

An increase in local encounters must not be interpreted automatically as improved survival, reproduction, or habitat quality.

Define usable interaction hours:

\[
U_{ij}
=
\int_{t_0}^{t_1}
g_{ij}(t)\,dt.
\]

## 5. Resource–pollinator–consumer dynamics

Define:

\[
\mathbf x
=
\begin{bmatrix}
F\\L\\B
\end{bmatrix},
\]

where:

- \(F\): accessible floral or equivalent food resource.
- \(L\): focal pollinator or prey population.
- \(B\): focal consumer population.

Use consumption fluxes:

\[
J_{FL}
=
c_{FL}(t)FL,
\]

\[
J_{LB}
=
c_{LB}(t)LB.
\]

The reduced dynamics are:

\[
\frac{dF}{dt}
=
\Phi-\delta_FF-J_{FL},
\]

\[
\frac{dL}{dt}
=
e_LJ_{FL}
-
m_LL
-
d_LL^2
-
J_{LB},
\]

\[
\frac{dB}{dt}
=
e_BJ_{LB}
+
(s_B-m_B)B
-
d_BB^2.
\]

Use:

\[
m_i(t)
=
m_{0,i}(t)
+
\alpha_iD_i(t).
\]

This mortality coupling is a declared reduced hypothesis, not a fitted law.

### Parameter constraints and units

| Parameter | Constraint | Meaning and units |
|---|---|---|
| \(\Phi\) | Nonnegative | Resource production, resource units/hour |
| \(\delta_F\) | Nonnegative | Resource loss rate, 1/hour |
| \(c_{FL}\) | Nonnegative | Resource-consumption coefficient, 1/(pollinator units × hour) |
| \(c_{LB}\) | Nonnegative | Predation coefficient, 1/(consumer units × hour) |
| \(e_L\) | Nonnegative | Pollinator units gained/resource unit consumed |
| \(e_B\) | Nonnegative | Consumer units gained/pollinator unit consumed |
| \(d_L\) | Nonnegative | Self-regulation, 1/(pollinator units × hour) |
| \(d_B\) | Nonnegative | Self-regulation, 1/(consumer units × hour) |
| \(m_{0,i}\) | Nonnegative | Baseline loss rate, 1/hour |
| \(\alpha_i\) | Nonnegative | Exposure-memory loss coefficient, 1/(degree-hour × hour) |
| \(s_B\) | Nonnegative | Alternative-resource growth contribution, 1/hour |

Every parameter requires provenance and an uncertainty description.

The paired resource losses and consumer gains are conversion-consistent fluxes. They are not necessarily a closed mass balance when units differ or respiration, waste, and external inputs are omitted.

Standing plant biomass, recruitment, and pollination feedback are outside this reduced state. Add them explicitly before making claims about plant reproduction or vegetation recovery.

### Nonnegativity

At the boundaries:

\[
\left.
\frac{dF}{dt}
\right|_{F=0}
=
\Phi\ge0,
\]

\[
\left.
\frac{dL}{dt}
\right|_{L=0}
=
0,
\]

\[
\left.
\frac{dB}{dt}
\right|_{B=0}
=
0.
\]

With nonnegative inputs and suitable regularity, the continuous equations preserve nonnegative states.

Numerical implementations must test this property. Do not silently clip negative solver outputs.

The reduced model cannot recolonize a population once it reaches exactly zero. Corridor or recolonization research requires explicit immigration, dispersal, or recruitment.

## 6. Interaction disturbance and local stability

The interaction matrix is:

\[
\mathbf A(t)
=
\begin{bmatrix}
0 & -c_{FL}(t) & 0\\
e_Lc_{FL}(t) & -d_L & -c_{LB}(t)\\
0 & e_Bc_{LB}(t) & -d_B
\end{bmatrix}.
\]

Define disturbance relative to a declared reference:

\[
\Delta\mathbf A(t)
=
\mathbf A(t)
-
\mathbf A_{\mathrm{reference}}(t).
\]

This measures coefficient changes. It is not the full local stability matrix or an extinction probability.

For fixed environmental and memory states:

\[
\mathbf f(\mathbf x)
=
\mathbf b
+
\operatorname{diag}(\mathbf x)
\left(
\mathbf v+\mathbf A\mathbf x
\right),
\]

where:

\[
\mathbf b
=
\begin{bmatrix}
\Phi\\0\\0
\end{bmatrix},
\qquad
\mathbf v
=
\begin{bmatrix}
-\delta_F\\
-m_L\\
s_B-m_B
\end{bmatrix}.
\]

The Jacobian is:

\[
\mathbf J
=
\operatorname{diag}
\left(
\mathbf v+\mathbf A\mathbf x
\right)
+
\operatorname{diag}(\mathbf x)\mathbf A.
\]

If mortality depends on exposure memory, include the corresponding derivatives in the augmented Jacobian.

Interpretation requirements:

- Coefficient changes alone do not determine stability.
- Stability depends on the current ecological state.
- Seasonal forcing makes the system time-dependent.
- One matrix norm does not characterize ecological recovery.
- Instantaneous eigenvalues are local diagnostics, not standalone extinction evidence.

Compare complete trajectories, resource deficits, interaction opportunity, and recovery durations.

## 7. Identifiability and model complexity

For constant excess exposure \(q_0\) and \(D(0)=0\):

\[
D(t)
=
q_0\tau_D
\left(
1-e^{-t/\tau_D}
\right).
\]

The added mortality is:

\[
m(t)-m_0
=
\alpha q_0\tau_D
\left(
1-e^{-t/\tau_D}
\right).
\]

At long duration:

\[
m-m_0
\rightarrow
\alpha q_0\tau_D.
\]

Long-exposure observations emphasize the product \(\alpha\tau_D\). They may not separate strong effects with rapid recovery from weaker effects with persistent memory.

After forcing ends:

\[
m(t)-m_0
=
\alpha D(t_0)
e^{-(t-t_0)/\tau_D}.
\]

Recovery observations provide information about the decay timescale.

### Observation priorities

Include:

- Exposure onset.
- Repeated adverse nights.
- Cooling transitions.
- Resource recovery.
- Return of interaction activity.
- Survey effort and detection conditions.

### Model ladder

1. Seasonal resources and observation error.
2. Add thermal opportunity.
3. Add exposure memory.
4. Add lighting and spatial overlap.
5. Add dispersal or acclimation only when supported.

Additional parameters must be justified through predictive performance, interpretable uncertainty, and identifiable mechanisms.

## 8. Evidence contract and ingestion

Each evidence package must retain:

- Intended claim and use.
- Input evidence classes.
- Source and permission information.
- Units and measurement support.
- Original timestamps and timezone conventions.
- Quality flags and missingness.
- Transformation history.
- Model equations and parameter provenance.
- Solver settings and reproducibility information.
- Uncertainty and sensitivity results.
- Review findings and unresolved issues.
- Retention and deletion decisions.
- Release restrictions.
- Any action-specific approval.

Raw observations remain unchanged. Corrections and derived values are separate records.

### Validation behavior

| Stage | Required check | Failure behavior |
|---|---|---|
| Intake | Explicit local selection, permission, sensitivity | No automatic fetch or export |
| Schema | Fields, types, units, evidence classes | Field-specific accessible explanation |
| Time | Timezone, duplicates, gaps, ordering | No silent assumptions or interpolation |
| Physical validity | Impossible values versus unusual valid extremes | Reject impossible values; preserve extremes for review |
| Harmonization | Approved conversions and temporal alignment | Record transformations |
| Spatial support | Height, footprint, native resolution | No implied finer observational detail |
| Model readiness | Units, forcing coverage, parameter constraints | Block unsupported numerical release |
| Review | Assumptions, uncertainty, evidence classes | Preserve unresolved issues |
| Release | Claim-specific rights and accessibility checks | Remain local until requirements pass |

## 9. Claim-specific release eligibility

Evaluate a proposed claim and use:

\[
G_{\mathrm{local}}(E,c,u)
=
G_{\mathrm{data}}
\land
G_{\mathrm{model}}
\land
G_{\mathrm{provenance}}
\land
G_{\mathrm{rights}}
\land
G_{\mathrm{access}},
\]

where:

- \(E\): evidence package.
- \(c\): proposed claim.
- \(u\): intended use.

| Proposed claim or use | Required disposition |
|---|---|
| Synthetic demonstration of solver behavior | Reproducibility and labeling checks |
| Estimate for a measured site | Site-relevant inputs and validation |
| Predicted reduction in local extinction risk | Stronger outcome evidence and uncertainty evaluation |
| Publication of precise sensitive habitat locations | Separate disclosure review and approval |

Use three review outcomes:

\[
G_k
\in
\{
\text{pass},
\text{fail},
\text{unresolved}
\}.
\]

Both failure and unresolved evidence block the relevant release or action.

- Failure: a requirement was evaluated and not satisfied.
- Unresolved: the requirement has not been adequately evaluated.

Neither outcome blocks accessible explanation, correction, appeal, or appropriately labeled local exploration.

## 10. External-action authorization

Represent the proposed action by:

\[
a
=
(
\text{operation},
\text{target},
\text{payload},
\text{scope}
).
\]

Authorization binds to the exact action and reviewed release candidate:

\[
G_{\mathrm{external}}
=
G_{\mathrm{local}}
\land
G_{\mathrm{approval}}(a,E).
\]

Requirements:

1. Changed target, content, scope, or reviewed evidence requires fresh authorization.
2. Approval is consumed once for the authorized operation.
3. Denial or cancellation produces no external effect.
4. A timeout with uncertain execution status enters reconciliation, not automatic repeated execution.
5. Audit records retain only what is necessary for accountability.
6. Research components cannot command hardware or private systems.

Scientific confidence does not create permission to act. Permission to act does not establish scientific validity.

### Local workflow

| State | Event or finding | Next state |
|---|---|---|
| Draft | Local inputs submitted | Validating |
| Validating | Correctable failure | Correction required |
| Correction required | Revision supplied | Validating |
| Validating | Checks pass | Modeling |
| Modeling | Numerical or specification failure | Correction required |
| Modeling | Evidence package complete | Blinded review |
| Blinded review | Unresolved findings | Human review |
| Blinded review | Findings complete | Rights/access review |
| Human review | Resolution documented | Rights/access review |
| Rights/access review | Requirements fail or remain unresolved | Correction or further review |
| Rights/access review | Claim-specific requirements pass | Local release candidate |
| Local release candidate | Exact external action requested | Awaiting approval |
| Awaiting approval | Denied or cancelled | Local release candidate |
| Awaiting approval | Exact action approved | Approved action |
| Approved action | Successful execution | Action completed |
| Approved action | Execution status uncertain | Reconciliation |
| Approved action | Action or reviewed evidence changes | Awaiting approval |

This specifies behavior; it is not a claim of completed implementation.

## 11. Rights, privacy, and access requirements

| Requirement | Acceptance condition |
|---|---|
| Equal access | Assistance does not depend on identity verification or private CyberRank disclosure |
| Data minimization | Every collected field has a stated analytical purpose |
| Purpose limitation | Reuse matches permission and declared purpose |
| Non-interference | No operational control of hardware or private systems |
| Correction | Reasons are inspectable and revisions can be submitted |
| External approval | Exact target, content, scope, and reviewed evidence match authorization |
| Habitat protection | Public outputs omit unnecessary sensitive location detail |
| Access equivalence | Alternative communication formats do not reduce eligibility |
| Retention | Each data class has retention and deletion rules |

These are project governance requirements, not declarations of legal compliance or institutional certification.

## 12. Accessibility and masking

Target WCAG 2.2 Level AA for an eventual web interface.

WCAG 2.2 includes requirements for keyboard operation, focus behavior, error identification, and status messages. A selected checklist is not a complete conformance determination. [85]

### Separate masking integrity from access equivalence

Evaluate both:

\[
\text{masking integrity}
\quad\text{and}\quad
\text{access equivalence}.
\]

Remove irrelevant attribution cues without removing supports needed to understand or submit evidence.

Retain accessible table explanations, communication supports, units, uncertainty, and scientific context.

### Acceptance tests

| Behavior | Criterion | Test |
|---|---|---|
| Keyboard operation | 2.1.1 | Complete workflows without a pointer |
| No keyboard trap | 2.1.2 | Enter and leave all interactive components |
| Meaningful focus order | 2.4.3 | Check navigation against reading and action order |
| Visible focus | 2.4.7 | Inspect each interactive control |
| Focus not entirely hidden | 2.4.11 | Test overlays, notices, and sticky panels |
| Text error descriptions | 3.3.1 | Submit malformed units, fields, and timestamps |
| Programmatic status messages | 4.1.3 | Test validation and review announcements |

For criterion 2.4.11, the focused component must not be entirely hidden by author-created content. Avoiding all obscuration is a stronger target than this minimum AA requirement. [83]

Qualifying status messages must be available to assistive technology without requiring focus to move to them. [100]

Test the entire correction and approval workflow, not only the initial submission screen.

## 13. Blinded review study

Research question:

Does structured evidence-and-rights review improve research triage compared with an unstructured workflow?

### Design requirements

- Review research packages, not people.
- Prespecify the rubric, material-error definition, and analysis.
- Remove irrelevant attribution and prestige cues where feasible.
- Preserve scientific context and accessibility supports.
- Allocate packages reproducibly.
- Record conflicts, incomplete masking, and prior exposure.
- Preserve independent ratings before adjudication.
- Document disagreement and unresolved cases.
- Provide accessible correction routes.

### Outcomes

Primary:

\[
\Delta_e
=
e_S-e_C,
\]

where \(e_S\) and \(e_C\) are material review-error proportions under structured and comparator workflows.

Negative values favor the structured workflow.

Keep error classes distinguishable:

\[
\mathbf e
=
\begin{bmatrix}
e_{\mathrm{scientific}}\\
e_{\mathrm{provenance}}\\
e_{\mathrm{privacy}}\\
e_{\mathrm{access}}\\
e_{\mathrm{authorization}}
\end{bmatrix}.
\]

A reduction in one error class must not conceal increased disclosure pressure or accessibility failures.

For repeated reviewers and packages, a candidate model is:

\[
\operatorname{logit}
\Pr(E_{pr}=1)
=
\beta_0
+
\beta_1 I_{\mathrm{structured}}
+
u_p+v_r,
\]

where:

- \(u_p\): package variation.
- \(v_r\): reviewer variation.

Choose the final analysis and sample size after defining target effects, baseline error rates, clustering assumptions, and desired precision.

An adjudicated reference is a documented evaluation standard, not unquestionable ground truth.

## 14. Validation and reproducibility gates

Before numerical release:

1. Publish equations, units, initial conditions, parameters, forcing, and solver settings.
2. Label every input as observed, fitted, literature-derived, or synthetic.
3. Verify zero-forcing exposure-memory decay.
4. Compare numerical memory integration with the exact update.
5. Test nonnegative states without silent clipping.
6. Check paired resource-loss and consumer-gain fluxes.
7. Test timestep and solver-tolerance convergence.
8. Preserve seasonal continuity.
9. Evaluate parameter identifiability.
10. Compare the model ladder using held-out observations where available.
11. Separate observation error from ecological change.
12. Report uncertainty in both parameters and derived outputs.
13. Define functional-extinction conventions before analysis.
14. Test privacy, accessibility, approval, and non-interference independently.
15. Record unresolved limitations in the release package.

## 15. Next implementation release

The next local implementation should contain four independently testable components:

| Component | Required demonstration |
|---|---|
| Ecological solver | Continuous seasonal state, exact memory updates, nonnegative trajectories, convergence |
| Observation layer | Explicit survey effort, missingness, and detection assumptions |
| Evidence contract | Preserved evidence classes, units, transformations, uncertainty, and claim limitations |
| Governance engine | Claim-specific checks, accessible correction, exact-action approval, uncertain-execution reconciliation |

The first scientific question is:

> Under explicitly synthetic forcing, when do additional thermally suitable night-time hours restore interaction opportunity, and when do resource depletion or exposure memory prevent that restoration?

The initial implementation should demonstrate behavior and reproducibility. Phoenix-specific predictive claims require local calibration and independent validation.

## 16. Provisional design assessment

These are qualitative specification assessments, not calibrated probabilities, implementation test results, or measured ecological outcomes.

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.87 | Explicit dynamics, units, identifiability analysis, and accessibility requirements; empirical calibration remains outstanding |
| eco_impact_value | 0.68 | Supports recovery-window and intervention comparisons; field benefit has not been demonstrated |
| harm_risk | 0.13 | Local-first analysis and claim-specific authorization reduce exposure; operational deployment remains outside scope |
| accessibility_impact | 0.92 | Correction, masking, status updates, and approval are treated as complete accessible workflows |
| rights_alignment | 0.97 | Scientific review is separate from identity legitimacy, service entitlement, and private-system disclosure |

## Conclusion

The framework explains not only where interactions become constrained, but why they can remain constrained after weather improves.

Its central contribution is traceability:

\[
\text{input}
\rightarrow
\text{transformation}
\rightarrow
\text{assumption}
\rightarrow
\text{result}
\rightarrow
\text{review}
\rightarrow
\text{permitted use}.
\]

Every released claim retains its evidence class. Every consequential external action requires specific approval. Neither requirement becomes a test of a person's identity legitimacy or entitlement to assistance.
