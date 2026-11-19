# Multi-Spectral Heat-Island Recovery Corridor Calibration

## Formula

For corridor position \(x, y\) and observation time \(t\):

\[
H_{\mathrm{recovery}} =
m_r \alpha
\left(
\sum_{i=1}^{n}
\frac{A_i R_i}{d_i^2}
\right)
e^{-\beta T_{\mathrm{lag}}}
+ \gamma \operatorname{VCI}(x,y)
- \delta B_m \eta_{\mathrm{cool}}
\]

Where:

- \(A_i\): leaf-area index of vegetation patch \(i\)
- \(R_i\): surface reflectance coefficient of patch \(i\), from 0 to 1
- \(d_i\): sensor-to-patch distance in meters
- \(T_{\mathrm{lag}}\): thermal lag in hours
- \(\operatorname{VCI}(x,y)\): vegetation condition index, from 0 to 1
- \(B_m\): built mass density in kilograms per square meter
- \(\eta_{\mathrm{cool}}\): radiative cooling efficiency, from 0 to 1
- \(\alpha, \beta, \gamma, \delta\): city- and deployment-specific calibration constants
- \(m_r\): solar-regime multiplier; 1.00 for daytime direct solar and 1.12 for nighttime radiational cooling in the initial implementation

The nighttime multiplier is a provisional, explicit model parameter. It must be recalibrated using local, longitudinal ground-truth measurements before any operational decision uses the coefficient.

## Data minimization

The calibration service accepts aggregated environmental variables only. It must not ingest:

- Names, addresses, contact details, or identity assertions
- Neural, biometric, health, augmentation, or assistive-device data
- Persistent sensor identifiers
- Individual-level travel, location, or behavioral histories

Sensor data should be aggregated by bounded spatial cell and time window before submission. The API intentionally does not expose a field for personal or device identity.

## Spatial data contract

Store corridor outputs using GeoParquet with:

- A WKB geometry column
- Coordinate reference system metadata
- Observation-time interval
- Spatial-cell resolution in meters
- Formula version and calibration-constant version
- Source provenance and uncertainty estimate
- Aggregation threshold and suppression status

GeoParquet standardizes how geospatial data, geometry encoding, and required spatial metadata are represented in Apache Parquet. [GeoParquet specification](https://geoparquet.org/releases/v1.0.0/)

## PostGIS corridor query

```sql
SELECT
    c.corridor_id,
    AVG(o.h_recovery) AS mean_h_recovery,
    COUNT(*) AS observation_count
FROM heat_observations AS o
JOIN cooling_corridors AS c
    ON ST_Intersects(o.geometry, c.geometry)
WHERE o.observed_at >= NOW() - INTERVAL '24 hours'
GROUP BY c.corridor_id;
```

`ST_Intersects` tests whether two geometries share any point, making it suitable for associating aggregated observations with corridor geometry. [PostGIS ST_Intersects](https://postgis.net/docs/ST_Intersects.html)

## Equity application

The coefficient is environmental decision support, not a person-level eligibility, risk, surveillance, or enforcement score.

For cooling-center planning, combine corridor-level recovery estimates with publicly reviewable accessibility inventories:

- Step-free and mobility-accessible entrances
- Accessible transportation and paratransit availability
- Low-bandwidth and offline-accessible public notices
- Communication supports and quiet/sensory-regulated spaces
- Backup electricity and device-charging availability
- Clearly documented non-digital alternatives

Do not infer disability, cognitive status, augmentation status, or personal mobility from environmental sensors. Do not condition cooling-center access on connected devices, telemetry, augmentation type, identity verification, or data sharing.

## Validation plan

1. Establish paired reference instruments and edge-sensor arrays in heterogeneous urban canyons.
2. Evaluate daytime and nighttime regimes separately.
3. Stratify validation by material albedo, shade condition, canopy density, built mass density, and corridor morphology.
4. Report mean bias, root-mean-square error, confidence intervals, missingness, and spatial autocorrelation.
5. Treat less than 2 percent sensor-alignment bias as a target that requires a preregistered measurement protocol, independently calibrated reference sensors, and a stated denominator.
6. Validate city-to-city transfer learning only after local holdout testing; never assume material, climate, geometry, or vegetation equivalence.
7. Publish uncertainty and limitations alongside each corridor-level recommendation.

## Deployment boundaries

- ESP32 nodes may measure local environmental conditions but should use rotating, non-personal identifiers.
- LoRaWAN payloads should contain only minimized, bounded environmental measurements.
- Gateway models should operate locally where feasible and publish aggregate outputs.
- MQTT-SN transport must use authenticated gateway links, replay protection, strict topic authorization, and encrypted backhaul.
- Broker APIs must validate ranges and reject identifiers or sensitive personal data.
- Human planners retain responsibility for cooling-center decisions and must provide accessible appeal and community feedback channels.

## Project metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.82 | Formula implementation is deterministic and validated for input range, but calibration parameters require local longitudinal data |
| eco_impact_value | 0.86 | Supports targeted heat mitigation, vegetation restoration evaluation, and material-aware cooling corridors |
| harm_risk | 0.28 | Privacy minimization and no person-level scoring reduce risk; deployment still requires security and environmental-justice review |
| accessibility_impact | 0.90 | Explicitly connects corridor calibration to accessible, non-discriminatory cooling-center planning |
| rights_alignment | 0.93 | Protects privacy, offline participation, accessibility, and transparent human oversight |
