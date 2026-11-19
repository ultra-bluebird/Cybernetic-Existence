# Cyboquatic Phoenix Heat Research Notes

## Scope

This document defines three research objects for a Phoenix-focused Cyboquatic
heat-resilience program:

1. A Cooling Benefit-Cost Ratio that compares verified heat protection against
   reclaimed-water consumption and lifecycle carbon.
2. A method to empirically select the minimum H3 resolution that meets a
   pre-registered urban-microclimate prediction target.
3. A privacy-preserving edge-to-cloud sensor-validation architecture.

The artifacts are decision support. They do not authorize reclaimed-water release,
weather modification, service exclusion, or automated actions affecting people.

## Cooling Benefit-Cost Ratio

### Proposed index

The preliminary Cyboquatic Cooling Benefit-Cost Ratio is:

    CCBCR =
        (AWH * P_eq)
        /
        (V_cons * CI_lifecycle)

Where:

- AWH is avoided weighted heat-exposure hours.
- P_eq is equity-weighted protected population.
- V_cons is reclaimed-water volume consumed.
- CI_lifecycle is lifecycle carbon attributable to the intervention.

The unnormalized expression in this form is not dimensionless:

    AWH has person-hours.
    P_eq has persons or population-weight units.
    V_cons has cubic meters.
    CI_lifecycle has kilograms carbon-dioxide equivalent.

A scientific comparison index must normalize each quantity to a transparent
reference condition.

### Dimensionless research index

Define:

    B_heat = AWH / AWH_ref

    B_equity = P_eq / P_ref

    C_water = V_cons / V_ref

    C_carbon = CI_lifecycle / CI_ref

    CCBCR_dimensionless = (B_heat * B_equity) / (C_water * C_carbon)

A value above 1.0 means the scenario outperforms the reference scenario under
the selected, published reference values. It does not mean the project is
automatically acceptable; all water-quality, equity, health, ecological-flow,
and governance gates remain mandatory.

### Operational definitions for Phoenix reclaimed water

AWH: avoided weighted heat-exposure hours

For person p during measurement interval t:

    E_p,t = max(0, WBGT_p,t - WBGT_threshold_p)

    AWH = sum_p sum_t [
        (E_baseline_p,t - E_intervention_p,t)
        * exposure_hours_t
        * occupancy_weight_p,t
    ]

Use WBGT or a separately justified heat-health metric. Do not substitute
dry-bulb temperature alone.

P_eq: equity-weighted protected population

    P_eq = sum_p [
        presence_weight_p
        * heat_vulnerability_weight_p
        * access_weight_p
    ]

The system must calculate this from privacy-preserving area-level categories,
not personal identity or individual tracking. Values should be developed through
community governance and published before analysis.

V_cons: reclaimed-water volume consumed

    V_cons =
        V_withdrawn
        - V_recovered
        - V_returned_to_authorized_system
        - V_verified_recharge_credit

Only a verified, permitted non-potable reclaimed-water source may be used.
Water reserved for essential access, ecological flow, public-health requirements,
or drought resilience is excluded from available volume.

CI_lifecycle: lifecycle carbon

    CI_lifecycle =
        C_treatment
        + C_pumping
        + C_disinfection
        + C_embodied_materials
        + C_maintenance
        - C_verified_displaced_emissions

For an operational reporting period, report both:

    CI_total: kg CO2e

and

    CI_per_m3: kg CO2e / m3

A project must document electricity source, treatment energy, pumping head,
equipment manufacturing assumptions, maintenance, and any avoided emissions.

### Required gates

The CCBCR is reported only when:

- water quality is approved for the specific beneficial use;
- no aerosolization pathway creates unverified public-health exposure;
- public cooling access does not require identity, telemetry, payment, or
  continuous connectivity;
- WBGT and humidity burdens are monitored;
- the source-water allocation is protected after essential and ecological needs;
- uncertainty is reported for every numerator and denominator;
- a matched baseline exists.

## H3 Resolution Research Question

The question cannot be answered from boundary-layer depth alone.

A convective boundary-layer depth of 2–4 km describes vertical mixing. H3
resolution describes horizontal geographic aggregation. The minimum usable H3
resolution must therefore be estimated from observed spatial thermal variability,
sensor density, time of day, urban morphology, and the prediction task.

