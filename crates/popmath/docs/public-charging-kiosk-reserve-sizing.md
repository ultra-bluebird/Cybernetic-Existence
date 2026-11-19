# Public Charging Kiosk Reserve Sizing

This guide documents a deterministic, aggregate-statistics method for estimating the minimum nominal battery capacity required to support a public charging kiosk during grid outages.

The calculation is implemented by:

```text
popmath::kiosk_reserve::calculate_public_charging_kiosk_reserve
```

The method uses declared aggregate outage-duration statistics, service requirements, battery operating parameters, and a selected confidence level. It produces an advisory reserve capacity in kilowatt-hours and does not require person-level data, live utility access, or external services.

## Purpose

Public charging kiosks can be planned with a declared continuity target so that service availability remains resilient during an outage scenario.

The model answers:

- What outage duration should the kiosk reserve plan support at a selected one-sided confidence level?
- What nominal battery capacity is needed to support the declared critical load?
- What maximum interruption is consistent with a continuity-ratio target?
- Which assumptions determine the resulting capacity estimate?

The calculation is scenario support. It does not operate charging equipment, alter infrastructure, or make binding service decisions.

## Inputs

| Symbol | Rust field | Meaning | Unit |
|---|---|---|---|
| \(P_{\mathrm{load}}\) | `critical_load_kw` | Kiosk critical electrical load | kW |
| \(\mu_O\) | `mean_outage_hours` | Aggregate mean outage duration | hours |
| \(\sigma_O^2\) | `outage_variance_hours_squared` | Aggregate outage-duration variance | hours² |
| \(q\) | `confidence_level` | One-sided confidence level | unit interval |
| \(C_{\min}\) | `continuity_ratio` | Required service availability ratio | unit interval |
| \(T_{\mathrm{service}}\) | `service_window_hours` | Declared kiosk service period | hours |
| \(\eta_d\) | `discharge_efficiency` | Battery discharge efficiency | unit interval |
| \(\delta\) | `usable_depth_of_discharge` | Usable share of nominal battery capacity | unit interval |
| \(r\) | `reserve_margin` | Additional planning margin | unit interval |

All input values must be finite. Electrical load and service-window duration must be greater than zero. Confidence must be greater than zero and less than one. Battery discharge efficiency and usable depth of discharge must be greater than zero.

## Method

### Standard deviation

The outage-duration standard deviation is derived from the declared variance:

\[
\sigma_O = \sqrt{\sigma_O^2}
\]

### Conservative outage duration

With only aggregate mean and variance available, the model uses a one-sided Cantelli bound to derive a conservative planning duration:

\[
T_q =
\mu_O +
\sigma_O
\sqrt{
\frac{q}{1-q}
}
\]

This is a distribution-free upper-tail planning bound. Cantelli’s inequality gives the one-sided probability bound:

\[
\Pr(O - \mu_O \ge \lambda)
\le
\frac{
\sigma_O^2
}{
\sigma_O^2 + \lambda^2
}
\]

for \(\lambda > 0\). [265][266]

The calculation is intentionally explicit about its meaning: it is a conservative planning estimate derived from declared aggregate moments, not a claim that every individual outage will have the same duration.

### Required support duration

The battery need not be sized for longer than the declared service window:

\[
T_{\mathrm{required}} =
\min
\left(
T_{\mathrm{service}},
T_q
\right)
\]

### Maximum interruption under target continuity

For a service window \(T_{\mathrm{service}}\) and availability target \(C_{\min}\), the largest total interruption compatible with that target is:

\[
G_{\max} =
\left(
1-C_{\min}
\right)
T_{\mathrm{service}}
\]

### Nominal battery capacity

The required nominal battery capacity is:

\[
E_{\mathrm{nominal}} =
\frac{
P_{\mathrm{load}}
\cdot
T_{\mathrm{required}}
\cdot
(1+r)
}{
\eta_d
\cdot
\delta
}
\]

The energy-power relationship is:

\[
E = P \cdot t
\]

Battery duration is commonly represented as stored energy divided by delivered power, with the result expressed in hours. [264][269][272]

## Synthetic worked example

The following values are synthetic planning inputs.

| Input | Value |
|---|---:|
| \(P_{\mathrm{load}}\) | 2.0 kW |
| \(\mu_O\) | 1.0 hour |
| \(\sigma_O^2\) | 0.25 hour² |
| \(q\) | 0.90 |
| \(T_{\mathrm{service}}\) | 8.0 hours |
| \(\eta_d\) | 0.92 |
| \(\delta\) | 0.80 |
| \(r\) | 0.20 |
| \(C_{\min}\) | 0.999 |

### Step 1: Standard deviation

\[
\sigma_O =
\sqrt{0.25}
=
0.5\text{ hours}
\]

### Step 2: Conservative outage duration

\[
T_q =
1.0
+
0.5
\sqrt{
\frac{0.90}{1-0.90}
}
\]

\[
T_q =
1.0
+
0.5
\sqrt{9}
\]

