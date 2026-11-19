# MSFP Session Lease Grammar

## States

```ebnf
SessionState =
    Cold
  | AdmissionRequest
  | IsolatedSession
  | SoftReset
  | Rejected
  | Revoked
  | EvidenceSeal;
```

## Terminal Reasons

```ebnf
TerminalReason =
    ValidationFailure
  | AuthenticationFailure
  | PolicyDenied
  | Expired
  | UserRevocation
  | IntegrityFailure
  | BudgetExceeded
  | Timeout
  | Restart;
```

## Events

```ebnf
Event =
    ExternalRequest
  | ValidationPassed
  | ValidationFailed
  | AuthenticationPassed
  | AuthenticationFailed
  | PolicyPermitted
  | PolicyDenied
  | TransientFault
  | RetryAuthorized
  | LeaseExpired
  | UserRevoked
  | IntegrityFailed
  | ReleaseBudgetExhausted
  | EvidenceWritten
  | Restarted;
```

## Valid Transitions

```ebnf
Cold
  ::= ExternalRequest -> AdmissionRequest;

AdmissionRequest
  ::= ValidationPassed AuthenticationPassed PolicyPermitted -> IsolatedSession
   |  ValidationFailed -> Rejected
   |  AuthenticationFailed -> Rejected
   |  PolicyDenied -> Rejected;

IsolatedSession
  ::= TransientFault -> SoftReset
   |  LeaseExpired -> Revoked
   |  UserRevoked -> Revoked
   |  IntegrityFailed -> Revoked
   |  ReleaseBudgetExhausted -> Revoked;

SoftReset
  ::= RetryAuthorized -> AdmissionRequest
   |  LeaseExpired -> Revoked
   |  UserRevoked -> Revoked
   |  IntegrityFailed -> Revoked
   |  Restarted -> Revoked;

Rejected
  ::= EvidenceWritten -> EvidenceSeal;

Revoked
  ::= EvidenceWritten -> EvidenceSeal;

EvidenceSeal
  ::= Restarted -> Cold;
```

## Forbidden Transitions

```ebnf
Forbidden =
    Cold -> IsolatedSession
  | AdmissionRequest -> Cold
  | Rejected -> IsolatedSession
  | Revoked -> IsolatedSession
  | EvidenceSeal -> IsolatedSession
  | SoftReset -> IsolatedSession
  | AnyState -> IsolatedSession without
      ValidationPassed AuthenticationPassed PolicyPermitted;
```

## Cold-State Invariant

```text
Cold =>
    no_session_key
    and no_active_lease
    and release_budget = 0
    and no_pending_plaintext
    and protected_release_blocked
```

## Terminal-State Invariant

```text
Rejected or Revoked or EvidenceSeal =>
    protected_release_blocked
```

A new trusted session can exist only after a new `ExternalRequest` reaches
`AdmissionRequest` and independently completes validation, authentication,
policy, lease, and integrity checks.
