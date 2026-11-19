# Micro-Swarm Firebreak Protocol Research Brief

## Status

Research architecture for revocable, least-privilege external-session isolation.

This document defines a software- and hardware-agnostic research model. It does not claim the ability to operate, assess, validate, or alter any medical, neural, biological, companion, or institutional system.

## Purpose

The Micro-Swarm Firebreak Protocol (MSFP) is a proposed containment pattern for temporary identity and telemetry exchanges between an untrusted external entity and a protected local system.

MSFP aims to:

- Minimize data disclosure.
- Bind each session to a declared purpose.
- Limit authority to explicit capabilities.
- Enforce short, non-extendable session leases.
- Prevent direct execution and uncontrolled lateral access.
- Revoke access deterministically on expiry, user action, or policy failure.
- Preserve accessible, privacy-minimized recovery and audit paths.

## Non-goals

MSFP does not:

- Verify a person's identity, augmentation status, health, credibility, or eligibility.
- Infer any identity or system condition from communication style, metadata, or refusal to disclose.
- Grant direct hardware, actuator, medical, neural, or biological control.
- Claim absolute security or irreversible data erasure.
- Replace clinical safety engineering, legal review, accessibility review, or human oversight.

## Security properties

### Default deny

No external session is active unless all admission checks pass:

1. Explicit user consent or a documented pre-authorization basis.
2. Mutual authentication.
3. Versioned schema validation.
4. Capability-policy approval.
5. Bounded resource reservation.
6. Independent lease activation.

### Capability confinement

A session capability is represented as:

```text
capability = {
  subject_binding,
  purpose,
  allowed_operations,
  data_categories,
  audience,
  expires_at,
  revocation_handle,
  policy_version
}
```

Capabilities must be:

- Specific rather than broad.
- Read-only by default.
- Bound to a single session.
- Non-transferable.
- Invalid after expiry or revocation.
- Denied if any required field is absent or invalid.

### Session lease

Each session has a fixed lease:

```text
lease = {
  session_id,
  issued_at,
  expires_at,
  max_messages,
  max_bytes,
  capability_set,
  protocol_version
}
```

Renewal is prohibited in place. A later interaction requires a new admission decision and new cryptographic session material.

### Ingress validation

The ingress gateway must:

- Use an authenticated, encrypted transport.
- Enforce frame-size and message-count bounds.
- Reject unknown fields and ambiguous encodings.
- Reject replayed nonces or sequence numbers.
- Reject unsupported protocol versions.
- Perform constant-time authentication checks where applicable.
- Treat every inbound field as non-executable data.
- Avoid logging sensitive payload contents by default.

### Termination

Any of the following transitions the system to `Revoked`:

- Lease expiry.
- User revocation.
- Authentication failure.
- Schema or capability-policy failure.
- Rate-limit breach.
- Integrity-check failure.
- Independent watchdog expiry.
- Authorized local maintenance lockout.

Termination must:

1. Stop ingress and egress.
2. Invalidate the session capability.
3. Zeroize session key material where supported.
4. Discard in-memory session state.
5. Emit a privacy-minimized audit event.
6. Require fresh admission before any subsequent session.

## Privacy and accessibility

MSFP implementations must:

- Offer a plain-language session status.
- Provide accessible alternatives to visual-only alerts.
- Support a human fallback for lockouts and disputes.
- Avoid collecting neural, biometric, physiological, location, or technical-inventory information unless necessary for a stated purpose and covered by explicit, revocable consent.
- Preserve correction and appeal paths for consequential access decisions.
- Avoid exposing personal or sensitive diagnostic data through ordinary logs.

## Audit event schema

An audit record must contain only the information needed for accountability:

```text
audit_event = {
  event_type,
  event_time,
  session_pseudonym,
  policy_version,
  protocol_version,
  outcome,
  reason_code,
  data_categories_requested,
  data_categories_released,
  retention_class
}
```

Audit records must not include raw session payloads, raw identity proofs, biometric values, neural data, or personal identifiers by default.

## Verification plan

A prototype is not complete until it demonstrates:

- Invalid frames cannot reach protected services.
- Expired capabilities cannot be reused.
- Revocation takes precedence over normal processing.
- Unknown message fields are rejected.
- Input-size and nesting bounds are enforced.
- No inbound path reaches a command or execution interface.
- Session state is not written to durable storage.
- Diagnostic events contain no sensitive payload by default.
- Human fallback remains available after an automated lockout.
- Accessibility status is available without relying solely on sound, color, or timing.
