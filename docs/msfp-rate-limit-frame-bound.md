# MSFP Rate Limit and Frame Bound Requirements

## Frame bounds

Every inbound frame must satisfy:

- Frame size is less than or equal to the configured maximum.
- Field count is less than or equal to the configured maximum.
- Nesting depth is less than or equal to the configured maximum.
- String and binary field lengths are bounded.
- Unknown fields are rejected.
- Compression is disabled by default unless a bounded decompression policy exists.

## Token bucket

For bucket capacity B, refill rate r, elapsed time Δt, and frame cost C(s):

T_refilled = min(B, T_previous + r * Δt)

A frame is admitted only when:

T_refilled >= C(s)

T_next = T_refilled - C(s)

The frame cost includes a fixed processing charge plus a byte-weighted charge:

C(s) = c0 + ceil(s / q)

## Independent budgets

A message must satisfy all configured budgets:

- Frame-count budget.
- Byte-volume budget.
- Authentication-work budget.
- Parser-work budget.
- Audit-output budget.

## Auditability

Rejected payloads are not stored by default.

The audit system records a privacy-minimized, coalesced receipt containing:

- Time window.
- Session pseudonym.
- Rejection reason.
- Rejected frame count.
- Rejected byte count.
- Policy version.

When the audit budget is exhausted, the system records one aggregate overflow
receipt instead of increasing retained payload data.
