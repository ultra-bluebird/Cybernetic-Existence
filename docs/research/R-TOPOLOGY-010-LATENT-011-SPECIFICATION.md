# Dynamic Topology and Latent Intent Research Specification

Document Ref: RES-TOPOLOGY-LATENT-010-011-2026-REV1  
Classification: Institutionally Managed / De-identified Research Specification  
Scope: Dynamic graph representation, inverse-problem methodology, and latent-dynamics evaluation

## 10 — Dynamic Topology Tracking with GNN

### Objective

Represent changing relationships among authorized, de-identified channel summaries as a temporal graph. The research object supports analysis of changing correlations, signal-quality relationships, and model-relevant topology without assuming static placement, fixed adjacency, or access to raw protected telemetry.

### Scope boundary

This object uses only authorized aggregate or de-identified channel summaries. It does not collect, infer, publish, or validate a person's medical, neural, biometric, identity, anatomy, or augmentation information.

### Dynamic graph model

At each observation window \(t\), define:

\[
G_t = (V_t,E_t,X_t)
\]

where:

- \(V_t\) is the set of authorized channel identifiers available at time \(t\).
- \(E_t\) is the set of weighted relationships between channels.
- \(X_t\) is the matrix of de-identified node features.

An edge weight may represent spatial correlation, temporal co-activation, feature similarity, signal-quality similarity, or an explicitly documented hybrid relation:

\[
w_{ij,t} \in [0,1]
\]

The adjacency matrix is:

\[
A_t = [w_{ij,t}]
\]

No edge is interpreted as physical proximity unless that interpretation is explicitly supported by an authorized system reference.

### Edge-construction policies

| Edge mode | Construction | Suitable research purpose |
|---|---|---|
| Spatial correlation | \(w_{ij,t}=|\operatorname{corr}(x_{i,t},x_{j,t})|\) | Relationship monitoring among time-aligned channel summaries |
| Feature similarity | \(w_{ij,t}=\exp(-\lVert x_{i,t}-x_{j,t}\rVert^2/\sigma^2)\) | Feature-cluster stability and graph embedding |
| Hybrid | \(w_{ij,t}=\alpha w_{\mathrm{correlation}}+(1-\alpha)w_{\mathrm{similarity}}\) | Joint monitoring when a locked policy defines \(\alpha\) |

All graph-construction parameters, including correlation window, missing-data treatment, thresholds, and \(\sigma\), must be recorded in the provenance manifest before results are interpreted.

### Temporal graph representation

A simple temporal graph encoder is:

\[
H_t^{(\ell+1)}
=
\sigma
\left(
\widetilde{D}_t^{-1/2}
\widetilde{A}_t
\widetilde{D}_t^{-1/2}
H_t^{(\ell)}
W^{(\ell)}
\right)
\]

where:

\[
\widetilde{A}_t=A_t+I
\]

and:

\[
\widetilde{D}_{ii,t}
=
\sum_j \widetilde{A}_{ij,t}
\]

The graph model may then preserve temporal continuity with:

\[
Z_t
=
\operatorname{GRU}
\left(
H_t^{(L)},
Z_{t-1}
\right)
\]

This is a research representation of time-varying channel relationships. It does not establish a biological mechanism, physical node migration, or a clinical inference.

### Topology-change measures

Edge-change fraction:

\[
C_E(t,0)
=
\frac{
\sum_{i,j}
\mathbf{1}
\left[
|A_{ij,t}-A_{ij,0}|
\geq
\varepsilon_E
\right]
}{
\sum_{i,j}
\mathbf{1}
\left[
A_{ij,t}\neq0
\lor
A_{ij,0}\neq0
\right]
}
\]

Mean node-feature shift:

\[
C_X(t,0)
=
\frac{1}{|V_0\cap V_t|}
\sum_{i\in V_0\cap V_t}
\lVert x_{i,t}-x_{i,0}\rVert_1
\]

Temporal-smoothness loss:

\[
\mathcal{L}_{\mathrm{topology}}
=
\frac{1}{|A_t|}
\lVert A_t-A_{t-1}\rVert_F^2
\]

The smoothness term prevents a model from interpreting insignificant short-term noise as a topology change. It must not erase meaningful, documented changes; use it as a regularizer whose weight is fixed in the experiment manifest.

### Disposition logic

| Condition | Research disposition |
|---|---|
| \(C_E\) and \(C_X\) below predeclared attention thresholds | Stable |
| Either measure meets attention but not investigation threshold | Monitor |
| Either measure reaches a predeclared investigation threshold | Investigate |
| Missing channel alignment, insufficient summaries, or undocumented edge policy | Insufficient evidence |

A graph change calls for analytical review of data quality, feature construction, session conditions, decoder versioning, or other documented factors. It does not independently imply a biological, clinical, or causal conclusion.

### Volumetric flux reconstruction interface

Volumetric reconstruction should be treated as a regularized inverse-problem research interface:

\[
y_t = L_t j_t+\epsilon_t
\]

where:

- \(y_t\) is an authorized measurement summary.
- \(L_t\) is the authorized or literature-derived forward operator.
- \(j_t\) is the estimated source-space representation.
- \(\epsilon_t\) is residual measurement and model error.

A Tikhonov-regularized estimator is:

\[
\hat{j}_t
=
\arg\min_{j}
\left(
\lVert L_tj-y_t\rVert_2^2+
\lambda\lVert j\rVert_2^2
\right)
\]

When \(L_t^TL_t+\lambda I\) is invertible:

\[
\hat{j}_t
=
(L_t^TL_t+\lambda I)^{-1}L_t^Ty_t
\]

Source localization from electromagnetic measurements is an inverse problem governed by a forward model and subject to non-uniqueness and model assumptions. Therefore, the reconstruction must always retain the forward-model reference, regularization policy, uncertainty method, and scope limitations.

