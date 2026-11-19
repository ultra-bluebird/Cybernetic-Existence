# Two-Class Service Panel Queue Model

This document defines the deterministic two-class service-panel queue model used by `popmath::queues`.

The model represents a shared public-service panel, kiosk, service counter, or comparable interface with two interaction classes:

- Standard interactions with a shorter expected service duration.
- Extended interactions with a longer expected service duration.

The model supports capacity planning, continuity assessment, staffing/channel sizing, and scenario comparison. It does not rank users or determine eligibility. It measures whether the declared public service capacity remains stable and whether the extended-duration interaction class meets its stated time threshold.

## Model Scope

The model uses:

- Poisson arrivals for each interaction class.
- Exponential service durations for each interaction class.
- A shared pool of `c` identical service channels.
- Equal queue priority between classes.
- An equivalent M/M/c approximation for shared waiting time.
- Class-specific total interaction time after queueing.

The model is appropriate as a transparent first-order planning method when a full multidimensional continuous-time Markov chain or discrete-event simulation is not required.

## Symbols

| Symbol | Meaning | Unit |
|---|---|---|
| \(\lambda_{\mathrm{standard}}\) | Standard interaction arrival rate | arrivals per hour |
| \(\lambda_{\mathrm{extended}}\) | Extended interaction arrival rate | arrivals per hour |
| \(\mu_{\mathrm{standard}}\) | Standard interaction service rate per channel | services per hour |
| \(\mu_{\mathrm{extended}}\) | Extended interaction service rate per channel | services per hour |
| \(c\) | Number of identical service channels | count |
| \(a_{\mathrm{standard}}\) | Standard offered load | Erlangs |
| \(a_{\mathrm{extended}}\) | Extended offered load | Erlangs |
| \(a\) | Total offered load | Erlangs |
| \(\rho\) | Channel utilization | unit interval when stable |
| \(P_{\mathrm{wait}}\) | Probability that an arrival waits | unit interval |
| \(W_q\) | Expected shared queue delay | hours |
| \(W_{\mathrm{standard}}\) | Expected standard total interaction time | hours |
| \(W_{\mathrm{extended}}\) | Expected extended total interaction time | hours |
| \(W_{\mathrm{extended,max}}\) | Maximum declared extended total interaction time | hours |
| \(C_{\mathrm{extended}}\) | Extended-class service continuity indicator | 0 or 1 |

## Offered load

The offered load for the standard class is:

\[
a_{\mathrm{standard}} =
\frac{
\lambda_{\mathrm{standard}}
}{
\mu_{\mathrm{standard}}
}
\]

The offered load for the extended class is:

\[
a_{\mathrm{extended}} =
\frac{
\lambda_{\mathrm{extended}}
}{
\mu_{\mathrm{extended}}
}
\]

The total offered load is:

\[
a =
a_{\mathrm{standard}}
+
a_{\mathrm{extended}}
\]

Equivalently:

\[
a =
\frac{
\lambda_{\mathrm{standard}}
}{
\mu_{\mathrm{standard}}
}
+
\frac{
\lambda_{\mathrm{extended}}
}{
\mu_{\mathrm{extended}}
}
\]

The offered load unit is Erlangs, representing the average number of continuously occupied service channels implied by demand.

## Utilization and stability

For \(c\) channels, utilization is:

\[
\rho =
\frac{
a
}{
c
}
\]

The shared service panel is stable only when:

\[
\rho < 1
\]

When:

\[
\rho \ge 1
\]

the offered work equals or exceeds practical channel capacity. Under this condition, expected queue delay does not have a finite steady-state value in the M/M/c approximation.

The `popmath` result must therefore report:

```text
stable: false
probability_of_wait: 1.0
extended_service_continuity: 0.0
```

The output remains visible for explanation and capacity planning, but it must not be represented as a stable service level.

## Equivalent service rate

The two classes have different mean service durations:

\[
\mathbb{E}[S_{\mathrm{standard}}] =
\frac{
1
}{
\mu_{\mathrm{standard}}
}
\]

\[
\mathbb{E}[S_{\mathrm{extended}}] =
\frac{
1
}{
\mu_{\mathrm{extended}}
}
\]

The total arrival rate is:

\[
\lambda_{\mathrm{total}} =
\lambda_{\mathrm{standard}}
+
\lambda_{\mathrm{extended}}
\]

The arrival-weighted mean service duration is:

