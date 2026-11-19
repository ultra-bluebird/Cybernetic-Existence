# Shade Relief and Privacy-Preserving Wastewater Heat Recovery

## Purpose

This specification defines:

1. A public bench and shade-placement method based on microclimate, access, and aggregate use evidence.
2. A district wastewater heat-recovery planning model using aggregate sewer-flow and thermal measurements without household-level monitoring.

The systems are decision-support tools. They do not identify, track, rank, profile, or determine the worth of pedestrians, transit riders, residents, visitors, households, properties, or communities.

## Shared Rights Commitments

Both systems SHALL:

- Use public, fixed-sensor, aggregate, or synthetic planning data.
- Avoid Wi-Fi probe requests, Bluetooth signals, phone identifiers, camera analytics, facial recognition, and persistent pedestrian tracking.
- Avoid household-level sewer monitoring, household heat-use profiling, property-value prioritization, and individual utility records.
- Preserve public accessibility, shade, seating, water access, transit access, and cooling routes as first-class planning outputs.
- Publish assumptions, calibration state, uncertainty, ecological tradeoffs, and community-review status.
- Require human engineering and community review before physical installation, procurement, operational control, or public claims.
- Support repairable sensors, local diagnostics, signed updates, and maintenance-first workflows.
- Apply non-compensation constraints: high modeled cooling or energy benefit cannot offset a failed accessibility, ecological-feasibility, privacy, anti-displacement, or public-access requirement.

## Part One: Benches and Shade

### Do Not Use Wi-Fi Probe Requests

Wi-Fi probe requests are not an appropriate default source for pedestrian-flow estimation in a rights-centered public-space project.

Probe requests can expose device-level metadata. Even when client MAC addresses are randomized, a device may be recognizable during a scan session, and protocol information can create fingerprinting or correlation risk. [221][222][225][229]

The system SHALL NOT:

- Collect Wi-Fi probe requests.
- Retain MAC addresses, randomized MAC addresses, SSIDs, Wi-Fi information elements, radio fingerprints, device counts derived from persistent clusters, or signal-strength histories.
- Use Wi-Fi infrastructure to infer pedestrian presence, dwell time, recurrence, route, demographic characteristic, disability, cybernetic-host status, or service need.
- Measure demand by identifying devices or requiring mobile participation.

### Privacy-Safe Use Evidence

Use one or more of the following instead:

| Method | Data retained | Privacy posture | Use |
|---|---|---|---|
| Fixed environmental measurements | Air temperature, humidity, wind, radiation, surface temperature, shade state | No person sensing | Heat exposure and cooling-benefit estimation |
| Public facility and transit inventories | Stop location, route schedule, public water, restroom, shade, bench, crossing data | Public infrastructure only | Access-gap analysis |
| Scheduled manual counts | Aggregate count bucket from trained observer | No names, photos, device data, or repeated person tracking | Time-of-day demand estimation |
| Voluntary community walk audits | Barrier and comfort observations with anonymous receipt | No required account or location history | Local lived-experience evidence |
| Infrared crossing counters | Aggregate directionless count, immediately coarsened | No image or device capture | Coarse pedestrian-volume signal |
| Pressure or occupancy strip | Aggregate crossing event count | No weight profile or trajectory retention | Public-path use estimation |
| Transit-boardings aggregate | Route-level totals only | No rider-level history | Transfer and waiting-area demand |
| Scenario simulation | Synthetic arrival rates and route demand | No personal data | Comparative planning under heat and event conditions |

Manual counts should be performed as aggregate, time-bucketed observations. Observers must not record appearance, identity, device use, presumed health, mobility category, or any persistent descriptor.

### UTCI-Based Comfort Planning

The Universal Thermal Climate Index combines air temperature, humidity, wind speed, and radiation into a temperature-like indicator of outdoor thermal stress. [223][230]

Let:

