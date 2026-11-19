# MSFP Enforcement Split

## Scope

TTL-HWC is a fail-closed lease-enforcement component. Software is responsible
for admission, policy, audit projection, continuity preservation, accessibility,
and local recovery explanation.

TTL-HWC is not an identity verifier, neural system, medical controller,
CyberRank evaluator, or source of personal-status determinations.

## Enforcement Allocation

| Property | TTL-HWC hardware responsibility | Software responsibility |
|---|---|---|
| Non-extendable lease | Enforce expiry against an independent monotonic timing source | Require renewal to use fresh admission and a new generation |
| Volatile authority clear | Disable V-NIR session authority and clear volatile registers under defined fault model | Verify zeroization receipt, record minimal outcome, transition to Cold |
| Watchdog independence | Independent clock, reset behavior, specified power-loss behavior | Recheck monotonic clock before every protected release |
| Frame bounds/rate limits | Optional coarse circuit breaker | Strict parser limits: size, nesting, fields, schema version |
| Capability confinement | Not authoritative | Intersect requested, policy, consent, and purpose scopes |
| Purpose binding | Not authoritative | Bind purpose, audience, data categories, policy version, expiry, and revocation |
| Human fallback | Not authoritative | Local status, offline instructions, accessible input/output |
| Audit minimization | May emit terminal reason signal only | Permit only minimal audit projection and retention policy |
| Recovery rights baseline | Must not erase durable local state | Preserve baseline guarantees and show accessible status |

## Lease Rule

```text
lease_active =
    now < expires_at
    and not revoked
    and integrity_ok
    and remaining_budget > 0
```

```text
expiry or revocation or integrity_failure =>
    authority_off
    and traffic_blocked
    and volatile_state_cleared
    and minimal_evidence_requested
    and local_continuity_preserved
```

## Timing Claim Rule

A target such as `V-NIR power drop under 1.2 ns` is a measurable engineering
objective under a documented clock, supply, load, temperature, process,
measurement, and fault model. It is not an absolute guarantee.

Any public performance claim must report the test conditions and uncertainty.
