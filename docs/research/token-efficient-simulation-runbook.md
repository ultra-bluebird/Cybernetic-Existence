# Token-Efficient, Privacy-Safe Urban Simulation Runbook

## Purpose

This runbook supports compact, reproducible, aggregate-only urban simulation for public-interest planning, accessibility analysis, ecological resilience, and community review.

The simulation layer must not process BLE identifiers, personal location traces, household data, individual health data, identity information, augmentation information, cybernetic-host declarations, device identifiers, or behavioral profiles.

## Scenario Library Pattern

Use a precomputed scenario catalog for repeated “what happens if” questions.

Each scenario contains:

- A short scenario key.
- Domain and metric names.
- Aggregate input assumptions.
- Result value and uncertainty.
- Privacy classification.
- Method version.
- Limitations.
- `bleIdentityUsed: false`.
- `essentialServiceIndependentOfBle: true`.

Example:

```json
{
  "domain": "cooling_center",
  "scenario": "heatwave_cooling_centers_ble_off",
  "metric": "essential_service_availability",
  "value": 0.99,
  "unit": "proportion",
  "uncertainty": 0.02,
  "privacyClass": "synthetic_aggregate",
  "bleIdentityUsed": false,
  "essentialServiceIndependentOfBle": true,
  "methodVersion": "1.0.0",
  "limitations": [
    "Illustrative aggregate scenario.",
    "Not a real-time capacity guarantee."
  ],
  "privacyLeakageEstimate": 0.0,
  "jainFairnessIndex": 0.93
}
```

A compact catalog avoids rerunning high-detail simulation for every public query while preserving auditability through fixed assumptions, method versions, and uncertainty disclosure.

## Reduced-Order Models

Use reduced-order models when a decision needs an approximate aggregate result rather than a person-level simulation.

### Cooling-center demand

\[
\lambda_{\mathrm{demand}} =
\beta_0 +
\beta_1
\left(
T -
T_{\mathrm{reference}}
\right) +
\beta_2
V
\]

where:

- \(\lambda_{\mathrm{demand}}\) is expected aggregate demand rate.
- \(T\) is observed or forecast public temperature.
- \(T_{\mathrm{reference}}\) is a documented reference temperature.
- \(V\) is an aggregate planning vulnerability or access-gap indicator.
- \(\beta_0, \beta_1, \beta_2\) are documented coefficients fitted or selected from public and aggregate evidence.

The model must not use individual health records, identity, BLE identity, mobility traces, or household-level behavior.

### Anonymous M/M/1 request queue

For aggregate request arrival rate \(\lambda\) and service rate \(\mu\), with:

\[
0 \leq \lambda < \mu
\]

the mean queue wait is:

\[
W_q =
\frac{\lambda}
{\mu(\mu-\lambda)}
\]

A BLE button and a physical button can contribute to the same aggregate arrival process. The model must not track which person used which method.

### Essential-service denial independence

Let:

- \(C\) be available service capacity.
- \(D\) be aggregate demand.
- \(B\) be the BLE-enabled interaction share.

The capacity shortfall is:

\[
S =
\max(0, D-C)
\]

The BLE-independent denial-risk proxy is:

\[
P_{\mathrm{denial}} =
f(S)
\]

subject to:

\[
\frac{\partial P_{\mathrm{denial}}}{\partial B} = 0
\]

The condition means that BLE participation must not change a person's access to an essential service. BLE may change only an optional local interaction method, and every such method must have an equivalent non-BLE route.

## Source Rules

Permitted compact inputs:

- Public weather and environmental summaries.
- Public transit schedules.
- Public facility inventories.
- Aggregate service capacity.
- Aggregate planning-zone population counts.
- Fixed environmental sensor summaries.
- Synthetic distributions and reproducible random seeds.
- Community-reviewed aggregate access barriers.

Prohibited inputs:

- BLE identifiers or BLE signal histories.
- Wi-Fi identifiers, MAC addresses, IP addresses, DNS histories, or browser histories.
- Individual device, account, health, identity, disability, augmentation, assistive-technology, or cybernetic-host data.
- Household energy, location, mobility, transaction, or service-use traces.
- Raw audio, raw video, facial imagery, biometric information, or re-identification features.

## Validation Gate

Before a scenario is published or supplied to an AI system:

1. Verify that the scenario has no BLE identifier fields.
2. Verify `bleIdentityUsed` is `false`.
3. Verify `essentialServiceIndependentOfBle` is `true`.
4. Verify the privacy-leakage estimate is zero for the published simulation output.
5. Verify that uncertainty and limitations are non-empty.
6. Verify source data are public, synthetic, fixed-sensor aggregate, or otherwise rights-reviewed.
7. Verify that the simulation output is advisory and cannot trigger infrastructure control or a service-access decision.
8. Verify that the same conclusion is accessible through text, plain language, screen-reader-compatible data, print, and staff-assisted explanation.

## Local Commands

Run BLE policy tests:

```text
python -m unittest python/ble_privacy/test_ble_policy.py
```

Run simulation tests:

```text
python -m unittest python/urban_simulation/test_scenario_library.py
```
