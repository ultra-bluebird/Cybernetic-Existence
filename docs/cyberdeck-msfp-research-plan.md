# Cyberdeck and MSFP Research Plan

## Purpose

This plan defines a privacy-preserving cyberdeck prototype as an external,
user-controlled gateway for temporary, consent-bound sessions with an MSFP
research emulator.

The cyberdeck is not a medical controller, neural controller, identity ranking
system, or authority for bodily or institutional decisions.

## Design principles

- Default deny.
- Explicit, revocable consent.
- Minimal disclosure.
- Short-lived capabilities.
- Independent session expiry.
- No inbound code execution.
- Accessible local status.
- Privacy-minimized audit evidence.
- Offline-first operation.
- Human fallback and review.

## Core services

### Gateway

The gateway accepts bounded protocol frames and forwards only approved,
authenticated, schema-valid capability requests to the MSFP emulator.

### Consent console

The console displays:

- Requested purpose.
- Requested data categories.
- Allowed operations.
- Explicitly denied operations.
- Session duration.
- Recipient category.
- Local revocation control.

### Lease monitor

The monitor terminates the local session when a deadline, revocation,
integrity failure, or resource budget violation occurs.

### Audit vault

The vault stores minimal event metadata and integrity hashes. It does not
store raw payloads or personal information by default.

### Test laboratory

The laboratory runs protocol test vectors, malformed-frame tests, timeout
tests, replay tests, capability-escalation tests, and audit-redaction tests.

## Prohibited authority

The cyberdeck must not provide:

- Direct hardware control.
- Firmware installation through ordinary sessions.
- Arbitrary memory access.
- Code execution from inbound frames.
- Identity ranking or eligibility decisions.
- Neural, medical, biological, or actuator control.
- Hidden telemetry collection.
- Remote override of local consent or revocation.

## Session lifecycle

1. The cyberdeck receives a request.
2. The consent console shows the requested purpose and scope.
3. The user approves, narrows, or rejects the request.
4. The gateway validates authentication, schema, replay controls, and policy.
5. MSFP issues a narrowly scoped, non-transferable session lease.
6. The lease monitor terminates the session on expiry or revocation.
7. The audit vault records a minimal outcome receipt.
8. A new request requires a new consent and admission process.

## Acceptance criteria

- Expired sessions cannot forward messages.
- Revoked sessions cannot be resumed.
- Unknown fields and oversized frames are rejected.
- Inbound data has no execution path.
- Session keys are not written to durable storage.
- Logs contain no raw payloads by default.
- The user can revoke the session through the primary interface.
- A nonvisual status path is available.
- The protected-side emulator independently rejects prohibited capabilities.
