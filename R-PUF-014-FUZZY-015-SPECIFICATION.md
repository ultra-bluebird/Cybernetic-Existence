<!-- mk-bluebird/Cybercore/research/R-PUF-014-FUZZY-015-SPECIFICATION.md -->

# PUF Reliability and Fuzzy-Extraction Specification

Document Ref: RES-PUF-FUZZY-014-015-2026-REV1  
Classification: Institutionally Managed / Hardware-Identity Research  
Scope: Device-bound identity reliability, response uniqueness, helper-data governance, and error-correction feasibility analysis

## 14 — PUF Reliability-Uniqueness Foundation

### Objective

Define a research-grade evaluation framework for physical unclonable function response reliability and uniqueness under documented environmental variation. The framework evaluates physical-component identity behavior through de-identified binary response statistics and does not use, derive, or represent biological identity.

### Scope boundary

The terms `enrollment response`, `verification response`, `helper data`, and `reconstructed key` describe ordinary hardware-security research objects.

This research object:

- Uses response summaries, Hamming-distance statistics, and institutionally controlled references.
- Does not request, expose, or analyze personal medical, neural, physiological, clinical, or identity data.
- Does not replace institutional hardware identity, key-management, or security-review procedures.
- Does not treat a physical-component response as a statement about a person.

### Arbiter-PUF model

For binary challenge vector:

\[
C=(c_1,c_2,\ldots,c_n)\in\{0,1\}^n
\]

define the feature vector:

\[
\phi_i(C)
=
\prod_{j=i}^{n}(1-2c_j),
\qquad i=1,\ldots,n
\]

with:

\[
\phi_{n+1}(C)=1
\]

The delay-difference model is:

\[
\Delta D(C)
=
\mathbf{w}^{T}\mathbf{\Phi}(C)
\]

The idealized response rule is:

\[
r(C)
=
\begin{cases}
1, & \Delta D(C)>0\\
0, & \Delta D(C)\leq0
\end{cases}
\]

The delay-vector \(\mathbf{w}\) represents manufacturing-dependent physical variation. This linear model is useful for evaluation and simulation, but it does not independently establish resistance to modeling attacks. Arbiter-PUF variants have documented exposure to machine-learning-based modeling attacks, so architecture-specific threat evaluation must remain a separate object. [215][218]

### SRAM-PUF model

For an SRAM cell with threshold-voltage mismatch \(\Delta V_{th}\) and manufacturing-variation scale \(\sigma_{RDF}\), a planning model is:

\[
P(\operatorname{Cell}=1)
=
\Phi
\left(
\frac{\Delta V_{th}}{\sigma_{RDF}}
\right)
\]

where \(\Phi\) is the standard normal cumulative distribution function.

This describes a statistical model of a physical memory cell’s power-up tendency. It is not a guarantee of response stability. SRAM PUF reliability may vary with temperature, voltage, and aging, which is why the research profile evaluates repeated responses over the declared environmental range. [217][224]

### Hamming-distance metrics

For equal-length binary responses \(R_a\) and \(R_b\), define:

\[
d_H(R_a,R_b)
=
\sum_{i=1}^{n}
\mathbf{1}
\left[
R_{a,i}\neq R_{b,i}
\right]
\]

Normalized Hamming distance is:

\[
\operatorname{NHD}(R_a,R_b)
=
\frac{d_H(R_a,R_b)}{n}
\]

#### Intra-device reliability

For repeated responses from the same physical component:

\[
\mu_{\mathrm{intra}}
=
\frac{1}{K}
\sum_{k=1}^{K}
\operatorname{NHD}
\left(
R_{\mathrm{enroll}},
R_{\mathrm{verify},k}
\right)
\]

Lower values indicate greater response repeatability in the documented environment.

#### Inter-device uniqueness

For responses across different physical components:

\[
\mu_{\mathrm{inter}}
=
\frac{1}{M}
\sum_{m=1}^{M}
\operatorname{NHD}
\left(
R_{a,m},
R_{b,m}
\right)
\]

An idealized unbiased and independent response population has an inter-device mean near \(0.5\). The result should be interpreted with sample size, environmental range, response length, and confidence intervals.

### Research disposition gate

For policy parameters:

\[
\theta_{\mathrm{intra,mean}},
\theta_{\mathrm{intra,max}},
\theta_{\mathrm{inter,mean}},
\theta_{\mathrm{inter,sd}}
\in[0,1]
\]

the system records a favorable research disposition only when:

\[
\mu_{\mathrm{intra}}
\leq
\theta_{\mathrm{intra,mean}}
\]

\[
\max(\operatorname{NHD}_{\mathrm{intra}})
\leq
\theta_{\mathrm{intra,max}}
\]

\[
\mu_{\mathrm{inter}}
\geq
\theta_{\mathrm{inter,mean}}
\]

\[
\sigma_{\mathrm{inter}}
\leq
\theta_{\mathrm{inter,sd}}
\]

Planning values may be:

\[
\theta_{\mathrm{intra,mean}}=0.10,
\qquad
\theta_{\mathrm{intra,max}}=0.20,
\qquad
\theta_{\mathrm{inter,mean}}=0.40,
\qquad
\theta_{\mathrm{inter,sd}}=0.10
\]