- \(T_a\): air temperature.
- \(RH\): relative humidity.
- \(v\): wind speed.
- \(T_{mrt}\): mean radiant temperature.
- \(UTCI\): modeled thermal-stress index.

\[
UTCI =
f(T_a, RH, v, T_{mrt})
\]

The target for shaded public resting areas is:

\[
UTCI < 26^\circ\mathrm{C}
\]

for at least:

\[
90\%
\]

of defined daytime operating hours during the relevant planning period.

The \(26^\circ\mathrm{C}\) threshold corresponds to the start of the UTCI moderate-heat-stress range; the range from \(9^\circ\mathrm{C}\) to \(26^\circ\mathrm{C}\) is categorized as no thermal stress in published UTCI category guidance. [230][233]

This is a planning objective, not a guarantee of individual comfort or medical safety. Public-space planning must also provide water, rest, accessible routes, clear information, and indoor cooling referrals during high-heat conditions.

### Shade Placement Score

For candidate location \(k\), define:

- \(H_k\): normalized heat-exposure burden.
- \(A_k\): normalized access gap to shade, seating, water, cooling, transit, and rest.
- \(U_k\): privacy-safe aggregate use estimate.
- \(C_k\): modeled UTCI reduction or comfort benefit.
- \(E_k\): ecological compatibility score.
- \(M_k\): maintenance and repair feasibility score.
- \(D_k\): displacement or exclusion risk.
- \(R_k\): rights and accessibility risk.
- \(u_k\): uncertainty penalty.

The preliminary planning score is:

\[
S_k =
0.40H_k +
0.25A_k +
0.15U_k +
0.10C_k +
0.05E_k +
0.05M_k
\]

The uncertainty-adjusted score is:

\[
S_{k,\mathrm{adjusted}} =
S_k(1-u_k)
\]

A location may advance only when:

\[
D_k \leq D_{\max}
\]

\[
R_k \leq R_{\max}
\]

\[
u_k \leq u_{\max}
\]

No modeled cooling benefit can compensate for blocking an accessible route, removing public seating without replacement, displacing people, reducing water access, creating an unsafe crossing, or increasing surveillance.

### Bench and Shade Requirements

Each approved shade-relief site should include:

- Shade coverage designed for actual solar geometry during the highest-risk hours.
- Integrated seating with backs, arms, varied heights, transfer-adjacent space, and companion seating.
- Clear accessible circulation around benches, tables, drinking water, charging, transit waiting areas, and public information.
- Wheelchair and mobility-device spaces integrated into social seating areas.
- Heat-reflective or low-heat surface materials where practical.
- Drinking water or clearly posted directions to nearby water.
- Publicly reachable repair reporting without account or device requirements.
- Optional quiet/low-stimulation space that remains socially integrated.
- Nighttime safety lighting designed without person tracking.
- Native vegetation and water-smart planting selected for local ecology and maintenance capacity.
- A maintenance plan covering shade fabric, tree survival, irrigation, drainage, seating repair, litter, lighting, and accessible-path clearance.

### Two-Speed Heat Simulation

Use two complementary planning models:

| Model | Use | Output |
|---|---|---|
| Detailed microclimate model | Calibration, high-stakes corridors, material comparison, shade geometry, tree-canopy design | High-resolution UTCI, mean radiant temperature, wind, surface temperature |
| Reduced-order emulator | Public scenario exploration, rapid community workshops, option comparison | Coarsened heat, shade, access, water, repair, and uncertainty estimates |

Detailed models should include air temperature, humidity, wind, direct and diffuse solar radiation, surface geometry, material properties, canopy geometry, and irrigation/soil constraints. Reduced-order models must clearly label their output as an approximation and retain uncertainty.

The project’s existing heat-corridor work supports a first-order mean-radiant-temperature model and explicitly treats UTCI and related comfort limits as planning constraints rather than identity-based inputs. [160]

## Part Two: Wastewater Heat Recovery

### Purpose Limitation

