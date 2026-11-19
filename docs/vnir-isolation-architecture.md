# V-NIR Isolation Architecture

## Purpose

V-NIR is a volatile session-isolation register bank. It stores only bounded,
short-lived session attributes and cannot write arbitrary session data into
durable local state.

V-NIR is not a neural interface, neural identity store, biometric verifier,
medical system, augmentation evaluator, or personal-status authority.

## Volatile Session Fields

- Session pseudonym.
- Protocol version.
- Fresh nonce or challenge reference.
- Policy version reference.
- Requested and granted capability bitmap.
- Lease-expiry counter or timestamp.
- Integrity flag.
- Revocation flag.
- Release-budget counter.
- Minimal terminal reason code.

## Durable Local Fields

- Encrypted local documents.
- Accessibility preferences.
- Local consent and revocation preferences.
- Local recovery records.
- Trusted key references.
- Versioned policy artifacts.
- Approved audit records subject to retention policy.

## Hardware Separation Rules

```text
session_domain_write -> permanent_domain_write = denied
session_domain_read  -> permanent_domain_read  = denied
session_domain_dma   -> permanent_domain_dma   = denied
debug_domain         -> permanent_domain       = denied by default
```

The only permitted session-to-durable transition is:

```text
audit_projection(session_terminal_event) -> append_minimal_audit_record
```

The projection contains only approved metadata and no raw payload, plaintext,
credential, network address, biometric data, or private identity assertion.

## Reset Rule

```text
expiry or revocation or integrity_failure or restart =>
    clear_vnir
    and block_protected_release
    and retain_local_continuity
    and create_accessible_local_status
```
