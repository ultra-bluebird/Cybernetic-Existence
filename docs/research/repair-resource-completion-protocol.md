# Repair, Energy, Sampling, and Thermal Completion Protocol

Protocol version: 1

## Scope

Complete and integrate:
- Repair-preserving configuration.
- Energy-per-task measurement.
- Adaptive sampling governance.
- Device-thermal workload policy.

## Planned files

| Topic | Source | Test |
|---|---|---|
| Repair configuration | kotlin/interoperability/RepairConfiguration.kt | tests/kotlin/interoperability/RepairConfigurationTest.kt |
| Energy measurement | kotlin/interoperability/TaskEnergy.kt | tests/kotlin/interoperability/TaskEnergyTest.kt |
| Sampling governance | kotlin/governance/SamplingGovernor.kt | tests/kotlin/governance/SamplingGovernorTest.kt |
| Thermal policy | kotlin/governance/DeviceThermalPolicy.kt | tests/kotlin/governance/DeviceThermalPolicyTest.kt |

Packages:
- augmentedhub.interoperability
- augmentedhub.governance

## Dependencies

Shared foundation and validation patterns.

Domain scaffolding:
- RepairConfigSchema.
- EnergyBoundary.
- SamplingScopeSchema.
- ThermalMapping.

## Exact sequence

### Repair

- Export selected presentation preferences only.
- Structurally exclude credentials, maps, trajectories, private inventories,
  actuator calibration, and pairing secrets.
- Preview before transfer.
- Report unsupported or mismatched settings.
- Verify the target's reported restoration separately from import success.
- Define copy retention and public-device handover.

### Energy

- Declare measurement boundary, instrument, sampling, task, workload,
  and failed-attempt policy.
- Integrate only covered, ordered samples.
- Reject excessive gaps and nonfinite values.
- Do not extrapolate missing task coverage.
- Report gross task energy and any baseline subtraction separately.
- Preserve failed attempts and task-success context.
- Do not penalize slower communication or remove essential assistance.

### Sampling

- Use immutable scopes.
- Bind pollutant, resource, purpose, intervals, retention, and validity.
- Reject requests outside scope.
- Require a new reviewed scope for expansion.
- Separate acquisition, averaging, reporting, and retention.
- Keep candidate selection separate from actual sensor configuration.
- Do not expand sensing because of energy pressure.

### Thermal

- Use documented device signals only.
- Preserve platform severity distinctions.
- Reject physiological sources and inferred fatigue.
- Handle unknown or stale signals explicitly.
- Preserve a recovery-review latch where required.
- Reduce optional workload before restricting essential interaction.
- Never override platform protection or claim continued operation through shutdown.

### Deliver tests

- Repair field exclusions and incompatible target settings.
- Energy endpoints, gaps, order, nonfinite values, and budget limits.
- Scope expansion, expiry, mismatched purpose, and retention violations.
- Thermal unknowns, severe states, recovery, and prohibited sources.
- Clock and lifecycle tests where controllers exist.
- No hardware commands in reference tests.

### Integration and batch close

- Specify measurement instrumentation and device-specific mappings.
- Define any separately approved control interface.
- Supply four complete sources and four tests.
- Update ledger, registry, and traceability.
- Record measured benefits separately from editorial estimates.
- End with the fixed session-state declaration.