Wastewater heat recovery may use sewer thermal energy to support nearby district-scale building heating, domestic hot-water preheating, thermal storage, or heat-pump operation.

The system SHALL NOT:

- Monitor a named household’s wastewater temperature, flow, occupancy, activity, bathing schedule, appliance use, health, disability, identity, augmentation status, or personal routine.
- Associate sewer measurements with individual addresses, properties, businesses, workers, or residents.
- Use household-level utility records to create a service, financial, or vulnerability ranking.
- Interrupt sanitation, wastewater treatment, public health protection, or essential water services to increase heat recovery.
- Treat recovered heat as a basis to reduce rights, public access, or service quality.

### Aggregate District Sensing

Permitted inputs include:

```text
district_sewer_flow_rate
district_influent_temperature
district_effluent_temperature
heat_pump_supply_temperature
heat_pump_return_temperature
heat_exchanger_pressure_drop
heat_exchanger_fouling_indicator
pump_energy
maintenance_state
aggregate_weather_condition
```

The preferred measurement location is a district interceptor, sewer trunk, treatment-plant influent channel, pumping-station wet well, or other aggregated municipal asset. Data should be aggregated at a level that does not expose individual contributor patterns.

### Thermal Recovery Model

Let:

- \(\dot{m}\): wastewater mass-flow rate in kilograms per second.
- \(c_p\): specific heat capacity in joules per kilogram per degree Celsius.
- \(\Delta T\): temperature decrease across the wastewater side.
- \(Q\): recoverable thermal power in watts.

\[
Q =
\dot{m}
c_p
\Delta T
\]

The requested design target is:

\[
\Delta T \geq 5^\circ\mathrm{C}
\]

This target must be validated against sewer temperature, flow variability, downstream treatment requirements, freeze protection where relevant, heat-exchanger approach temperature, equipment limits, and local regulatory conditions.

For a planning calculation, water-like wastewater can be approximated as:

\[
c_p \approx 4180
\frac{\mathrm{J}}
{\mathrm{kg}\cdot^\circ\mathrm{C}}
\]

The recovered energy during interval \(\Delta t\) is:

\[
E_{\mathrm{recovered}} =
Q \Delta t
\]

Heat-pump electrical input and coefficient of performance must be included when evaluating net energy benefit:

\[
COP =
\frac{Q_{\mathrm{delivered}}}
{W_{\mathrm{electric}}}
\]

\[
Q_{\mathrm{net}} =
Q_{\mathrm{delivered}} -
W_{\mathrm{electric}}
\]

### Heat-Exchanger Selection

| Heat-exchanger approach | Strength | Main concern | Appropriate planning condition |
|---|---|---|---|
| Spiral heat exchanger | Handles dirty, viscous, particulate-bearing flow; compact counter-current geometry; can support self-scouring flow conditions | Requires careful design, access, and cleaning strategy | High-solids, dirty wastewater or difficult fouling environment |
| Plate heat exchanger | High heat-transfer performance and compact footprint | Narrow passages can foul in untreated wastewater | Screened, clarified, or secondary-loop application |
| Shell-and-tube exchanger | Mechanically robust and inspectable | Larger footprint and potentially lower compactness | Applications requiring mechanical cleaning access |
| Sewer-integrated external exchanger | Avoids extracting some solids depending on design | Installation and hydraulic constraints | Large interceptor or new-build infrastructure |
| Side-stream exchanger with filtration | Allows controlled treatment and cleaning | Adds pumping, screening, and maintenance needs | Sites needing strong maintenance isolation |

Spiral exchangers are frequently considered for dirty or particulate-bearing wastewater because their channel configuration can reduce clogging and support a self-cleaning effect; however, actual performance depends on flow, solids, corrosion, access, and maintenance design. [227][231] Literature on wastewater heat recovery identifies fouling as a central design and cost issue, with geometry and installation orientation affecting fouling behavior. [224][228]

