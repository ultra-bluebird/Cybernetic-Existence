# Fair Decentralized Sensor Calibration Protocol

## Purpose

This protocol ensures that temperature, air-quality, and noise sensors remain accurate, comparable, maintainable, and equitably distributed across heterogeneous neighborhoods.

The protocol treats sensor quality as a public-service obligation. It must not use environmental monitoring to infer personal identity, immigration status, health status, behavior, residence, or eligibility for public services. It must not convert environmental observations into a policing, enforcement, or social-scoring system.

## Calibration Principles

- Every district receives a published minimum monitoring and maintenance service level.
- Calibration priority is determined by uncertainty, environmental burden, equipment condition, uptime, and coverage equity, not political power, property value, complaint volume, or surveillance interest.
- Each sensor has a documented calibration lineage, including reference method, environmental conditions, uncertainty estimate, maintenance history, and current validity window.
- Sensor readings remain environmental measurements. They are not personal telemetry.
- Raw audio must not be retained for noise monitoring. Noise systems should derive short aggregation windows such as equivalent continuous sound level and delete source audio immediately in volatile memory.
- Final calibration, data-release, and resource-allocation decisions require accountable human review.
- A blockchain or append-only ledger stores tamper-evident commitments and review events, not personal data, exact household locations, raw audio, network credentials, or private maintenance notes.

## Local Calibration Cells

A city-wide network is divided into Local Calibration Cells. Each cell contains:

- One or more reference-grade or institutionally traceable reference stations.
- A rotating cohort of field sensors.
- A local maintenance and accessibility liaison.
- A public dashboard showing aggregate uptime, calibration age, uncertainty, and planned service window.
- A calibration record publisher that writes hashes of signed calibration records to the audit ledger.

Cells should be constructed by microclimate, sensor exposure class, and maintenance logistics rather than by neighborhood prestige. A low-income, low-power-reliability, or historically under-invested area must not be assigned a lower calibration standard.

## Calibration Schedule

Every sensor receives three layers of calibration.

| Layer | Trigger | Action |
|---|---|---|
| Initial collocation | Before deployment or after major repair | Operate beside a traceable reference instrument under representative conditions; estimate bias, variance, and environmental sensitivity |
| Routine distributed check | Scheduled by uncertainty and elapsed time | Use a mobile reference kit or rotating calibrated transfer sensor to check field performance across all cells |
| Exception recalibration | Drift, outage, environmental mismatch, tamper indication, or maintenance event | Mark data as provisional, inspect the device, recalibrate or replace it, and publish a review event |

Collocation and periodic quality checks are established quality-assurance practices for air sensors because they quantify accuracy and detect drift over time and under changing environmental conditions. EPA guidance identifies collocation, correction, maintenance, automatic checks, and data review as components of sensor quality control. [68] A rotating “golden sensor,” mobile reference, or routine collocation strategy can provide network-wide checks while avoiding concentration of calibration resources in a few favored sites. [71]

### Fair Priority Function

For sensor \(s\) in district \(d\), define calibration priority:

\[
P_{s,t}
=
0.28U_{s,t}
+
0.22D_{s,t}
+
0.20G_{d,t}
+
0.15F_{s,t}
+
0.15X_{d,t}
\]

Where:

- \(U_{s,t}\) is normalized measurement uncertainty.
- \(D_{s,t}\) is normalized estimated drift since the last successful calibration.
- \(G_{d,t}\) is the district coverage gap.
- \(F_{s,t}\) is the elapsed calibration-freshness deficit.
- \(X_{d,t}\) is the infrastructure-access burden, including power unreliability, safe maintenance travel time, and repair delay.

All terms are bounded from zero to one.

The coverage gap is:

\[
G_{d,t}
=
\operatorname{clip}
\left(
\frac{
M_{\mathrm{target}} - M_{d,t}
}
{M_{\mathrm{target}} + \epsilon},
0,
1
\right)
\]

Where \(M_{d,t}\) is effective monitoring coverage and \(M_{\mathrm{target}}\) is the published minimum service floor.

A larger infrastructure-access burden increases service priority. It must never be used as a reason to defer repair or reduce monitoring.

## Decentralized Schedule

Each weekly planning cycle allocates available calibration capacity in this order:

- Reserve a minimum service allocation for every Local Calibration Cell.
- Select the highest-priority sensors within each cell until its baseline is met.
- Allocate remaining capacity by the fair priority function.
- Enforce a maximum interval between calibrations for every sensor class.
- Publish the schedule, uncertainty map, and coverage-equity result in accessible formats.
- Allow community correction requests for missed service, inaccurate sensor location metadata, accessibility barriers, or unsafe installation conditions.

The protocol must maintain an explicit anti-concentration invariant:

\[
M_{d,t} \ge M_{\mathrm{floor}}
\quad
\text{for every district } d
\]

No discretionary deployment, removal, or maintenance deferral may cause the invariant to fail.

## Audit Ledger Commitments

For each calibration event, create a canonical signed record containing:

- Sensor pseudonym.
- Sensor class and measured modality.
- Calibration method.
- Calibration start and end time.
- Reference instrument class and traceability record.
- Environmental condition bands, such as temperature and humidity ranges.
- Calibration-model version.
- Bias and uncertainty summary.
- Validity interval.
- Maintenance action category.
- Reviewer authorization.
- Previous record hash.

The ledger stores:

\[
h_t = \operatorname{SHA256}(\operatorname{canonicalize}(r_t) \parallel h_{t-1})
\]

Where \(r_t\) is the signed calibration record and \(h_{t-1}\) is the previous commitment hash.

The operational record remains in an access-controlled system. The public ledger holds only its cryptographic commitment, status class, time window, model version, uncertainty band, and aggregated cell-level coverage measures.

## Drift and Comparability

Sensor output should be treated as provisional when any of the following occurs:

- Calibration validity has expired.
- Drift exceeds the approved modality-specific threshold.
- Reference comparison fails.
- Time synchronization fails.
- A power interruption creates unresolved data gaps.
- A firmware change changes measurement behavior.
- An environmental exposure condition falls outside the calibration model’s supported range.

A provisional status does not mean a neighborhood is ignored. It triggers priority repair, local communication, and alternative temporary coverage.

## Oversight and Community Rights

Residents and community organizations may:

- Inspect aggregate sensor coverage, uptime, calibration age, uncertainty, and service schedules.
- Request an accessibility review of sensor placement or public dashboard format.
- Report environmental data concerns without providing unrelated identity information.
- Challenge unequal service or maintenance patterns.
- Request a plain-language explanation of a calibration result or data-quality flag.

The city must publish an annual equity audit showing:

- Effective coverage by district.
- Calibration freshness by district.
- Data-quality uncertainty by district.
- Mean repair delay by district.
- Number of provisional-data intervals by district.
- Reallocation decisions and their written rationale.
- Whether any district fell below the monitoring floor.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.93 | Uses collocation, recurring quality control, drift tracking, reference comparison, and auditable records |
| eco_impact_value | 0.88 | Supports trustworthy heat, air-quality, and noise evidence for equitable environmental interventions |
| harm_risk | 0.18 | Reduced through data minimization, non-policing restrictions, human review, and anti-concentration safeguards |
| accessibility_impact | 0.94 | Requires accessible reporting, service floors, complaint pathways, and infrastructure-burden prioritization |
| rights_alignment | 0.96 | Centers non-discrimination, privacy, accountability, contestability, and community participation |
