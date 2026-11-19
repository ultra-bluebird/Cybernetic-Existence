# Asynchronous SNN and Ascon-AEAD128 Research Specification

Document Ref: RES-SNN-ASCON-012-013-2026-REV1  
Classification: Institutionally Managed / Assistive Neurotechnology Research  
Scope: Event-threshold evaluation and confidentiality, integrity, provenance contract design

## 12 — Asynchronous SNN Threshold Policy

### Objective

Define a simulation and evaluation policy for reducing event-telemetry volume while preserving predeclared task-performance and user-centered accuracy targets.

The object operates on authorized, de-identified event summaries or synthetic research data. It does not modify sensing thresholds in an institutionally managed system and does not infer clinical, cognitive, or identity information.

### Baseline transmission rule

\[
\operatorname{Transmit}(x_t)=
\begin{cases}
1,&|x_t|>\theta_t\\
0,&|x_t|\leq\theta_t
\end{cases}
\]

where:

- \(x_t\) is a normalized event-amplitude summary at time \(t\).
- \(\theta_t\) is an adaptive threshold.
- `Transmit = 1` means the event is retained for the local research processing path.
- `Transmit = 0` means the event is suppressed from the low-bandwidth event stream.

### Adaptive threshold policy

\[
\theta_t
=
\operatorname{clip}
\left(
\theta_{\mathrm{base}}
+
\alpha n_t
+
\beta u_t
-
\gamma v_t,
\theta_{\min},
\theta_{\max}
\right)
\]

where:

- \(n_t\) is a normalized noise-scale estimate.
- \(u_t\) is a normalized model-uncertainty estimate.
- \(v_t\) is a normalized event-novelty estimate.
- \(\alpha,\beta,\gamma\geq0\) are policy parameters fixed before evaluation.
- \(\operatorname{clip}\) bounds the selected threshold within the declared policy range.

The novelty term reduces the threshold for unusual but potentially informative events. The uncertainty term raises the threshold when uncertainty indicates that the system should avoid transmitting ambiguous activity without additional review. Every rule is a research policy and must be versioned.

### Local reconstruction interface

\[
\hat{x}_{1:T}
=
\operatorname{SNNDecode}
\left(
\{
(x_t,\operatorname{Transmit}(x_t))
\}_{t=1}^{T},
\mathcal{M}
\right)
\]

where \(\mathcal{M}\) is a documented local reconstruction model. The decoder is evaluated against a fixed, held-out research set or authorized aggregate outcome summary.

### Evaluation objectives

| Metric | Formula or method | Interpretation |
|---|---|---|
| Telemetry fraction | \(R_{\mathrm{tx}}=\frac{N_{\mathrm{transmit}}}{N_{\mathrm{total}}}\) | Lower is more bandwidth-efficient, subject to accuracy and usability constraints |
| Reconstruction quality | Documented similarity or prediction metric | Tests whether event suppression destroys useful task-relevant structure |
| Task accuracy | \(A\in[0,1]\) | Must remain above a predeclared research floor |
| False activation rate | \(F\in[0,1]\) | Must not increase beyond a predeclared tolerance |
| Latency | \(L\in[0,1]\) | Captures event-selection and reconstruction delay |
| Calibration burden | \(B_{\mathrm{cal}}\in[0,1]\) | Links threshold adaptation to human-factors effort |
| Uncertainty review rate | \(R_{\mathrm{review}}\) | Tracks events withheld for controlled analytical review |

### Threshold-policy gate

A threshold policy is retained as a research candidate only if:

\[
\operatorname{ThresholdPolicyEligible}
=
(A\geq\theta_A)
\land
(F\leq\theta_F)
\land
(R_{\mathrm{tx}}\leq\theta_R)
\land
(B_{\mathrm{cal}}\leq\theta_B)
\]

The thresholds are study-specific and must be locked in the provenance manifest before evaluation.