\[
T_q =
1.0
+
0.5
\cdot
3
\]

\[
T_q =
2.5\text{ hours}
\]

### Step 3: Required supported duration

\[
T_{\mathrm{required}} =
\min(8.0, 2.5)
=
2.5\text{ hours}
\]

### Step 4: Maximum continuity-compatible gap

\[
G_{\max} =
(1-0.999)
\cdot
8.0
\]

\[
G_{\max} =
0.001
\cdot
8.0
\]

\[
G_{\max} =
0.008\text{ hours}
\]

\[
G_{\max} =
28.8\text{ seconds}
\]

### Step 5: Nominal battery capacity

\[
E_{\mathrm{nominal}} =
\frac{
2.0
\cdot
2.5
\cdot
(1+0.20)
}{
0.92
\cdot
0.80
}
\]

\[
E_{\mathrm{nominal}} =
\frac{
6.0
}{
0.736
}
\]

\[
E_{\mathrm{nominal}} =
8.152173913\text{ kWh}
\]

Rounded for scenario reporting:

\[
E_{\mathrm{nominal}} \approx 8.15\text{ kWh}
\]

## Rust usage

```rust
use popmath::bounds::{NonNegativeF64, UnitInterval};
use popmath::kiosk_reserve::{
    calculate_public_charging_kiosk_reserve,
    KioskReserveSizingInput,
};

let reserve = calculate_public_charging_kiosk_reserve(
    KioskReserveSizingInput {
        critical_load_kw: NonNegativeF64::new(2.0)?,
        mean_outage_hours: NonNegativeF64::new(1.0)?,
        outage_variance_hours_squared: NonNegativeF64::new(0.25)?,
        confidence_level: UnitInterval::new(0.90)?,
        continuity_ratio: UnitInterval::new(0.999)?,
        service_window_hours: NonNegativeF64::new(8.0)?,
        discharge_efficiency: UnitInterval::new(0.92)?,
        usable_depth_of_discharge: UnitInterval::new(0.80)?,
        reserve_margin: UnitInterval::new(0.20)?,
    },
)?;

assert!(
    (reserve.conservative_outage_hours.value() - 2.5).abs() < 1e-9
);

assert!(
    (reserve.required_support_hours.value() - 2.5).abs() < 1e-9
);

assert!(
    (reserve.maximum_allowed_gap_hours.value() - 0.008).abs() < 1e-9
);

assert!(
    (
        reserve.minimum_nominal_capacity_kwh.value().value()
        - 8.152_173_913
    )
    .abs()
    < 1e-6
);
```

## Output interpretation

The result object contains:

| Field | Interpretation |
|---|---|
| `conservative_outage_hours` | Outage-duration planning value derived from the selected confidence level |
| `required_support_hours` | Support duration after capping the outage estimate at the declared service window |
| `maximum_allowed_gap_hours` | Total interruption compatible with the requested continuity ratio |
| `minimum_nominal_capacity_kwh` | Nominal battery capacity before any additional technology-specific derating or deployment review |

For the synthetic example:

```text
conservative_outage_hours: 2.5
required_support_hours: 2.5
maximum_allowed_gap_hours: 0.008
minimum_nominal_capacity_kwh: 8.152173913
```

## Continuity integration

The reserve estimate can be used to define an energy support interval:

\[
T_{\mathrm{support}} =
\frac{
E_{\mathrm{available}}
\cdot
\eta_d
\cdot
\delta
}{
P_{\mathrm{load}}
}
\]

A continuity assessment should then compare the support interval with the declared service requirement:

\[
C_{\mathrm{energy}}
\ge
C_{\min}
\]

\[
G_{\max,\mathrm{energy}}
\le
G_{\max}
\]

The reserve-sizing result estimates capacity. The continuity module evaluates time-window availability, evidence status, redundancy, and longest service gap.

## Reproducibility contract

A reserve-sizing result is reproducible when all of the following are unchanged:

- `critical_load_kw`
- `mean_outage_hours`
- `outage_variance_hours_squared`
- `confidence_level`
- `continuity_ratio`
- `service_window_hours`
- `discharge_efficiency`
- `usable_depth_of_discharge`
- `reserve_margin`
- `popmath` crate version
- The selected formula version

A scenario result envelope should retain the input assumptions, calculation version, and reproducibility digest alongside the derived capacity.

## Local validation

Run the dedicated test suite from the repository root:

```powershell
cargo test -p popmath kiosk_reserve
```

Run the full crate test suite:

```powershell
cargo test -p popmath
```

Run formatting and lint checks:

```powershell
cargo fmt --check
cargo clippy -p popmath --all-targets -- -D warnings
```

## Scope

This artifact is a deterministic planning model based on aggregate outage statistics. It supports comparison of reserve options, continuity thresholds, load assumptions, and sensitivity ranges.

The output is not a hardware procurement specification, a prediction of any specific outage, or a substitute for deployment-specific electrical engineering review. It is a transparent mathematical input to the broader Population.Math scenario workflow.
