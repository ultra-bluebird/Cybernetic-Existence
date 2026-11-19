# Defense-in-Depth Quantification

## Purpose

This document provides a bounded method for estimating attack-path risk
reduction across MSFP and Cyberdeck controls.

It does not produce a universal security score, a safety certification, a
medical or cybernetic assurance claim, or a guarantee that an architecture is
safe for real-world bodily, neural, medical, or cybernetic operation.

## Independent-Layer Approximation

For a defined attack path with independently measured controls:

```text
P(block) = 1 - product(1 - P(control_i))
P(residual) = product(1 - P(control_i))
```

This calculation is allowed only when the following are documented:

- Attack path and attacker capability.
- Control measurement method.
- Test corpus or scenario distribution.
- Shared dependencies.
- Environmental assumptions.
- Confidence interval or uncertainty range.
- Recovery behavior on control failure.

## Common-Cause Adjustment

Do not multiply controls as independent when they share:

- Build pipeline.
- Operating system.
- Parser or cryptographic library.
- Clock source.
- Policy engine.
- Power domain.
- Key-management root.
- Maintenance credential.
- Audit storage path.
- Human operational procedure.

```text
residual_risk =
    common_cause_risk
    + independent_bypass_risk
    - overlap(common_cause_risk, independent_bypass_risk)
```

## Required Report

For every protected release path, report:

1. Attack scenario.
2. Threat preconditions.
3. Controls exercised.
4. Measured block rate per control.
5. Shared dependency map.
6. Conservative residual-risk range.
7. Impact if bypass succeeds.
8. Safe-failure behavior.
9. Local baseline-right preservation result.
10. Independent review status.

## Safe-Failure Requirement

```text
control_failure or uncertainty =>
    block_external_release
    and clear_volatile_authority
    and preserve_local_continuity
    and show_accessible_local_status
```