### Required artifacts

- `GraphSnapshot` schema
- Edge-construction policy
- Channel-alignment policy
- Dynamic-GNN model card
- Temporal-smoothness configuration record
- Topology-change report
- Inverse-model reference record
- Uncertainty and limitation register
- Provenance-manifest entry

## 11 — Latent Factor Intent Isolation

### Objective

Specify a latent-dynamics research model that estimates task-relevant low-dimensional temporal structure from authorized, de-identified time-series summaries while evaluating sensitivity to drift, contextual variation, signal change, and learning effects.

### Scope boundary

The term `intent latent` is an analytic representation for evaluating task-associated structure in an approved research context. It is not a direct reading of thoughts, a proof of inner experience, a clinical diagnosis, or a personal identity inference.

### Generative dynamics

Let:

- \(x_t\) be the observed de-identified feature vector.
- \(z_t\) be the latent dynamic state.
- \(u_t\) be an inferred or documented contextual input.
- \(\epsilon_t\) be process noise.
- \(\nu_t\) be observation noise.

The state model is:

\[
z_t=f_\theta(z_{t-1},u_t)+\epsilon_t
\]

and the observation model is:

\[
x_t=g_\phi(z_t)+\nu_t
\]

For count-like event data, a suitable observation model is:

\[
x_t
\sim
\operatorname{Poisson}
\left(
\operatorname{softplus}(Wz_t+b)
\right)
\]

For normalized continuous feature summaries, a Gaussian observation model may be used:

\[
x_t
\sim
\mathcal{N}
\left(
g_\phi(z_t),
\Sigma
\right)
\]

The likelihood family must match the documented data representation rather than being chosen from convenience.

### LFADS-aligned architecture

A research model may contain:

\[
q_\psi(z_0,u_{1:T}\mid x_{1:T})
\]

as an encoder approximation and:

\[
p_\theta(z_{1:T},x_{1:T}\mid z_0,u_{1:T})
\]

as a recurrent generative model.

A generic evidence lower bound is:

\[
\mathcal{L}_{\mathrm{ELBO}}
=
\mathbb{E}_{q_\psi}
[
\log p_\theta(x_{1:T}\mid z_{1:T})
]
-
D_{\mathrm{KL}}
\left(
q_\psi(z_0,u_{1:T}\mid x_{1:T})
\Vert
p(z_0,u_{1:T})
\right)
\]

The training objective may include explicitly declared terms for reconstruction, prediction, temporal regularity, domain shift, and uncertainty calibration:

\[
\mathcal{L}_{\mathrm{total}}
=
\mathcal{L}_{\mathrm{ELBO}}
+
\beta
\mathcal{L}_{\mathrm{temporal}}
+
\gamma
\mathcal{L}_{\mathrm{drift}}
+
\omega
\mathcal{L}_{\mathrm{uncertainty}}
\]

Every coefficient must be fixed before evaluation and recorded in the provenance manifest.

### Drift-control design

The model must not treat every session change as an intent change. Separate research features into:

| Feature class | Use in model | Governance rule |
|---|---|---|
| Task-associated outcome features | Decoder-target evaluation | Use only when task definition and labels are documented |
| Signal-quality summaries | Drift and measurement-quality monitoring | Do not use as an intent label |
| Session-context summaries | Covariate adjustment or stratified evaluation | Record source, scope, and missingness |
| Calibration metadata | Adaptation-burden analysis | Keep distinct from outcome labels |
| User-reported aggregate outcomes | Human-factors evaluation | Never substitute for signal-derived labels without stated methodology |

A domain-invariance regularizer can be specified as:

\[
\mathcal{L}_{\mathrm{drift}}
=
D
\left(
q_\psi(z\mid x,\mathrm{baseline}),
q_\psi(z\mid x,\mathrm{session}\ t)
\right)
\]

only when the task context is comparable. The method must preserve uncertainty and report where session comparability is weak.

### Evaluation panel

| Metric | Research purpose |
|---|---|
| Reconstruction quality | Determines whether the model can represent observed summary structure |
| Held-out prediction quality | Tests generalization without reusing evaluation observations |
| Task-associated outcome quality | Tests documented association with the approved research task |
| Drift sensitivity | Measures whether output is unduly altered by session distribution shift |
| Uncertainty coverage | Tests whether model confidence matches observed error patterns |
| Calibration burden | Links adaptation cost to the human-factors research object |
| False activation rate | Ensures adaptation does not increase unintended system output |

The latent model is retained as a research candidate only when each predeclared minimum requirement is satisfied:

\[
\operatorname{LatentModelEligible}
=
(R_{\mathrm{reconstruction}}\geq\theta_R)
\land
(P_{\mathrm{heldout}}\geq\theta_P)
\land
(Q_{\mathrm{task}}\geq\theta_Q)
\land
(S_{\mathrm{drift}}\leq\theta_S)
\land
(U_{\mathrm{coverage}}\geq\theta_U)
\]

A weighted report score may be displayed:

\[
Q_{\mathrm{latent}}
=
0.20R_{\mathrm{reconstruction}}
+
0.25P_{\mathrm{heldout}}
+
0.30Q_{\mathrm{task}}
+
0.15(1-S_{\mathrm{drift}})
+
0.10U_{\mathrm{coverage}}
\]

The conjunctive gate remains authoritative. The weighted score cannot compensate for an unacceptably poor required dimension.

### Required artifacts

- Latent-model specification
- Data-representation and likelihood-selection record
- Encoder and generator model card
- Drift-control plan
- Label and task-definition policy
- Evaluation and uncertainty-calibration plan
- Human-factors linkage record
- Claim-status and limitation register
- Provenance-manifest entry
