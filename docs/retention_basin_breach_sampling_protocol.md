# Retention Basin Breach Sampling Protocol

## Purpose

This protocol derives protective sensor sampling intervals from a declared
time-to-threshold model. It distinguishes rapid operational detection from
laboratory, compliance, or environmental-characterization sampling.

This protocol does not establish a permit condition, civil design approval,
structural safety certification, emergency authorization, or deployment-specific
operating threshold.

## Required definitions

Each retention-basin configuration MUST declare:

- `warning_threshold`: stage, volume, flow, or rate-of-rise condition that begins
  the protective response clock;
- `blast_radius_threshold`: approved model threshold for the domain (g) impact
  boundary;
- `time_to_threshold_seconds`: conservative earliest time from warning threshold
  to threshold crossing;
- `sensor_latency_seconds`: sensing, filtering, and timestamping delay;
- `transport_latency_seconds`: local network or storage delay;
- `validation_latency_seconds`: local parsing and invariant-validation delay;
- `confirmation_latency_seconds`: time reserved for independent confirmation;
- `human_response_seconds`: escalation and decision time;
- `physical_response_seconds`: time until bypass, gate, diversion, or other
  independently authorized safeguard begins to take effect;
- `safety_margin_seconds`: separately declared uncertainty allowance;
- `required_confirmations`: integer greater than or equal to one.

## Sampling bound

The configured protective interval MUST satisfy:

`sample_interval_seconds <=
 (time_to_threshold_seconds - total_reserved_seconds) / required_confirmations`

where:

`total_reserved_seconds =
 sensor_latency_seconds +
 transport_latency_seconds +
 validation_latency_seconds +
 confirmation_latency_seconds +
 human_response_seconds +
 physical_response_seconds +
 safety_margin_seconds`

The result MUST be strictly positive.

If the result is less than or equal to zero, periodic sampling is not an adequate
protective measure. The system MUST reject the configuration and require a different
safety design, such as continuous sensing, independently designed overflow routing,
or a physical fail-safe.

## Continuous sensing requirement

Protective monitoring MUST use continuously operating or near-continuous instruments
for at least:

- basin stage;
- inflow or rate-of-rise proxy;
- outflow or bypass state where applicable;
- sensor-health status;
- local power status;
- local storage availability.

Laboratory sampling, manual sampling, or periodic visual inspection MUST NOT be
represented as a substitute for protective breach detection.

## Sensor-health requirement

The protective path MUST enter a review or fail-safe state when:

- stage or flow data become stale;
- sensor clock status becomes uncertain;
- measurements exceed physical plausibility bounds;
- the configured sampling interval is missed;
- calibration is expired;
- local storage cannot preserve an audit record;
- a topology, corridor, or KER boundary invariant fails.

## Alert classes

- `advisory`: evidence quality or trend requires review; no threshold is imminent.
- `warning`: warning threshold crossed; begin protective response clock.
- `critical`: predicted threshold crossing occurs before the available response time.
- `sensor_fault`: protective measurement is absent, stale, implausible, or untrusted.
- `recovery_required`: continuity cannot be established after restart or interruption.

## Review record

Every threshold event MUST retain:

- model revision;
- parameters used;
- raw observations;
- sampling interval;
- latency measurements;
- alert time;
- operator notification time;
- response outcome;
- uncertainty statement;
- superseding record reference when corrected.
