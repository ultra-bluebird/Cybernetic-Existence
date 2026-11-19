<!-- mk-bluebird/Cybercore/research/R-SIDECHANNEL-018-019-SPECIFICATION.md -->

# Boolean Masking and Dual-Rail Side-Channel Research Specification

Document Ref: RES-SIDECHANNEL-018-019-2026-REV1  
Classification: Institutionally Managed / Hardware-Security Research  
Scope: Four-share Boolean masking, non-complete circuit declarations, WDDL-style dual-rail transition balancing, and leakage-evidence documentation

## 18 — Four-Share Boolean Masking Non-Completeness

### Objective

Define a structural verification object for splitting a sensitive logical variable into four Boolean shares and recording whether each declared combinational processing cell remains non-complete with respect to that sensitive variable.

The object is a circuit-structure and evidence specification. It does not establish immunity from differential power analysis, electromagnetic leakage, probing, glitches, coupling, routing imbalance, fault injection, or any other implementation-level side channel.

### Share relation

Let the sensitive logical value be:

\[
X\in\{0,1\}
\]

Represent \(X\) as four Boolean shares:

\[
\boxed{
X=x_0\oplus x_1\oplus x_2\oplus x_3
}
\]

A valid share-generation relation is:

\[
x_0=\rho_0
\]

\[
x_1=\rho_1
\]

\[
x_2=\rho_2
\]

\[
x_3=X\oplus\rho_0\oplus\rho_1\oplus\rho_2
\]

where \(\rho_0,\rho_1,\rho_2\) are independent mask values from a documented randomness source.

The exact source, health testing, entropy evaluation, reseeding policy, and implementation boundary for mask randomness must be recorded in the security evidence ledger.

### Non-completeness property

For a sensitive input with \(d=4\) shares, an individual declared processing function must not consume all four shares:

\[
\boxed{
\forall g\in\mathcal{G}:
\left|
\operatorname{SharesVisible}(g)
\right|
<
4
}
\]

For a declared third-order probing model:

\[
\forall \mathcal{P}\subseteq\mathcal{G}:
|\mathcal{P}|\leq3
\Rightarrow
\operatorname{IndependentOf}
\left(
\operatorname{Observations}(\mathcal{P}),
X
\right)
\]

The second relation is a verification target requiring a precise leakage model and composition proof. It must not be inferred merely from a gate-level share-count check.

### Nonlinear processing requirement

Nonlinear masked operations require carefully designed share transformation and fresh randomness. A structural requirement for this research profile is:

\[
\operatorname{Nonlinear}(g)
\Rightarrow
|\operatorname{RandomnessInputs}(g)|\geq1
\]

This is an evidence-completeness condition, not proof that a nonlinear masked gadget is secure.

### Structural wiring

\[
[\text{Sensitive State }X]
\rightarrow
[\text{Four-Share Generation}]
\rightarrow
[\text{Declared Gate Share Visibility}]
\rightarrow
[\text{Non-Completeness Assessment}]
\rightarrow
[\text{Masked Computation Evidence Ledger}]
\]

### Required netlist record

```text
profile_id:
masked_signal_id:
share_count: 4
share_ids:
reconstruction_relation: "x0 XOR x1 XOR x2 XOR x3"
randomness_source_reference:
declared_probe_order:

gate_declarations:
  - gate_id:
    operation_class:
    input_share_ids:
    output_share_id:
    randomness_input_ids:
    placement_region_reference:
    routing_region_reference:

physical_separation_review_reference:
glitch_model_reference:
randomness_quality_review_reference:
leakage_measurement_reference:
claim_status:
review_event_reference:
```

### Verification output

| Structural result | Interpretation |
|---|---|
| Every declared gate sees fewer than four shares and nonlinear gates declare randomness | Structurally non-complete |
| One or more declared gates sees all shares | Share-separation review required |
| A nonlinear gate lacks declared fresh randomness | Randomness review required |
| Placement, routing, clock, power-delivery, glitch, or measurement evidence is absent | Structural result only; implementation evidence remains incomplete |

## 19 — WDDL Constant-Energy-Flux Research Model

### Objective

Define a paired-rail accounting and evidence model for WDDL-style logic in which each true data path is paired with a complementary path and evaluated for declared nominal transition balance.

