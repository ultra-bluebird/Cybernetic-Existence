# MSFP Research Deck Boundary

## Security Statement

The research deck is conditionally trusted infrastructure. It can display
status, generate requests, run local test tools, and retain local encrypted
artifacts. It cannot independently authorize protected data release.

## Enforcement Boundary

The protected MSFP boundary must independently verify:

1. Frame byte length is within the configured maximum.
2. Encoding is canonical under the selected protocol profile.
3. The message version is supported and explicitly selected.
4. Unknown and duplicate fields are rejected.
5. Authenticated decryption succeeds before request semantics are used.
6. Policy permits the requested purpose, data categories, and capabilities.
7. Granted categories and capabilities are subsets of requested scope.
8. The lease is active immediately before release.
9. Revocation, expiry, integrity failure, and budget exhaustion block release.
10. Audit records contain only approved, data-minimized fields.

## Deck Capabilities

The deck may:

- Render local consent and recovery status.
- Send a user-approved request proposal.
- Submit a user-approved revocation request.
- Run isolated parser/fuzzer/model-checking workloads.
- Store encrypted local test vectors and audit views.
- Export a selected artifact only through an explicit review step.

The deck may not:

- Treat a UI state as a policy decision.
- Convert an audit receipt into an active session.
- Bypass lease checks after a prior approval.
- Execute hostile frame content.
- Retain hostile payloads merely because an inspection failed.
- Infer identity, health, credibility, augmentation, or eligibility.
- Claim to control a real-world neural, medical, cybernetic, or companion system.

## Boundary Invariant

```text
protected_release =
    valid_frame
    and canonical_encoding
    and authenticated_decryption
    and policy_permit
    and active_lease
    and atomic_budget_consumption
```

If any term is false, the protected release is blocked and the audit vault
records only the allowed outcome metadata.
