# Minimal Disclosure Policy

## Rule

A data category may be released only when it is:

1. Requested by the active session.
2. Necessary for the declared purpose.
3. Within active, revocable consent scope.
4. Permitted by the active policy version.
5. Explicitly aligned with the declared purpose.

## Set definition

Let:

- R be requested categories.
- N(p) be categories necessary for purpose p.
- C be active consent scope.
- P be policy-permitted categories.
- L be released categories.

The maximum allowable release set is:

A = R ∩ N(p) ∩ C ∩ P

The required condition is:

L ⊆ A

## Prohibitions

The gateway must not release:

- Data outside the declared purpose.
- Data merely because it was requested.
- Data outside active consent.
- Data outside the capability data-category set.
- Raw payloads, private keys, capability tokens, biometric data, neural data,
  medical data, technical inventory, or identity material by default.
- Any data required for public ranking, eligibility, credibility, or identity
  inference.

## Audit

Audit receipts contain category labels, decision outcomes, policy version, and
a privacy-minimized commitment. They do not contain raw released data by
default.
