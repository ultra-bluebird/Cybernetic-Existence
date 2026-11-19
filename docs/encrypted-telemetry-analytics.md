# Encrypted Telemetry Analytics

## Scope

This design supports consented, purpose-limited aggregate analysis. It does not
authorize collection of neural, medical, biometric, physiological, identity,
or device telemetry by default. It does not support individual eligibility,
credibility, diagnosis, or automated high-impact decisions.

## Collection Gate

```text
collect =
    necessary_for_documented_purpose
    and explicit_revocable_consent
    and minimized_schema
    and approved_retention_limit
    and local_export_review
```

If any condition is false, do not collect or transmit the telemetry.

## Operation Selection

| Operation | Preferred Method |
|---|---|
| Count, sum, mean | Local aggregation or additive homomorphic encryption |
| Histogram | Local aggregate with small-group protections |
| Approved linear model | Additive homomorphic encryption with bounded fixed-point inputs |
| Comparison or threshold | Local evaluation first; FHE only with a documented necessity case |
| Feature extraction | Local-only before any encrypted export |
| Complex nonlinear model | Local model preferred; FHE requires measured feasibility and review |
| Individual-level classification | Prohibited |

## Encrypted Aggregate Rule

```text
encrypted_export =
    aggregate_only
    and minimum_group_threshold_met
    and approved_purpose
    and retention_bound
    and no_raw_payload
    and no_identity_or_stable_device_identifier
```

## Key Governance

- Keep decryption keys under a documented local or multi-party governance model.
- Do not place decryption keys on the analytics service.
- Rotate keys on approved schedules and after compromise.
- Bind keys to purpose and retention scope.
- Destroy expired analysis keys according to retention policy.
- Record only minimal accountability metadata, never plaintext telemetry.

## Required Validation

- Define plaintext ranges, fixed-point scale, and overflow limits.
- Test malformed ciphertext rejection.
- Test aggregation correctness with boundary values.
- Test that individual records are not exported.
- Test minimum-group suppression.
- Test retention deletion.
- Measure compute time, memory, energy use, and battery impact.
