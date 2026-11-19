<!-- mk-bluebird/Cybercore/research/R-PUF-016-017-MODELING-RESISTANCE-SPECIFICATION.md -->

# Feed-Forward and XOR PUF Modeling-Resistance Specification

Document Ref: RES-PUF-FF-XOR-016-017-2026-REV1  
Classification: Institutionally Managed / Hardware-Security Research  
Scope: PUF topology description, adversarial modeling evaluation, challenge-response access governance, and evidence traceability

## 16 — Feed-Forward Obfuscation Complexity

### Objective

Define how a Feed-Forward Arbiter PUF modifies the canonical linear Arbiter-PUF feature representation and establish an evidence-based procedure for measuring resistance to declared modeling attacks.

The object evaluates a physical-component security topology under a stated attack model. It does not claim universal modeling resistance, stable cryptographic strength, or a guaranteed sample-complexity value from topology parameters alone.

### Linear Arbiter-PUF reference model

For a binary challenge:

\[
C=(c_1,c_2,\ldots,c_n)\in\{0,1\}^n
\]

the conventional Arbiter-PUF feature vector is:

\[
\phi_i(C)
=
\prod_{j=i}^{n}
(1-2c_j)
\]

with:

\[
\phi_{n+1}(C)=1
\]

The modeled delay difference is:

\[
\Delta D(C)
=
\mathbf{w}^{T}\mathbf{\Phi}(C)
\]

and the response is:

\[
R(C)
=
\mathbf{1}
\left[
\Delta D(C)>0
\right]
\]

### Feed-Forward topology

A Feed-Forward loop introduces an intermediate response:

\[
f
=
\mathbf{1}
\left[
\Delta D_m(C)>0
\right]
\]

where \(m\) is a designated intermediate tap stage.

For an override stage \(v\), with \(m<v\), the modified challenge is:

\[
C^{FF}
=
(c_1,\ldots,c_{v-1},f,c_{v+1},\ldots,c_n)
\]

with:

\[
c_v\leftarrow f
\]

The downstream feature component becomes:

\[
\phi_i(C^{FF})
=
\prod_{j=i}^{n}
\left(
1-2c_j^{FF}
\right)
\]

For feature components whose product includes the override stage:

\[
\phi_i(C^{FF})
=
(1-2f)
\cdot
\prod_{\substack{j=i\\j\neq v}}^{n}
(1-2c_j)
\]

Because \(f\) is itself a thresholded function of the earlier challenge-dependent delay relation, the overall mapping becomes a composition of thresholded and multiplicative terms. It is piecewise-defined and no longer a single linear decision boundary in the standard Arbiter-PUF feature space.

This structural change alone does not establish a universal security level. Feed-Forward PUFs have been studied specifically because of the desire to resist modeling attacks, but published attack work also demonstrates that Feed-Forward structures can remain vulnerable under certain adversarial settings. [230][235][239]

### Complexity claim handling

The expression:

\[
M_{\min}
\propto
\mathcal{O}
\left(
\left(
\frac{n}{\epsilon}
\right)^{2k}
\right)
\]

may be retained only as a **topology-scaling hypothesis** for a stated attack family, response-access model, error regime, and evaluation protocol. It shall not be used as a universal lower bound on the number of challenge-response pairs required by an attacker.

The research record must store:

- Challenge dimensions \(n\).
- Number of parallel Arbiter paths \(k\).
- Feed-Forward tap and override positions.
- Challenge-response pair budget.
- Attack family and hyperparameter-search policy.
- Whether adversarial chosen challenges are permitted.
- Whether reliability information is available.
- Whether side-channel information is available.
- Train, validation, and held-out evaluation partitioning.
- Held-out prediction accuracy with uncertainty interval.
- Independent replication status.

### Attack-evaluation record

```text
attack_id:
topology_profile_id:
attack_family:
challenge_response_pair_budget:
chosen_challenge_access:
reliability_side_information:
side_channel_information:
training_accuracy:
held_out_accuracy:
held_out_confidence_interval:
evaluation_protocol_reference:
source_reference:
independent_evaluation_reference:
claim_status:
```

### Required topology profile

```text
profile_id:
topology:
challenge_dimensions:
parallel_streams:
feed_forward_loops:
  - tap_stage:
    override_stage:
response_access_policy_id:
institutional_reference:
claim_status:
```

### Wiring

\[
[\text{Challenge Bits }c_1,\ldots,c_n]
\rightarrow
[\text{Intermediate Arbiter Response }f]
\rightarrow
[\text{Override Stage }v]
\rightarrow
[\text{Modified Challenge }C^{FF}]
\rightarrow
[\text{Final Response }R]
\rightarrow
[\text{Attack-Evaluation Ledger}]
\]