These are research-reporting thresholds rather than universal hardware-security or clinical standards. Values must be chosen for the component class, response length, environment, error-correction capability, and intended protocol.

### Wiring

\[
[\text{Enrollment Response }R]
\rightarrow
[\text{Helper-Data Generation}]
\rightarrow
[\text{Institutionally Controlled Helper }W]
\]

\[
[\text{Verification Response }R']
\rightarrow
[\text{Hamming-Distance Assessment}]
\rightarrow
[\text{Error-Correction Feasibility}]
\rightarrow
[\text{Stable Key Reconstruction Result}]
\]

### Required research artifacts

- PUF profile and component-reference schema
- Environmental-range declaration
- Enrollment and verification response summary format
- Intra-device reliability report
- Inter-device uniqueness report
- Hamming-distance distribution report
- Modeling-resistance evidence register
- Helper-data handling policy
- Provenance manifest and review-event record

## 15 — Fuzzy Extraction Error Bound

### Objective

Specify the error-correction feasibility calculation required to determine whether a BCH error-correction profile can meet a declared reconstruction-failure target under a stated response-noise model.

### Fuzzy-extraction relation

At enrollment, a response \(R\) and encoded key material are used to form helper data \(W\):

\[
W
=
R
\oplus
\operatorname{Codeword}(K)
\]

At verification:

\[
R'
\oplus
W
=
R'
\oplus
R
\oplus
\operatorname{Codeword}(K)
\]

Let:

\[
e=R'\oplus R
\]

Then:

\[
R'
\oplus
W
=
e
\oplus
\operatorname{Codeword}(K)
\]

A BCH decoder reconstructs the intended codeword when:

\[
d_H(R,R')
\leq t
\]

where \(t\) is the code’s guaranteed correction capacity.

\[
\operatorname{Decode}
\left(
R'
\oplus W
\right)
=
\operatorname{Codeword}(K)
\Rightarrow
K
\]

### BCH feasibility model

Let:

- \(n\) be codeword length.
- \(k\) be message length.
- \(t\) be BCH correction capacity.
- \(p\) be a declared per-bit noise probability.
- \(X\sim\operatorname{Binomial}(n,p)\) be the number of erroneous bits.

The estimated reconstruction-failure probability is:

\[
P_{\mathrm{failure}}
=
P(X>t)
=
\sum_{i=t+1}^{n}
{n\choose i}
p^i
(1-p)^{n-i}
\]

The profile meets the declared target only if:

\[
\boxed{
P_{\mathrm{failure}}
<
10^{-9}
}
\]

For a selected \((n,k)\) profile, choose the least correction capacity satisfying:

\[
t_{\min}
=
\min
\left\{
t\in\{0,\ldots,n-1\}
:
P(X>t)<10^{-9}
\right\}
\]

The model is valid only as a planning approximation when the observed error process is sufficiently modeled by independent Bernoulli bit errors. If error clustering, temporal correlation, environmental shifts, systematic bias, or unstable-bit concentration exists, the model must be replaced or extended with an empirically supported correlated-error model.

### Parameter-selection workflow

1. Declare the response length \(n\).
2. Record the BCH message length \(k\) and helper-data length \(n-k\).
3. Estimate or bound a response-noise parameter \(p\) from authorized reliability summaries.
4. Compute \(P(X>t)\) for feasible values of \(t\).
5. Select the minimum \(t\) that meets the declared probability target.
6. Confirm that a realizable BCH code profile exists for the selected \((n,k,t)\).
7. Record environmental scope, sample size, confidence treatment, and independence assumptions.
8. Record helper-data protection, integrity, and access-control requirements.

### Helper-data handling

Helper data may be public in fuzzy-extractor constructions, but it is security-relevant protocol material. The research profile therefore requires:

- Integrity protection for helper-data records.
- Binding to the component and protocol version through authenticated metadata.
- Controlled access and audit logging.
- Explicit analysis of information leakage and entropy loss.
- No direct storage of protected primary response material in the research ledger.
- No use of helper data as a substitute for institutional identity or authorization.

Research literature recognizes helper-data manipulation as a relevant fuzzy-extractor threat category and notes that Hamming-distance-based fuzzy extractors have a correction boundary defined by \(t\). [214]

### Required output record

```text
reconstruction_assessment_id:
puf_profile_reference:
bch_codeword_length_n:
bch_message_length_k:
helper_data_length_bits:
correction_capacity_t:
noise_model_type:
independent_bit_error_probability:
environment_scope_reference:
sample_size_reference:
predicted_failure_probability:
target_failure_probability:
model_assumptions:
correlated_error_assessment:
helper_data_governance_reference:
result_disposition:
review_event_reference:
```

### Completed conclusion

The appropriate answer to “what Hamming threshold achieves \(P_{\mathrm{error}}<10^{-9}\)?” is not a universal numeric \(t\). It is the minimum correction capacity obtained from the declared codeword length \(n\) and justified response-noise model \(p\):

\[
\boxed{
t_{\min}
=
\min
\left\{
t:
\sum_{i=t+1}^{n}
{n\choose i}
p^i(1-p)^{n-i}
<
10^{-9}
\right\}
}
\]

This computation is implemented in the accompanying Rust and Python artifacts. It returns a parameter-specific feasibility result, records the model assumptions, and prevents unsupported statements that a particular BCH threshold is universally sufficient.
