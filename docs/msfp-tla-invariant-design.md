# MSFP TLA+ Invariant Design

## Scope

This model specifies an abstract, non-actuating session-control boundary.

It models:

- Explicit admission.
- Narrow capabilities.
- Session expiry.
- User or policy revocation.
- Key invalidation.
- Return to a Cold state.
- New admission rather than in-place renewal.
- No mid-session capability widening.

It does not model or claim control over biological, neural, medical, cybernetic,
or physical systems.

## State vocabulary

A session has one of these states:

- Cold: no active session, no usable session key, no usable capability.
- Pending: an admission request is being evaluated.
- Active: a newly admitted, bounded session exists.
- Revoked: authority is removed and teardown is required.
- Expired: the time lease ended and teardown is required.

The only state that can hold external authority is Active.