\[
\mathbb{E}[S] =
\frac{
\lambda_{\mathrm{standard}}
}{
\lambda_{\mathrm{total}}
}
\frac{
1
}{
\mu_{\mathrm{standard}}
}
+
\frac{
\lambda_{\mathrm{extended}}
}{
\lambda_{\mathrm{total}}
}
\frac{
1
}{
\mu_{\mathrm{extended}}
}
\]

The equivalent exponential service rate is:

\[
\mu_{\mathrm{equivalent}} =
\frac{
1
}{
\mathbb{E}[S]
}
\]

Since:

\[
a =
\lambda_{\mathrm{total}}
\mathbb{E}[S]
\]

the equivalent rate can also be written as:

\[
\mu_{\mathrm{equivalent}} =
\frac{
\lambda_{\mathrm{total}}
}{
a
}
\]

This preserves total offered load:

\[
\frac{
\lambda_{\mathrm{total}}
}{
\mu_{\mathrm{equivalent}}
}
=
a
\]

## Erlang-C waiting probability

For a stable queue, the probability that an arriving interaction must wait is:

\[
P_{\mathrm{wait}} =
\frac{
\frac{
a^c
}{
c!
\left(
1-\rho
\right)
}
}{
\sum_{n=0}^{c-1}
\frac{
a^n
}{
n!
}
+
\frac{
a^c
}{
c!
\left(
1-\rho
\right)
}
}
\]

This is the Erlang-C waiting probability for the equivalent shared service system.

## Expected queue delay

The expected shared queue delay is:

\[
W_q =
\frac{
P_{\mathrm{wait}}
}{
c\mu_{\mathrm{equivalent}}
-
\lambda_{\mathrm{total}}
}
\]

Because:

\[
c\mu_{\mathrm{equivalent}}
-
\lambda_{\mathrm{total}}
>
0
\]

whenever:

\[
\rho < 1
\]

the queue delay is finite for stable systems.

## Class-specific total interaction time

The expected total time for a standard interaction is:

\[
W_{\mathrm{standard}} =
W_q
+
\frac{
1
}{
\mu_{\mathrm{standard}}
}
\]

The expected total time for an extended interaction is:

\[
W_{\mathrm{extended}} =
W_q
+
\frac{
1
}{
\mu_{\mathrm{extended}}
}
\]

When:

\[
\mu_{\mathrm{extended}}
<
\mu_{\mathrm{standard}}
\]

the extended class has a longer expected service duration:

\[
W_{\mathrm{extended}}
>
W_{\mathrm{standard}}
\]

for the same shared queue delay.

## Extended-class continuity

The extended-class continuity indicator is:

\[
C_{\mathrm{extended}} =
\begin{cases}
1, &
\rho < 1
\land
W_{\mathrm{extended}}
\le
W_{\mathrm{extended,max}}
\\
0, &
\text{otherwise}
\end{cases}
\]

This is a per-time-bin indicator. It establishes whether the panel is stable and whether the extended interaction class meets the declared service-time threshold.

For multiple planning time bins \(b\), each with duration \(\Delta t_b\), aggregate continuity is:

\[
C_{\mathrm{extended,overall}} =
\frac{
\sum_b
\Delta t_b
\cdot
C_{\mathrm{extended},b}
}{
\sum_b
\Delta t_b
}
\]

The longest extended-service disruption is the longest consecutive period in which:

\[
C_{\mathrm{extended},b} = 0
\]

This longest-gap value can be represented through `continuity::CapabilityWindow` instances using a service-capacity capability.

## Worked synthetic example

Use a two-channel public service panel:

| Input | Value |
|---|---:|
| \(\lambda_{\mathrm{standard}}\) | 8 arrivals/hour |
| \(\lambda_{\mathrm{extended}}\) | 2 arrivals/hour |
| \(\mu_{\mathrm{standard}}\) | 12 services/hour/channel |
| \(\mu_{\mathrm{extended}}\) | 4 services/hour/channel |
| \(c\) | 2 channels |
| \(W_{\mathrm{extended,max}}\) | 0.50 hours |

### Offered loads

\[
a_{\mathrm{standard}} =
\frac{
8
}{
12
}
=
0.6667
\]

\[
a_{\mathrm{extended}} =
\frac{
2
}{
4
}
=
0.5
\]

\[
a =
0.6667
+
0.5
=
1.1667
\]

### Utilization

\[
\rho =
\frac{
1.1667
}{
2
}
=
0.5833
\]

Since:

\[
0.5833 < 1
\]

the panel is stable.

### Equivalent service rate

\[
\lambda_{\mathrm{total}} =
8+2
=
10
\]

