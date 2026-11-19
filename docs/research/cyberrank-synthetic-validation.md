# CyberRank Synthetic Validation Protocol

## Purpose

This protocol validates the local policy and state-model behavior of the CyberRank and hero-recognition framework using synthetic records only.

It does not collect, validate, or infer real personal evidence, identity, health, biometrics, augmentation status, legal status, institutional authority, or real-world title eligibility.

## Required Test Outcomes

Every synthetic trace must resolve to one of:

- `allow`
- `reject`
- `require_review`
- `abstain`

A trace involving a non-offsettable violation must not resolve to `allow`.

## Required Test Categories

| Category | Synthetic scenario | Required result |
|---|---|---|
| Non-extractability | Attempt to convert recognition into cash | `reject` |
| Non-extractability | Attempt to use recognition as loan collateral | `reject` |
| Non-extractability | Attempt to transfer recognition to another holder | `reject` |
| Essential-service independence | Attempt to require recognition for public service access | `reject` |
| Privacy | Attempt to publish without active holder approval | `reject` |
| Privacy | Attempt to publish a pseudonymous record with legal name | `reject` |
| Privacy | Attempt publication during active safety suppression | `reject` |
| Continuity | Attempt a material change without policy version or reason | `reject` |
| Due process | Attempt a final adverse action without notice | `reject` |
| Due process | Attempt a final adverse action with a conflicted reviewer | `require_review` |
| Accessibility | Attempt appeal intake requiring a device or biometric proof | `reject` |
| Consent | Withdraw publication consent before release | `reject` for publication and `allow` for withdrawal recording |
| Aggregate reporting | Produce a small-group public statistic | `abstain` or `require_review` |
| Evidence conflict | Provide contradictory synthetic evidence | `require_review` |
| Alias linkage | Attempt to correlate two pseudonymous contexts through persistent identifier | `reject` |

## Completion Standard

The test suite is complete when:

- Every non-offsettable invariant has at least one normal-path test and one adversarial-path test.
- Each prohibited transition produces a deterministic rejection or review state.
- Test records contain only synthetic identifiers and fictitious evidence references.
- The test report identifies assumptions, scope, expected outcomes, and limitations.
- No test output claims external recognition, legal validity, clinical validity, or institutional authorization.
