# MSFP Minimal Gateway and Offline Assurance Lab

## Scope

This document defines a minimal viable Message and Session Framing Protocol
(MSFP) gateway. It is intentionally fail-closed:

1. bytes are bounded before parsing;
2. only one protocol version is accepted;
3. frames must use a canonical encoding;
4. malformed, duplicate, or unknown fields are rejected;
5. authenticated decryption happens before any request payload is interpreted;
6. a policy decision happens before data is released or a capability is used;
7. revoked, expired, integrity-failed, or budget-exceeded leases terminate;
8. audit events are data-minimized;
9. restarts never reconstruct an active session from stale memory or audit data.

This is an engineering specification, not an authentication, medical,
identity, augmentation, or eligibility determination system.

## Trust Boundaries

| Boundary | Input | Rule | Output |
|---|---|---|---|
| Network to quarantine | Arbitrary bytes | Length-delimit and cap before allocation | Bounded frame candidate |
| Quarantine to parser | Bounded bytes | Strict canonical parser; no execution callbacks | Parsed envelope |
| Parser to cryptography | Parsed header and ciphertext | Version, field, nonce, and algorithm checks | Authenticated plaintext |
| Cryptography to policy | Authenticated request | Explicit policy evaluation | Permit or deny |
| Policy to service | Permit decision only | Least-privilege capability scope | Released data or action |
| Service to audit | Outcome metadata | Data-minimized, pseudonymous receipt | Retained audit event |

## Frame Acceptance

For an input byte sequence \(b\), the gateway accepts only when:

\[
\operatorname{accept}(b) \iff
\begin{aligned}
&0 < |b| \leq M_{\text{frame}} \\
&\land \operatorname{is\_canonical}(b) \\
&\land \operatorname{parse\_strict}(b) = f \\
&\land f.version = V_{\text{supported}} \\
&\land \operatorname{fields}(f) \subseteq F_{\text{allowed}} \\
&\land \operatorname{aead\_open}(f) = p \\
&\land \operatorname{policy\_permit}(f, p) \\
&\land \operatorname{lease\_active}(p.lease)
\end{aligned}
\]

Unknown fields are a rejection condition, not an ignored extension point:

\[
\operatorname{unknown}(f) =
\operatorname{fields}(f) \setminus F_{\text{allowed}}
\]

\[
\operatorname{unknown}(f) \neq \varnothing \Rightarrow
\operatorname{reject}(\texttt{UNKNOWN\_FIELD})
\]

A later protocol version must use an explicitly negotiated version and a
separate parser/schema path. Do not add `flatten`, loose maps, extension
blobs, or fallback decoders to the security boundary.

## Lease Termination

\[
\operatorname{terminate} \iff
now \geq expires\_at
\lor revoked
\lor integrity\_fail
\lor budget\_exceeded
\]

The service must test lease state immediately before every protected release.
A permit at request admission does not authorize a later release after a
revocation, expiry, integrity failure, or budget exhaustion.

## Audit Data Minimization

The audit record contains only:

- `event_type`
- `event_time`
- `session_pseudonym`
- `policy_ver`
- `outcome`
- `reason_code`
- `data_cats_requested`
- `data_cats_released`
- `retention_class`

The record must not contain raw plaintext, ciphertext, credentials, source
network address, biometric data, device inventories, identity assertions, or
unnecessary payload-derived fields.

## Offline Laboratory

The portable laboratory verifies:

- valid canonical frames are accepted only when policy and lease checks pass;
- oversized frames are rejected before parsing;
- unknown fields are rejected;
- duplicate keys and noncanonical encodings are rejected;
- authenticated-decryption failures release nothing;
- expiry and revocation races do not release data;
- capability escalation fails closed;
- restart clears volatile active sessions;
- audit output never includes forbidden secret-like fields.
