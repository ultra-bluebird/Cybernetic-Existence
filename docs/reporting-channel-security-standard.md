# Reporting Channel Security Standard

## Purpose

This standard defines minimum security requirements for reporting channels,
including SMS gateways, USSD, PWA, voice systems, in-person assisted intake,
case portals, accessibility intermediaries, and translation support workflows.

It protects reporter confidentiality, case integrity, anti-retaliation routing,
contact-envelope separation, accessibility, and auditability. It does not
authorize surveillance, identity inference, public disclosure, operational
control, field activity, or external action.

## Security Predicate

A channel is eligible for protected reporting only when:

\[
\mathrm{secure}(c) =
\mathrm{encrypted}
\land
\mathrm{authenticated}
\land
\mathrm{auditable}
\land
\mathrm{non\text{-}repudiable}
\]

For channels that cannot independently provide one of these properties at the
transport layer, the case system MUST add compensating controls before the
channel can carry protected case content.

## Required Properties

### 1. Encrypted

Protected content must be encrypted in transit and at rest.

- Use current, reviewed transport encryption for network channels.
- Encrypt stored case records and contact envelopes separately.
- Use distinct encryption key scopes for public derivatives, restricted case
  records, and contact envelopes.
- Do not place protected report content in SMS body text, USSD session text,
  voicemail transcripts, email subjects, URLs, logs, analytics events, or
  push-notification previews when those channels cannot provide the required
  protection.
- For low-security channels, collect only a short intake token or request for
  contact through the channel, then move protected content into a secure,
  accessible workflow.

### 2. Authenticated

The system must authenticate the channel endpoint, service integration, or
authorized intake worker without forcing unnecessary reporter identity
disclosure.

- Authenticate services and staff using least-privilege credentials.
- Bind case-owner access to a documented role and purpose.
- Permit anonymous reporting; do not require a reporter account to submit a
  case.
- Do not treat a phone number, device ID, IP address, voice pattern, writing
  style, location, or assistive-technology signal as proof of identity.
- Use explicit consent before retaining contact information for follow-up.

### 3. Auditable

Every sensitive action must create a protected, reviewable audit event.

Audit events MUST include:

- Opaque case reference.
- Event type.
- Timestamp.
- Actor role or service identity.
- Bounded purpose.
- Access outcome.
- Integrity reference.

Audit events MUST NOT include:

- Raw report content.
- Reporter identity or contact content.
- Non-recordable knowledge.
- Precise sensitive locations.
- Credentials, encryption keys, session tokens, or biometric data.

### 4. Non-Repudiable

Case events and decisions must be integrity-protected so that material actions
cannot be silently altered or denied.

- Digitally sign or otherwise integrity-protect intake, assignment, review,
  access, correction, and closure events.
- Preserve append-only event history or an equivalent tamper-evident ledger.
- Bind signatures to role and purpose, not unnecessary public identity data.
- Rotate credentials and maintain revocation records.
- Store verification evidence separately from public case summaries.
- Provide correction records rather than rewriting historical case events.

## Channel-Specific Controls

| Channel | Permitted use | Required compensating controls |
|---|---|---|
| PWA or accessible web portal | Full protected reporting where secure transport and storage are available | TLS, secure session handling, encrypted storage, anonymous intake option, accessibility support |
| SMS | Initial contact, short token, status notification without sensitive content | No protected content in messages; use a case token and secure follow-up path |
| USSD | Minimal intake routing and accessibility-compatible navigation | Do not transmit detailed protected content; issue a short-lived secure continuation token |
| Voice | Assisted intake or accessible reporting | Authorized intake worker, secure recording/transcription controls, reporter notice, separate contact envelope |
| In-person | Assisted intake | Authorized intake worker, private setting, secure digitization, no unnecessary identity collection |
| Translation/interpreter support | Meaning-preserving assistance | Confidentiality agreement or equivalent duty, role-bound access, original-record preservation, uncertainty escalation |
| Offline paper or accessible copy | Reporter-controlled reference or assisted intake | Secure transfer to case owner, controlled digitization, retention/deletion documentation |

## Anonymous Reporting

Anonymous reporting is permitted.

\[
\mathrm{case\ identity} =
\mathrm{pseudonymous\ case\ id}
\neq
\mathrm{reporter\ identity}
\]

Reporter identity and contact method, if voluntarily supplied, must be held in a
separate encrypted contact envelope. The envelope is accessible only to the
designated case owner for a documented purpose. It is never available to
implicated parties.

## Anti-Retaliation Controls

When a report implicates a project operator, authority, supervisor, contractor,
or other potentially conflicted party:

- Route to an independent reviewer.
- Do not notify implicated parties automatically.
- Exclude implicated parties from case and contact-envelope access.
- Use minimal internal disclosure.
- Record assignment and access events in a tamper-evident audit trail.
- Maintain response-time commitments and accessible reporter updates.

## Failure Handling

A channel that cannot satisfy the security predicate MUST fail closed for
protected content.

Permitted fallback actions:

- Provide a short, non-sensitive intake token.
- Offer an accessible secure continuation path.
- Route to an authorized human-assisted intake process.
- Provide an offline or in-person alternative.
- Record the security limitation without storing protected content.

A security failure MUST NOT:

- Cause the system to infer reporter identity.
- Force disclosure of personal information.
- Expose a reporter to implicated parties.
- Downgrade case credibility.
- Convert a failed secure-channel attempt into a public record.

## Verification Checklist

Before approving a reporting channel, verify:

- [ ] Transport and storage encryption are documented.
- [ ] Service and staff authentication are documented.
- [ ] Anonymous reporting remains available where appropriate.
- [ ] Audit events are protected and content-minimized.
- [ ] Material case events are tamper-evident.
- [ ] Contact envelopes are separate from case records.
- [ ] Implicated-party exclusion is enforced.
- [ ] Accessibility and human-assisted alternatives are available.
- [ ] Low-security channels cannot carry protected content.
- [ ] Key rotation, revocation, and incident handling are documented.
- [ ] Correction and appeal workflows are supported.
- [ ] Retention, deletion, withdrawal, and access controls are documented.

## Non-Authorization Statement

This artifact does not authorize:

- field activity
- environmental release
- weather modification
- infrastructure control
- public alerting
- external data transfer
- rights-holder representation
- government representation
- operational system control

Internal research approval does not create external operational authorization.