## 17 — XOR PUF Resilience Matrix

### Objective

Create a reproducible matrix of topology configurations and observed adversarial modeling results. The output records evidence under specified attack conditions; it does not equate a high \(n\) or \(k\) value with proven resistance.

### XOR composition

For \(k\) component Arbiter-PUF responses:

\[
R
=
\bigoplus_{\ell=1}^{k}
r_\ell
\]

The output response is the parity of the component responses.

For independent component-response probabilities \(p_\ell(C)\), a useful modeling identity is:

\[
P(R=1\mid C)
=
\frac{1}{2}
-
\frac{1}{2}
\prod_{\ell=1}^{k}
\left(
1-2p_\ell(C)
\right)
\]

This expresses why XOR composition changes the response landscape. It does not establish that a chosen \(k\) defeats all modeling strategies.

### Resilience matrix schema

| Profile | Topology | \(n\) | \(k\) | FF loops | CRP budget | Attack family | Challenge access | Auxiliary information | Held-out accuracy | Interval | Evidence status |
|---|---|---:|---:|---:|---:|---|---|---|---:|---|---|
| `PUF-LINEAR-064-01` | Linear Arbiter | 64 | 1 | 0 | Recorded per study | Recorded per study | Recorded per study | Recorded per study | Measured | Measured | Study-specific |
| `PUF-XOR-128-06` | XOR Arbiter | 128 | 6 | 0 | Recorded per study | Recorded per study | Recorded per study | Recorded per study | Measured | Measured | Study-specific |
| `PUF-FF-XOR-128-08` | FF-XOR Arbiter | 128 | 8 | Recorded per profile | Recorded per study | Recorded per study | Recorded per study | Recorded per study | Measured | Measured | Study-specific |

### Required evaluation coverage

A profile is not eligible for a favorable research statement until the evaluation ledger includes:

\[
N_{\mathrm{attack\ families}}
\geq3
\]

\[
N_{\mathrm{independent\ evaluations}}
\geq2
\]

and includes explicit evaluation of:

\[
\operatorname{ChosenChallengeAccess}
\]

\[
\operatorname{ReliabilitySideInformation}
\]

\[
\operatorname{SideChannelInformation}
\]

The last three are separate dimensions because a topology can appear resistant to one restricted attack experiment while remaining vulnerable under a different response-access or adversary-information model.

### Prediction advantage

Define held-out adversarial prediction advantage:

\[
\operatorname{Advantage}_{\mathrm{atk}}
=
\max
\left(
0,
A_{\mathrm{atk}}-0.5
\right)
\]

where \(A_{\mathrm{atk}}\) is held-out prediction accuracy.

A result near \(0.5\) in a single experiment means only that the declared attacker and declared budget did not exceed random guessing in that experiment. It does not establish cryptographic indistinguishability or universal resistance.

### Research disposition

| Condition | Disposition |
|---|---|
| One attack result has held-out accuracy above the declared upper target | No evidence of resistance |
| Results are near random but coverage lacks chosen-challenge or reliability-aware evaluation | Requires independent attack evaluation |
| Modeling coverage is sufficient but side-channel evidence is missing | Access control and side-channel evaluation required |
| Multiple independent, documented evaluations remain near random under declared scope | Limited resistance in declared experiment |

### Access-control contract

The response-access policy must specify:

```text
policy_id:
topology_profile_id:
authorized_actor_class:
challenge_issuance_policy:
response_rate_limit:
challenge_reuse_policy:
duplicate_response_policy:
audit_event_requirement:
anomaly_threshold:
review_authority:
```

The access-control contract is not a substitute for topology evaluation. It reduces uncontrolled challenge-response exposure and creates an auditable research boundary.

### Completed conclusion

No general formula converts:

\[
(n,k)=(64,1)
\]

into a universal attack accuracy of \(99.8\%\), or:

\[
(n,k)=(128,\geq8)
\]

into a universal attack accuracy of \(50.05\%\).

The 50.05% figure appears in a particular reported four-layer DNN experiment involving a five-XOR construction; it is valuable as an evidence record, not as a transferable security threshold. [231]

Recent work demonstrates why the research object must remain adversary-specific: XOR-Arbiter PUFs have been attacked through reliability-aware methods, and a 2025 chosen-challenge study reports attacks that can model large XOR-Arbiter PUFs without reliability or side-channel information. [234][235]

The technically complete outcome is therefore:

\[
\boxed{
\text{Topology Profile}
\rightarrow
\text{Response-Access Contract}
\rightarrow
\text{Multi-Family Attack Evaluation}
\rightarrow
\text{Held-Out Accuracy and Uncertainty}
\rightarrow
\text{Evidence-Bounded Security Statement}
}
\]
