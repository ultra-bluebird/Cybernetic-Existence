# Hearthline Recovery Expression and Pseudonymous Identity

## 1. Purpose

This specification defines two user-controlled privacy capabilities:

- Recovery-context expression with no platform-imposed verification hierarchy.
- Recipient-scoped pseudonymous identity with platform accountability.

The capabilities are designed for adults using Hearthline for dating, friendship,
activities, and community connection. They do not certify recovery, sobriety,
treatment participation, safety, honesty, compatibility, social worth, or
relationship readiness.

Hearthline supports personal choice while enforcing behavior and consent boundaries.

## 2. Conduct Boundaries

Hearthline prohibits:

```text
- Coercion
- Harassment
- Fraud
- Impersonation
- Threats
- Pressure to disclose recovery information
- Use of recovery language to override another person's consent
- Repeated contact after a block or clear boundary
- Attempts to obtain clinical, sponsor, emergency, or legal authority over another user
```

Hearthline does not:

```text
- Endorse one recovery framework over another
- Maintain an approved-pathway registry
- Treat abstinence duration as evidence of safety
- Treat treatment participation as evidence of relationship readiness
- Penalize silence
- Penalize harm-reduction language
- Penalize faith-based language
- Penalize peer-support language
- Penalize clinical language
- Penalize self-defined recovery language
```

The platform handles observable conduct and consent violations. It does not enforce
a recovery doctrine, health narrative, or personal-life classification.

## 3. Recovery Expression

### 3.1 Core rule

Recovery-context expression is voluntary, recipient scoped, purpose bound, revocable
for future Hearthline-controlled presentation, and never used in matching, ranking,
visibility, access, action-integrity controls, or public profile status.

A recovery-expression presentation may describe a limited evidentiary property. It
may not be transformed into a judgment about the person.

```text
Hearthline may describe:
- Personal expression
- Commitment timing
- Consistency of selected commitments
- A narrow supporter statement
- A narrow issuer-backed predicate

Hearthline may not describe:
- Personal honesty
- Personal virtue
- Personal safety
- Recovery quality
- Relationship readiness
- Connection eligibility
- Trustworthiness
- Desirability
```

### 3.2 Expression formats

```text
NONE
PERSONAL_NARRATIVE
TIME_BOUND_COMMITMENT
CONSISTENCY_PRESENTATION
OPTIONAL_VOUCH
OPTIONAL_ISSUER_ATTESTATION
```

These are formats, not status levels. The user interface must not render them as a
progression, ladder, badge, strength meter, score, tier, or comparative ranking.

| Format | Descriptive technical meaning | Not a claim about |
|---|---|---|
| `NONE` | The user chose not to share recovery context | Concealment, dishonesty, lower safety, or lower eligibility |
| `PERSONAL_NARRATIVE` | The user chose the statement | Objective truth, duration, clinical fact, or character |
| `TIME_BOUND_COMMITMENT` | A selected commitment existed before a time boundary | Truth, continued abstinence, safety, or reliability |
| `CONSISTENCY_PRESENTATION` | Selected commitments are linked under a chosen consistency relation | Truth, stability, future behavior, or character |
| `OPTIONAL_VOUCH` | A selected supporter made a limited statement | Universal authority, clinical validity, or safety certification |
| `OPTIONAL_ISSUER_ATTESTATION` | A selected issuer signed a narrow predicate | Wellbeing, safety, compatibility, readiness, or social worth |

### 3.3 Equal platform treatment

No expression format may affect:

```text
- Candidate presentation
- Candidate ordering
- Search
- Filters
- Profile visibility
- Mutual-interest eligibility
- Messaging access
- Waypoint planning access
- SteadyPath pacing
- Account capabilities
- Lantern action state
- Public profile status
- User pricing
- Analytics profiling
- External provider access
```

A user who selects `NONE` must receive no negative label, explanation, visibility
change, capability restriction, recipient notice, or account-state change.

### 3.4 Recipient presentation

A recovery expression may render only after CommonGround confirms a current,
recipient-specific scope for the selected purpose.

Recipient-facing notice:

```text
This is a personal disclosure chosen for this conversation.
It describes only the selected claim format.
It does not rate honesty, safety, compatibility, wellbeing, or readiness.
```

Issuer-backed presentation notice:

```text
This presentation verifies only the selected statement from the named source.
It does not certify the person or predict future behavior.
```

Hearthline must not provide:

```text
- Request verification
- Ask for recovery proof
- Show only verified people
- Filter by sobriety duration
- Filter by verification format
- Compare claims
- Show verification status
- Report someone for declining to verify
- Send a prewritten proof request
```

### 3.5 Privacy controls

Every presentation is:

```text
- Private to one recipient
- Purpose bound
- Expiring where the selected format supports expiry
- Revocable for future Hearthline-controlled rendering
- Non-public
- Excluded from matching and ranking
- Excluded from analytics profiles
- Excluded from cross-platform account linkage
- Excluded from automatic issuer contact
```

Hearthline must not maintain:

```text
- A central recovery-claim registry
- A recovery-duration directory
- A holder lookup endpoint
- A public recovery badge
- A public or private recovery score
- An issuer ranking
- A platform-issued recovery certificate
```

### 3.6 User-facing holder notice