The object is not a claim that physical power consumption is perfectly constant. Process variation, routing, capacitance mismatch, glitches, clock skew, supply noise, electromagnetic radiation, placement, and layout can all cause observable imbalance even if a Boolean-level transition count is matched.

### Paired-rail relation

For each true rail \(T_i\), define a complementary rail \(D_i\):

\[
D_i=\neg T_i
\]

The nominal Boolean transition-accounting target is:

\[
\boxed{
A_t+A_d=E_c
}
\]

where:

- \(A_t\) is the declared transition count or switching-activity estimate for the true rail.
- \(A_d\) is the declared transition count or switching-activity estimate for the complementary rail.
- \(E_c\) is a constant nominal activity target for the paired implementation.

For each declared dual-rail gate:

\[
\Delta A_i
=
\left|
A_{t,i}-A_{d,i}
\right|
\]

The structural balance requirement is:

\[
\Delta A_i
\leq
\delta_A
\]

where \(\delta_A\) is a predeclared policy tolerance. A strict transition-balance study can select:

\[
\delta_A=0
\]

### Physical balance requirement

Boolean-level balance is insufficient for physical constant-power claims. The implementation evidence record must include:

\[
C_{t,i}\approx C_{d,i}
\]

\[
L_{t,i}\approx L_{d,i}
\]

\[
R_{t,i}\approx R_{d,i}
\]

where \(C\), \(L\), and \(R\) represent rail-dependent capacitance, inductance, and resistance estimates or measured summaries.

The implementation should also document:

- Placement symmetry.
- Routing symmetry.
- Clock-arrival skew.
- Load balance.
- Power-distribution conditions.
- Glitch behavior.
- Electromagnetic measurement setup.
- Process-voltage-temperature evaluation range.

### Structural wiring

\[
[\text{True Path}]
+
[\text{Complementary Dummy Path}]
\rightarrow
[\text{Paired-Rail Transition Accounting}]
\rightarrow
[\text{Physical Balance Evidence}]
\rightarrow
[\text{Leakage Measurement}]
\rightarrow
[\text{Uniform-Power-Signature Research Claim}]
\]

### Leakage assessment

Use a fixed-versus-random trace test to determine whether the measurement setup detects a statistically meaningful separation:

\[
t
=
\frac{
\mu_{\mathrm{fixed}}
-
\mu_{\mathrm{random}}
}{
\sqrt{
\frac{\sigma_{\mathrm{fixed}}^2}{N_{\mathrm{fixed}}}
+
\frac{\sigma_{\mathrm{random}}^2}{N_{\mathrm{random}}}
}
}
\]

A common exploratory screening threshold is:

\[
|t|\geq4.5
\]

A result below the threshold means:

\[
|t|<4.5
\Rightarrow
\text{no statistical leakage detected by this test configuration}
\]

It does not prove the absence of leakage under all sampling rates, locations, attack models, environmental conditions, or higher-order statistical tests.

### Required evidence record

```text
profile_id:
dual_rail_gate_id:
true_rail_id:
complementary_rail_id:
nominal_true_transitions:
nominal_complementary_transitions:
transition_delta:
placement_region_reference:
routing_region_reference:
capacitance_balance_reference:
clock_skew_reference:
power_delivery_reference:
glitch_evaluation_reference:
measurement_setup_reference:
trace_count_fixed:
trace_count_random:
welch_t_value:
screening_threshold:
leakage_result:
claim_status:
review_event_reference:
```

### Completed conclusion

The rigorous conclusions available from Objects 18 and 19 are:

\[
\boxed{
X=x_0\oplus x_1\oplus x_2\oplus x_3
}
\]

with a structural non-completeness obligation:

\[
\boxed{
\forall g\in\mathcal{G}:
|\operatorname{SharesVisible}(g)|<4
}
\]

and a dual-rail transition-balance objective:

\[
\boxed{
\Delta A_i=
|A_{t,i}-A_{d,i}|
\leq\delta_A
}
\]

These support a verifiable design record for masked computation and paired-rail balancing. They become evidence-bounded side-channel claims only after combining structural review, randomness assessment, physical implementation review, and measured leakage evaluation.
