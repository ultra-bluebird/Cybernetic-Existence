# MSFP STRIDE Threat Model

## Scope

This threat model covers the MSFP gateway, consent console, frame inspector,
lease monitor, V-NIR volatile-session boundary, audit vault, receipt exporter,
maintenance gateway, and local continuity interface.

It does not infer or verify identity, health, neural status, augmentation,
credibility, eligibility, or personal status from data, behavior, hardware,
or communication patterns.

## Security Objectives

- Authenticate external peers cryptographically.
- Reject tampered, replayed, malformed, or unsupported frames.
- Preserve minimal accountability evidence without raw payload retention.
- Release only data and capability scope authorized by active policy and lease.
- Bound resource consumption and preserve local continuity during failure.
- Prevent authority expansion through deck, gateway, policy, lease, or
  maintenance paths.
- Preserve baseline rights after external denial, expiry, revocation, or
  integrity failure.

## STRIDE Matrix

| Category | MSFP threat | Required control | Formal guarantee | Evidence |
|---|---|---|---|---|
| Spoofing | Impersonated external peer, forged maintenance actor, replayed credential | Mutual authentication, transcript binding, fresh nonce, signed maintenance grant | `release => peer_authenticated and nonce_fresh` | Handshake tests, signature-negative tests |
| Tampering | Altered frame, policy bundle, audit receipt, update artifact | Canonical encoding, AEAD/signature verification, digest checks, signed release verification | `accepted_artifact => integrity_verified` | Parser tests, artifact-signature tests |
| Repudiation | A party disputes a completed/blocked session event | Minimal signed or hash-linked receipt, policy version, reason code, retention rule | `terminal_event => minimal_evidence_recorded or evidence_write_failure_recorded` | Receipt verification, audit-store failure tests |
| Information Disclosure | Raw payload, credential, telemetry, or local data leaves policy scope | Data-category allowlist, minimal audit schema, encryption, selective export review | `released_categories subset_of requested_categories intersect permitted_categories` | Redaction tests, export-review tests |
| Denial of Service | Oversized frame, parser nesting attack, request flood, audit-volume exhaustion | Bounds, rate limits, allocation budgets, quarantine, bounded audit queue, local fallback | `resource_limit_exceeded => protected_release_blocked` | Fuzzing, load tests, timeout tests |
| Elevation of Privilege | Capability expansion, ordinary session requesting maintenance/firmware authority, stale lease reuse | Monotonic capability attenuation, separate maintenance mode, fresh generation, expiry/revocation checks | `final_authority subset_of granted_authority` | Typestate tests, policy tests, TLA+ model |

## Cross-Cutting Invariants

```text
terminal_state =>
    not external_authority
    and not protected_release_allowed
    and local_baseline_rights_preserved

revoked_generation =>
    never active_generation

ordinary_session =>
    never firmware_update_authority

audit_record =>
    no raw_payload
    and no credential
    and no stable personal identifier
```

## Review Rule

A STRIDE entry is incomplete unless it includes:

1. A bounded threat description.
2. The affected trust boundary.
3. A prevention or containment control.
4. A formal invariant or testable property.
5. Evidence-producing tests.
6. A residual-risk statement.
7. A recovery behavior that preserves local continuity and accessible status.