```text
You never need to share or verify recovery information to use Hearthline.
Other people cannot request proof through Hearthline.
You decide what to share, with whom, and for how long.
You can stop future sharing at any time.
```

## 4. Recipient-Scoped Pseudonymous Identity

### 4.1 Core binding

```text
recipient_scoped_persona_ref
  ↔ opaque_internal_account_ref
  ↔ AnchorLine account protection
  ↔ CommonGround consent enforcement
  ↔ Lantern action-scoped integrity control
  ↔ Afterlight privacy-minimized accountability
```

The internal account reference is opaque and exists only for narrowly authorized
platform operations. A recipient-facing persona must not bind to legal identity,
recovery context, health information, another recipient persona, external social
identity, public reputation, or social score.

### 4.2 Persona states

```text
PERSONA_DRAFT
PERSONA_ACTIVE
PERSONA_PAUSED_BY_USER
PERSONA_REVOKED_BY_USER
PERSONA_EXPIRED
```

The following states are prohibited:

```text
SUSPICIOUS_PERSONA
UNTRUSTED_PERSONA
FAKE_PERSONA
RECOVERY_PERSONA
HIGH_RISK_PERSONA
```

Technical action controls belong to Lantern and must never become a social persona
classification.

### 4.3 Recipient isolation

A recipient may see only their authorized persona presentation.

A recipient must not learn:

```text
- Whether the account has other personas
- Other display names used by the account
- Legal name
- Recovery status
- Health information
- Account age
- Credential-continuity history
- Guardian relationship status
- Lantern state
- Reports
- Match count
- External accounts
- Persona count
- Identity linkage graph
```

No recipient-facing API, export, audit projection, notification, or error response
may reveal whether two personas belong to the same account.

### 4.4 Platform accountability

Pseudonymity does not bypass:

```text
- Mutual-match-only messaging
- Current consent checks
- Recipient-scoped block
- User-initiated reporting
- Action-specific rate control
- Request replay protection
- Passkey-first authentication
- Credential-continuity controls
- Content-free audit events
```

These controls operate only against the opaque internal account reference. They are
never exposed as recipient-facing trust, reputation, verification, or safety signals.

### 4.5 Persona privacy review

Before activation or scope expansion, the account holder reviews:

```text
- Display name
- Photos
- Broad region
- Interests
- Personal details
- Profile wording
- External handles
```

The review warns that pseudonymity cannot prevent identity inference through photos,
writing style, mutual acquaintances, unique biographical details, locations,
screenshots, external profiles, or off-platform disclosures.

## 5. Service Wiring

```text
AnchorLine
→ authenticates opaque internal account reference

CommonGround
→ validates current recipient and purpose scope for recovery expression
→ validates current recipient scope for persona rendering

Recovery Expression Service
→ returns a recipient-scoped presentation only after CommonGround approval
→ produces no matching, ranking, reputation, or public-profile signal

Recipient Persona Resolver
→ returns one active persona for authenticated account and authorized recipient
→ never accepts a recipient-supplied persona reference as authority

TrueCompass
→ cannot read recovery-expression records
→ cannot read persona registry records
→ cannot use expression format or persona state as input

Lantern
→ may act only on opaque account and action-window signals
→ cannot read recovery-expression payloads
→ cannot read persona state or persona count

BridgeAdapters
→ cannot receive persona linkage or recovery-expression data
→ cannot infer account identity from recipient persona values

Afterlight Ledger
→ receives content-free operational events only
→ excludes persona display text, recipient identity, recovery field names,
  expression content, proof payload, and raw identity material
```

## 6. Required Tests

| Test ID | Scenario | Required outcome |
|---|---|---|
| `REPI-001` | User selects no recovery expression | No recipient signal, match effect, rank effect, or capability effect occurs |
| `REPI-002` | User presents an issuer-backed predicate | Recipient sees predicate limits only; no safety, honesty, or compatibility claim appears |
| `REPI-003` | Recipient attempts to filter by verification | UI, API, and query path are absent or denied |
| `REPI-004` | Recipient attempts to request proof | No product affordance or service operation exists |
| `REPI-005` | Recovery expression expires | Future rendering stops with no badge removal, recipient notice, or negative state |
| `REPI-006` | External provider offers a recovery-profile attribute | BridgeAdapter rejects the attribute |
| `REPI-007` | TrueCompass receives recovery-expression input | Service boundary rejects the request |
| `REPI-008` | User reports disclosure pressure | Case intake is available without requiring recovery disclosure |
| `REPI-009` | User activates recipient persona | Recipient sees only authorized display name and consent-visible fields |
| `REPI-010` | Recipient A attempts persona linkage to Recipient B | API, store, events, logs, exports, and profile routes deny linkage |
| `REPI-011` | Lantern receives a pseudonymous action | Control is account-scoped; recipient receives no Lantern signal |
| `REPI-012` | User revokes persona | Future authorized rendering stops without recipient linkage notice |
| `REPI-013` | Persona includes legal, recovery, health, or external identity data | Schema and service validation reject it |
| `REPI-014` | BridgeAdapter requests persona linkage | Request is denied; no external provider receives account-persona correlation |
| `REPI-015` | Backup, crash trace, or analytics export is inspected | No recovery content, persona linkage, legal identity, or recipient mapping appears |