The required claim is:

    Find the coarsest H3 resolution r for which the held-out
    spatial-temporal mean absolute error is below 0.5 degrees Celsius.

For every candidate resolution r:

    MAE_r =
        (1 / N_r) * sum_i abs(T_predicted_i,r - T_observed_i)

Choose:

    r_star = min {
        r : MAE_r < 0.5 degrees Celsius
        and coverage_r >= coverage_minimum
        and uncertainty_upper_r <= uncertainty_limit
    }

Where:

- T_observed is calibrated air temperature, WBGT, land-surface temperature, or
  another explicitly named target variable.
- T_predicted is produced without access to held-out observations.
- coverage_r measures whether cells have enough independent observations.
- uncertainty_upper_r is a confidence or posterior bound defined before testing.

The H3 grid is hierarchical, and cell areas change with resolution and location.
Use actual cell geometry for the Phoenix study domain rather than relying solely
on global average area tables.

### Study design

1. Establish a calibrated reference network across shade, pavement, irrigated
   landscape, industrial land, transit areas, dense residential districts,
   riparian zones, and public cooling sites.

2. Collect multi-season observations at a fixed sampling interval, including
   air temperature, humidity, globe temperature or radiant proxy, wind,
   surface temperature, shade fraction, and sensor quality status.

3. Assign every measurement to H3 resolutions selected before analysis.

4. Perform blocked validation:
   - hold out entire sensors;
   - hold out entire days;
   - hold out heat-event periods;
   - hold out spatial clusters.

5. Compare simple and interpretable models before complex models:
   - cell mean;
   - inverse-distance interpolation;
   - land-cover and shade regression;
   - physically informed urban-temperature model.

6. Report MAE, bias, 95 percent uncertainty, coverage, and failure conditions
   per H3 resolution and weather regime.

7. Select the coarsest resolution that meets the target in all pre-registered
   high-priority regimes. Do not select a resolution that only performs well
   during mild weather.

## Edge-to-Cloud Data Protection

### Privacy rule

No raw personal data leaves local nodes.

The telemetry plane carries environmental and equipment measurements only.
Any optional local accessibility feedback is transformed locally into aggregated,
threshold-protected counts before publication. Direct identifiers, faces, voice,
device identifiers, precise trajectories, biometric data, neural data, and
individual behavior profiles are prohibited.

### Tiered flow

1. Sensor tier
   - Collects environmental, water, energy, and equipment-state observations.

2. Edge validation tier
   - Performs range, rate-of-change, unit, calibration, clock, and invariant
     checking.
   - Rejects malformed or unsafe records.
   - Produces privacy-preserving aggregate packets.

3. Secure telemetry tier
   - Publishes validated packets by MQTT over mutual TLS.
   - Uses allowlisted topics and per-device credentials.

4. Event tier
   - A bridge validates topic-to-event-schema mapping and writes to Kafka.
   - Kafka carries only validated, aggregate event records.

5. Storage tier
   - A consumer writes immutable raw-environment aggregate records and
     derived metrics to TimescaleDB.
   - Retention is bounded by purpose, audit requirement, and public-interest
     research approval.

6. Research and civic tier
   - Dashboards show accessible, uncertainty-aware results.
   - Deployment and water-release decisions retain human, community, and
     regulatory review.

## Metrics

knowledge_factor: 0.86
Basis: the formulas use dimensional analysis, pre-registered validation, and
bounded sensor processing; the Phoenix-specific thresholds require field data.

eco_impact_value: 0.90
Basis: the artifacts prioritize heat safety, reclaimed-water accountability,
ecosystem protection, and measured comparison against alternatives.

harm_risk: 0.22
Basis: main residual risks are water misallocation, bad sensors, unrepresentative
sampling, and metric misuse. Corridor gates, uncertainty, and review reduce risk.

accessibility_impact: 0.91
Basis: accessible heat-benefit measurement and aggregate-only data collection
support inclusive public cooling without surveillance.

rights_alignment: 0.94
Basis: explicit data minimization, non-coercive access, community review,
auditability, and ecological-flow protections are built into the framework.
