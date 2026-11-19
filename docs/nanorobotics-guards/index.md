# Nanorobotics Guards Documentation

This directory defines the pre-guard and software-level enforcement layers for neurorights and safety corridor adherence.

## Guard Layers
1. **Neurorights Enforcer**: Validates consent, mental privacy, cognitive liberty, and psychological continuity constraints.
2. **Pain/Fear Clamp LUT**: Hardware-prepended monotonic lookup table that scales actuation force based on nociceptive indices.
3. **Invariant Checker**: Evaluates residual risk, RoH ceilings, and duty fraction limits against historical and current states.
4. **Guard Orchestrator**: Coordinates all layers, applies layered decision logic, and logs outcomes to Prometheus metrics.

## Safety Semantics
- Guards are fail-closed. Any layer returning `Deny` overrides lower-priority `Allow` decisions.
- Pain/fear clamp is monotone non-increasing: higher nociception → lower or equal actuation factor.
- All guard evaluations are timestamped, host-bound, and exportable as `ViolationReport` arrays.

## Compliance
Guard configurations must align with `NeurorightsPainFearEnvelope` shards and `HostBudget` ceilings. Unauthorized guard modifications are blocked at the manifest level.