### Fouling-Aware Operation

Let:

- \(U_0\): clean overall heat-transfer coefficient.
- \(U_t\): estimated current overall heat-transfer coefficient.
- \(R_{f,t}\): estimated fouling resistance.
- \(\Delta P_t\): measured pressure drop.
- \(\Delta P_0\): clean baseline pressure drop.

A simplified fouling resistance estimate is:

\[
R_{f,t} =
\frac{1}{U_t}
-
\frac{1}{U_0}
\]

A normalized performance-loss indicator is:

\[
L_t =
1 -
\frac{U_t}{U_0}
\]

A conservative maintenance-review trigger can use:

\[
L_t \geq L_{\mathrm{review}}
\]

or:

\[
\Delta P_t -
\Delta P_0
\geq
\Delta P_{\mathrm{review}}
\]

The system must enter `MAINTENANCE_REVIEW_REQUIRED` rather than automatically perform chemical cleaning, flushing, bypass changes, or heat-exchanger isolation.

### Biofouling Prevention

Use layered, repairable and environmentally reviewed controls:

- Upstream coarse screening where hydraulically appropriate.
- Side-stream configuration where maintenance isolation is needed.
- Flow velocities and channel geometry selected for solids tolerance and cleaning access.
- Scheduled inspection based on thermal-performance decline and pressure-drop trends.
- Mechanical cleaning where compatible with equipment design.
- Cleaning-in-place only with reviewed chemical selection, containment, worker safety controls, wastewater compatibility, and disposal procedures.
- Corrosion-resistant materials selected for sewer chemistry and maintenance accessibility.
- Redundant or bypass heat-exchanger trains so cleaning does not interrupt sanitation.
- Calibrated temperature and flow sensors with drift detection.
- A documented lifecycle plan for pumps, screens, seals, filters, heat-pump refrigerant management, and end-of-life recycling.

## Privacy-Preserving Audit Records

### Shade-relief planning record

```json
{
  "event_type": "shade_relief_planning_summary",
  "planning_zone": "public_heat_access_zone",
  "time_window": "summer_daytime",
  "utci_target_c": 26.0,
  "target_hours_below_utci_percent": 90.0,
  "pedestrian_use_evidence_class": "aggregate_non_radio",
  "wifi_probe_data_used": false,
  "bluetooth_data_used": false,
  "camera_data_used": false,
  "identity_data_used": false,
  "accessibility_review_complete": true,
  "community_review_state": "pending_or_complete",
  "retention_class": "aggregate_planning"
}
```

### Wastewater heat-recovery record

```json
{
  "event_type": "district_wastewater_heat_recovery_summary",
  "district_asset_zone": "aggregate_sewer_service_area",
  "time_window": "hourly_or_daily",
  "district_flow_measurement_present": true,
  "household_level_data_used": false,
  "property_level_data_used": false,
  "identity_data_used": false,
  "temperature_drop_c": 0.0,
  "estimated_recovered_power_w": 0.0,
  "fouling_review_required": false,
  "automated_physical_action_performed": false,
  "retention_class": "aggregate_maintenance"
}
```

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.91 | UTCI-based microclimate planning, non-radio privacy-preserving use evidence, aggregate wastewater thermodynamics, and fouling-aware exchanger governance |
| eco_impact_value | 0.90 | Improves heat refuge, walkability, shade access, district energy recovery, thermal efficiency, and maintenance planning |
| harm_risk | 0.32 | Risks include heat-model uncertainty, poor access placement, sewer fouling, corrosion, maintenance hazards, and secondary surveillance; hard privacy and access constraints reduce exposure |
| accessibility_impact | 0.99 | Treats shade, seating, water, rest, route continuity, and human review as first-class public infrastructure outcomes |
| rights_alignment | 0.99 | Prohibits Wi-Fi tracking and household monitoring, preserves public access, limits data collection, requires co-design, and prevents optimization from overriding rights |