A weighted planning score may be displayed:

\[
Q_{\mathrm{threshold}}
=
w_AA+
w_R(1-R_{\mathrm{tx}})
+
w_F(1-F)
+
w_L(1-L)
+
w_B(1-B_{\mathrm{cal}})
\]

with:

\[
\sum_iw_i=1,
\qquad
w_i\geq0
\]

The conjunctive eligibility gate remains authoritative. A favorable weighted score cannot compensate for a failed accuracy or false-activation criterion.

### Wiring

\[
[\text{Authorized Event Summary}]
\rightarrow
[\text{Adaptive Threshold Policy}]
\rightarrow
[\text{Retained Event Stream}]
\rightarrow
[\text{Local SNN Reconstruction}]
\rightarrow
[\text{Edge Decoder Evaluation}]
\rightarrow
[\text{Drift, Calibration, and Human-Factors Ledger}]
\]

### Research interpretation

Asynchronous event-driven processing is a useful research direction because sparse, dynamic computations can reduce processing demand when the event representation retains task-relevant information. Evidence from neuromorphic research reports energy reductions from asynchronous sensing and dynamic input masking, but the effect is dependent on hardware, workload, encoding, sparsity, and evaluation method. [203][205][206]

## 13 — Ascon-AEAD128 Security Contract

### Objective

Define a node-to-hub telemetry security contract that preserves confidentiality, integrity, replay resistance, provenance, purpose limitation, and auditability using an approved implementation of the NIST SP 800-232 Ascon-AEAD128 algorithm.

This object is a cryptographic governance specification. It does not implement custom encryption, disclose keys, generate authentication credentials, or describe private institutional system parameters.

### NIST SP 800-232 parameter profile

| Parameter | Required value |
|---|---:|
| Algorithm | Ascon-AEAD128 |
| Key size | 128 bits |
| Nonce size | 128 bits |
| Full authentication-tag size | 128 bits |
| Internal state | 320 bits |
| State lanes | \(5\times64\) bits |
| Rate | 128 bits |
| Capacity | 192 bits |
| Outer permutation | 12 rounds |
| Inner permutation | 8 rounds |

Ascon-AEAD128 uses a 320-bit state and a duplex authenticated-encryption construction. Its standardized parameter profile is a 128-bit key, nonce, and tag; 128-bit message rate; 192-bit capacity; and 12-round / 8-round permutations. [202][210][211]

### State notation

\[
S=s_0\parallel s_1\parallel s_2\parallel s_3\parallel s_4
\]

where each lane \(s_i\) is 64 bits:

\[
|S|=5\times64=320\text{ bits}
\]

A permutation round contains a round-constant addition, substitution layer, and linear diffusion layer:

\[
s_2\leftarrow s_2\oplus C_r
\]

\[
s_i
\leftarrow
s_i
\oplus
(s_i\ggg a_i)
\oplus
(s_i\ggg b_i)
\]

The project shall rely on NIST SP 800-232 and approved library conformance tests for exact algorithm semantics, constants, bit ordering, padding, and test vectors. The contract is intentionally not a substitute for a reviewed cryptographic implementation.

### Security requirements

| Property | Contract requirement |
|---|---|
| Confidentiality | Sensitive payload content is encrypted using an approved Ascon-AEAD128 implementation |
| Integrity | Every ciphertext and associated-data value is authenticated with a full 128-bit tag |
| Nonce uniqueness | A 128-bit nonce is unique for every encryption under a key; reuse is prohibited |
| Associated-data binding | Protocol version, sender/receiver reference, purpose class, sequence information, and retention class are authenticated as associated data |
| Replay resistance | Receiver validates monotonic sequence or anti-replay state before accepting a record |
| Provenance | Each accepted envelope references a signed or institutionally authorized provenance event |
| Key custody | Key material is generated, held, rotated, and retired only in the authorized key-management boundary |
| Fail-closed verification | Authentication failure, invalid sequence, missing provenance, malformed metadata, or nonce-reuse detection results in rejection or quarantined review |
| Minimal disclosure | The envelope contains only pseudonymous references and integrity metadata needed for the permitted purpose |
| Auditability | Encryption, verification, rejection, and key-lifecycle events emit a privacy-minimized audit record |

