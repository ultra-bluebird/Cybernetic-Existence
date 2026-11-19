# Hybrid Mobile–Stationary Sensor Fusion

## Purpose

This protocol defines a hybrid sensor architecture for Phoenix-area hex corridors.

Stationary instruments establish temporal baselines. Mobile instruments characterize
spatial variation, investigate gaps, identify anomalies, and support targeted
sampling. The protocol preserves source-level auditability for drainage-decay frames.

It does not diagnose PFAS from a proxy sensor, certify PFAS removal, authorize
equipment movement, authorize canal access, or create an autonomous physical-control
path.

## Roles

### Stationary reference node

A stationary node MUST have:

- fixed approved anchor/corridor binding;
- known coordinate and geometry revision;
- calibration revision;
- measurement method;
- timestamp source;
- source-health state;
- defined sampling interval;
- uncertainty model;
- local persistence path;
- maintenance and outage record.

Stationary readings are temporal reference observations. They are not automatically
ground truth; they remain subject to calibration and quality rules.

### Mobile survey unit

A mobile unit MUST have:

- position estimate and position uncertainty;
- route identifier;
- measurement method;
- measurement timestamp;
- calibration revision;
- co-location or cross-calibration history;
- source-health state;
- sample matrix;
- uncertainty model;
- anchor/corridor assignment rule;
- no physical-control authority.

Mobile observations are spatial samples. They MUST NOT replace stationary baseline
records or be treated as equivalent without cross-calibration.

## Parameter classes

### Continuous environmental context

Mobile and stationary units MAY measure, subject to validation:

- temperature;
- conductivity or salinity proxy;
- dissolved oxygen;
- pH;
- turbidity;
- chlorophyll or algae proxy;
- water level;
- flow proxy;
- weather context.

### Drainage-decay frame components

BOD, TSS, and CEC MUST retain separate evidence paths:

- BOD: water-sample measurement under documented method;
- TSS: water-sample measurement under documented method;
- CEC: sediment or soil measurement under documented method.

CEC MUST NOT be synthesized from a mobile water-quality sensor.
BOD and TSS proxy signals MUST NOT be presented as laboratory reference values unless
the source method and calibration support that claim.

### PFAS boundary

PFAS concentration, transformation, defluorination, and removal claims require
analyte-specific validated analytical methods and appropriate quality control.

Mobile sensors MAY support sampling prioritization. They MUST NOT be presented as
direct PFAS analytical evidence unless the deployed method is validated for the
specific analyte, matrix, reporting limit, and operating environment.

## Co-location requirement

A mobile source may contribute to a fused estimate only when at least one applies:

- it is co-located with a stationary reference source within the approved distance
  and time window;
- it has an accepted calibration transfer record applicable to its current revision;
- it is explicitly included as an uncalibrated exploratory observation with increased
  uncertainty and `provisional` status.

The fusion system MUST retain the co-location record or calibration-transfer record.

## Baseline adjustment

For parameter j:

`mobile_adjusted(j, p, t) =
 mobile_raw(j, p, t) - estimated_mobile_to_stationary_bias(j, t)`

Bias estimation MUST retain:

- overlapping source records;
- matching window;
- method and calibration revisions;
- estimated bias;
- uncertainty;
- validity period;
- acceptance status.

## Fusion inclusion

A source reading may be included only when:

- source health is accepted;
- method and unit match the parameter definition;
- geometry binding is current;
- timestamp is within the declared frame window;
- required co-location or calibration-transfer evidence exists;
- uncertainty is finite and positive;
- source record is immutable and retained.

A reading excluded from fusion MUST remain auditable with an exclusion reason.

## Drainage-decay audit rule

Every accepted drainage-decay frame MUST retain:

- at least one accepted BOD contribution;
- at least one accepted TSS contribution;
- at least one accepted CEC contribution;
- source type for every contribution;
- raw value and unit;
- normalization revision;
- observation variance;
- innovation and innovation variance;
- inclusion status;
- filter revision;
- anchor and corridor binding;
- frame residual.

A composite frame MUST NOT overwrite or delete the individual BOD, TSS, or CEC
source records.

## Routing

A mobile anomaly MAY create:

- `sampling_priority`;
- `review_required`;
- `co_location_required`;
- `laboratory_confirmation_requested`.

It MUST NOT create:

- PFAS detected;
- PFAS removed;
- device action;
- canal-flow command;
- public status;
- personal identity inference.
