# Corridor Negotiation Research Plan

## Purpose

This research plan evaluates a non-actuating, deterministic protocol for managing shared narrow corridors used by pedestrians, mobility-device users, emergency responders, and autonomous delivery bots.

The work uses synthetic scenarios, seeded Monte Carlo simulation, bounded exhaustive testing, and aggregate outputs only. It does not require field deployment, personal identity data, medical data, neural data, device serial numbers, biometric data, or individual travel histories.

## Research questions

- Does the protocol always produce one deterministic outcome for valid inputs?
- Does the protocol prevent delivery bots from receiving passage ahead of pedestrians, mobility-device users, and emergency responders?
- Does a self-declared service urgency affect priority without becoming identity verification?
- Which corridor widths produce structurally unsafe configurations?
- Can repeated high-priority traffic cause unbounded delivery-bot delays?
- Does changing a self-declared identity label alter an otherwise identical infrastructure outcome?
- How stable are aggregate outcomes across fixed seeds, scenario changes, and bounded sensor faults?

## Policy invariants

### Determinism

For identical validated inputs, the selected actor, decision, and explanation must be identical.

### Pedestrian and mobility precedence

A delivery bot must not receive a passage grant while a pedestrian, mobility-device user, or emergency responder is waiting for passage.

### No forced passage

If a corridor cannot provide the configured clear width for the highest-priority actor, the protocol returns an unsafe-configuration decision and requests an accessible alternate route, human assistance, or physical redesign.

### Optional service urgency

Battery state, thermal need, and connectivity need are optional service-urgency inputs. Their absence must not reduce access priority for a pedestrian or mobility-device user.

### Category non-discrimination

A self-declared planning category must not alter passage outcomes when physical corridor requirements, service urgency, safety class, and arrival order remain equal.

### Aggregate-only simulation

Simulation outputs may contain counts, ratios, quantiles, scenario identifiers, version identifiers, and random seeds. They must not retain person-level trajectories, raw battery histories, health records, device serial numbers, biometric data, neural data, or identity records.

## Core measures

- Pedestrian priority-grant ratio.
- Mobility priority-grant ratio.
- Delivery-bot yield ratio.
- Unsafe-configuration ratio.
- Mean, median, and upper-percentile simulated waiting slots.
- Maximum observed simulated wait.
- Policy-determinism mismatch count.
- Category-nondiscrimination mismatch count.
- Sensor-fault fail-safe ratio.
- Simulation energy estimate per completed scenario.

## Reproducibility protocol

Each run records:

- Simulation module version.
- Scenario manifest digest.
- Fixed pseudorandom seed.
- Number of trials.
- Aggregate result digest.
- Policy configuration digest.

A repeated run with the same module version, scenario manifest, configuration, and seed must produce identical aggregate output.