### Associated-data profile

The associated-data field must bind the ciphertext to its context:

```text
protocol_version
contract_id
sender_reference_id
receiver_reference_id
data_class
permitted_purpose
sequence_number
created_at_utc
retention_class
provenance_event_id
```

Associated data is authenticated but not encrypted. It must therefore contain controlled identifiers and categorical metadata only; it must not contain raw protected telemetry, direct personal identifiers, secret material, or health status.

### Envelope acceptance predicate

Let \(\mathcal{E}\) be an incoming telemetry envelope. It is accepted only if:

\[
\operatorname{Accept}(\mathcal{E})
=
V_{\mathrm{tag}}
\land
U_{\mathrm{nonce}}
\land
M_{\mathrm{sequence}}
\land
B_{\mathrm{purpose}}
\land
P_{\mathrm{provenance}}
\land
R_{\mathrm{recipient}}
\]

where:

- \(V_{\mathrm{tag}}\): authentication tag verifies.
- \(U_{\mathrm{nonce}}\): nonce has not been used with the relevant key.
- \(M_{\mathrm{sequence}}\): sequence value satisfies anti-replay policy.
- \(B_{\mathrm{purpose}}\): data class and purpose binding are authorized.
- \(P_{\mathrm{provenance}}\): the referenced provenance event is valid.
- \(R_{\mathrm{recipient}}\): the intended recipient reference matches the receiving boundary.

\[
\neg\operatorname{Accept}(\mathcal{E})
\Rightarrow
\operatorname{RejectOrQuarantine}(\mathcal{E})
\]

No plaintext-derived action is authorized before tag verification and envelope-policy validation complete.

### Provenance record

```text
contract_id:
envelope_id:
sender_reference_id:
receiver_reference_id:
data_class:
permitted_purpose:
sequence_number:
nonce_reference:
associated_data_digest:
ciphertext_digest:
authentication_tag_length_bits:
verification_result:
replay_check_result:
provenance_event_id:
created_at_utc:
retention_class:
audit_event_id:
```

### Wiring

\[
[\text{Authorized Distributed-Node Reference}]
\rightarrow
[\text{Ascon-AEAD128 Approved Implementation}]
\rightarrow
[\text{Authenticated Telemetry Envelope}]
\rightarrow
[\text{Authorized Local Hub Reference}]
\rightarrow
[\text{Secure Institutional Data Boundary}]
\rightarrow
[\text{Append-Only Audit and Provenance Ledger}]
\]

### Formal-verification targets

The appropriate Lean or Coq work is a formal model of the **contract properties**, not an independent replacement implementation of Ascon:

\[
\forall\mathcal{E}:
\neg V_{\mathrm{tag}}(\mathcal{E})
\Rightarrow
\neg\operatorname{Accept}(\mathcal{E})
\]

\[
\forall\mathcal{E}:
\neg U_{\mathrm{nonce}}(\mathcal{E})
\Rightarrow
\neg\operatorname{Accept}(\mathcal{E})
\]

\[
\forall\mathcal{E}:
\neg P_{\mathrm{provenance}}(\mathcal{E})
\Rightarrow
\neg\operatorname{Accept}(\mathcal{E})
\]

\[
\forall\mathcal{E}:
\operatorname{Accept}(\mathcal{E})
\Rightarrow
\operatorname{AuditRecorded}(\mathcal{E})
\]

These lemmas prove fail-closed governance at the protocol boundary. Cryptographic primitive correctness should be inherited from a verified, maintained, standards-conformant implementation and its test-vector suite.