\[
\mu_{\mathrm{equivalent}} =
\frac{
10
}{
1.1667
}
=
8.5714
\]

### Erlang-C waiting probability

\[
P_{\mathrm{wait}}
=
\frac{
\frac{
1.1667^2
}{
2!(1-0.5833)
}
}{
1
+
1.1667
+
\frac{
1.1667^2
}{
2!(1-0.5833)
}
}
\]

\[
P_{\mathrm{wait}}
\approx
0.4295
\]

### Expected queue delay

\[
W_q =
\frac{
0.4295
}{
2(8.5714)-10
}
\]

\[
W_q
\approx
0.0603\text{ hours}
\]

\[
W_q
\approx
3.62\text{ minutes}
\]

### Standard total interaction time

\[
W_{\mathrm{standard}} =
0.0603
+
\frac{
1
}{
12
}
\]

\[
W_{\mathrm{standard}}
\approx
0.1436\text{ hours}
\]

\[
W_{\mathrm{standard}}
\approx
8.62\text{ minutes}
\]

### Extended total interaction time

\[
W_{\mathrm{extended}} =
0.0603
+
\frac{
1
}{
4
}
\]

\[
W_{\mathrm{extended}}
\approx
0.3103\text{ hours}
\]

\[
W_{\mathrm{extended}}
\approx
18.62\text{ minutes}
\]

Because:

\[
0.3103
\le
0.50
\]

the extended-service continuity indicator is:

\[
C_{\mathrm{extended}} = 1
\]

## Rust mapping

The corresponding `popmath` input is:

```rust
use popmath::bounds::{NonNegativeF64, PositiveF64};
use popmath::queues::{
    calculate_two_class_queue_service_level,
    TwoClassQueueServiceLevelInput,
};

let result = calculate_two_class_queue_service_level(
    TwoClassQueueServiceLevelInput {
        standard_arrival_rate_per_hour: NonNegativeF64::new(8.0)?,
        extended_arrival_rate_per_hour: NonNegativeF64::new(2.0)?,
        standard_service_rate_per_hour: PositiveF64::new(12.0)?,
        extended_service_rate_per_hour: PositiveF64::new(4.0)?,
        channel_count: 2,
        maximum_extended_total_time_hours: NonNegativeF64::new(0.50)?,
    },
)?;

assert!(result.stable);
assert!(result.utilization.value() < 1.0);
assert!(result.expected_extended_total_time_hours.value() <= 0.50);
assert_eq!(result.extended_service_continuity.value(), 1.0);
```

## Result interpretation

The queue calculation should report:

| Result field | Meaning |
|---|---|
| `standard_offered_load` | Required standard-class channel load in Erlangs |
| `extended_offered_load` | Required extended-class channel load in Erlangs |
| `total_offered_load` | Combined offered load |
| `utilization` | Fraction of total channel capacity required |
| `probability_of_wait` | Likelihood an arrival encounters a busy panel |
| `expected_queue_wait_hours` | Shared expected wait before service begins |
| `expected_standard_total_time_hours` | Expected standard interaction time including waiting |
| `expected_extended_total_time_hours` | Expected extended interaction time including waiting |
| `extended_service_continuity` | Per-bin indicator of stable and threshold-compliant extended service |
| `stable` | Whether steady-state queue assumptions hold |

## Assumptions and limits

The model is a deterministic planning approximation.

- It uses equal priority across standard and extended interactions.
- It approximates a mixture of exponential service rates through one equivalent rate for shared waiting calculations.
- It reports separate total interaction times after calculating the shared queue delay.
- It is most useful for scenario comparison, service-channel sizing, and continuity screening.
- A later discrete-event simulation module can refine the model with time-varying arrivals, appointment schedules, abandonment, service interruptions, and additional interaction classes.

The model remains valuable before those refinements because it makes the principal capacity tradeoffs explicit:

\[
\lambda_{\mathrm{extended}} \uparrow
\Rightarrow
a_{\mathrm{extended}} \uparrow
\Rightarrow
\rho \uparrow
\Rightarrow
W_q \uparrow
\Rightarrow
W_{\mathrm{extended}} \uparrow
\]

This creates a direct, transparent relationship between extended interaction demand, service capacity, expected delay, and continuity status.

## Reproducibility

A queue result is reproducible when the following declared values remain unchanged:

- Standard arrival rate
- Extended arrival rate
- Standard service rate
- Extended service rate
- Channel count
- Extended total-time threshold
- Time-bin duration, when aggregating continuity across bins
- `popmath` crate version
- Queue-model formula version
