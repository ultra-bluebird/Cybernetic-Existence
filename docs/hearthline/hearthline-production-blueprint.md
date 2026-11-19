# Hearthline Production Blueprint

## 1. Purpose

Hearthline is a consent-first adult connection environment designed for dating,
friendship, local activities, and community connection. It offers private,
recovery-aware accessibility and pacing tools without requiring a user to
disclose recovery status, treatment history, health information, or a life stage.

Hearthline does not diagnose, certify, monitor, infer, rank, or disclose recovery
status. It does not promise romantic success, recovery outcomes, safety from every
harm, or trustworthiness of another person.

Hearthline exists to reduce avoidable barriers to connection:

- Password and credential burden
- Unwanted disclosure of private profile information
- Pressure-based dating mechanics
- Stale AI-generated drafts after consent changes
- Burst-style automated misuse of connection features
- Confusing account continuity after device loss
- Social pressure caused by public status, reputation, or ranking

## 2. Public and Internal Names

```text
Public product: Hearthline
Security and credential center: AnchorLine
Consent and disclosure center: CommonGround
Pacing and accessibility center: SteadyPath
Private candidate presentation: TrueCompass
Action-integrity controls: Lantern
AI-chat drafting and reflection: HearthChat
External provider boundary: BridgeAdapters
Privacy-minimized accountability: Afterlight Ledger
Optional meeting-planning checklist: Waypoint
```

Public positioning:

```text
Hearthline
Connection at your pace.

Private, low-pressure ways to meet people for dating, friendship, and community.
```

Hearthline must not use public product descriptions that require or imply recovery
disclosure.

## 3. Product Boundaries

### 3.1 Included capabilities

```text
- Private connection profiles
- Mutual-interest and paced introductions
- Per-field and per-recipient consent
- Passkey-first account access
- Accessible account-continuity guidance
- AI-generated drafting and reflection suggestions
- User-selected pacing and low-energy presentation
- Optional meeting-planning checklists
- Supported provider connections through documented authorization mechanisms
- User-controlled imports and exports
- Privacy-minimized user-readable security history
```

### 3.2 Excluded capabilities

```text
- Medical assessment, diagnosis, monitoring, or treatment
- Recovery-status certification
- Recovery-stage storage or inference
- Public reputation, trust, desirability, popularity, or compatibility scores
- Autonomous messages, likes, profile publication, reporting, or external actions
- Password collection or storage for third-party platforms
- Scraping, unofficial APIs, credential replay, or session imitation
- Live location tracking, mandatory check-ins, autonomous transport booking,
  or third-party contact
- Public “last active,” response-rate, streak, urgency, or inactivity pressure
- Matching based on health, recovery, accessibility, fraud, financial, legal,
  employment, housing, behavioral, or social-graph information
```

## 4. Trust Zones

```text
Device zone:
- User-controlled browser, native client, platform authenticator,
  hardware security key, and protected local storage where available.

Identity zone:
- AnchorLine account, credential lifecycle, session, and continuity controls.

Consent zone:
- CommonGround field-level and recipient-level disclosure decisions.

Connection zone:
- TrueCompass, SteadyPath, Waypoint, and HearthChat user-facing workflows.

Integrity zone:
- Lantern action-scoped controls with dedicated data boundary.

Integration zone:
- Isolated BridgeAdapters for supported providers.

Governance zone:
- Afterlight Ledger, retention jobs, review controls, audit projections,
  policy versioning, and release evidence.
```

No zone may use another zone's sensitive data without an explicit service contract,
least-privilege authorization, and a documented purpose.

## 5. Identity Continuity

### 5.1 Stage-agnostic identity states

```text
IDENTITY_ACTIVE
IDENTITY_PAUSED_BY_USER
IDENTITY_DORMANT
IDENTITY_REACTIVATED
IDENTITY_CREDENTIAL_CONTINUITY_PENDING
IDENTITY_CREDENTIALS_REVOKED
IDENTITY_CLOSED_BY_USER
```

The following are forbidden in identity, credential, matching, integrity, audit,
notification, adapter, analytics, and preference records:

```text
IN_RECOVERY
STABLE_RECOVERY
EARLY_SOBRIETY
RELAPSED
RE_ENTERED_TREATMENT
RECOVERY_RISK
NOT_READY_TO_DATE
RECOVERY_STATUS
RECOVERY_HISTORY
TREATMENT_HISTORY
SUBSTANCE_USE_HISTORY
```

### 5.2 Identity continuity function

```text
continuity(identity, time) =
  credential_persistence(identity, time)
  AND consent_persistence(identity, time)
  AND user_selected_account_persistence(identity, time)
```

The continuity function must not include health, recovery, behavior, social value,
relationship activity, account tenure, or response-pattern inputs.

### 5.3 Support preferences

Support preferences are private interface settings, not identity labels.

Allowed examples:

```text
- Manual candidate review
- Low-energy display mode
- Slower conversation pace
- Privacy review before expansion
- Neutral reminder language
- Support-resource entry-point visibility
- One candidate at a time
- Digest-only notifications
```

Prohibited interpretations:

```text
- Low-energy mode means the user has a health condition.
- Slower pace means the user is in early recovery.
- Neutral reminders mean the user has memory impairment.
- Manual review means the user is unsafe or unreliable.
```

## 6. CommonGround Consent

### 6.1 Consent rule

A protected field may render only when current, explicit, recipient-specific consent
permits it at the moment of use.

```text
render_allowed(artifact, recipient, field, time) =
  current_explicit_grant(recipient, field, time)
  AND artifact_is_current(artifact, time)
  AND purpose_is_allowed(artifact, field, time)
```

### 6.2 Consent states

```text
NO_GRANT
GRANTED
REVOKED
EXPIRED
```

### 6.3 Protected fields

```text
display_name
photo
city_region
interests
recovery_context
meeting_preference
phone_number
external_handle
```

Recovery context is always optional, per-recipient, revocable, and excluded from
matching, ranking, safety-readiness, fraud controls, and public display.

### 6.4 Revocation behavior

A revocation stops future platform-controlled disclosure of the affected field.

```text
Revocation affects:
- Future profile rendering
- Future AI suggestions
- Current AI draft rendering
- Send preview
- Final send submission
- Export preparation and download
- Queued notifications
- Platform-controlled cached views after synchronization

Revocation does not guarantee:
- Recall of sent text
- Removal from recipient screenshots
- Removal from copied content
- Removal from browser extensions, OS artifacts, or compromised endpoints
- Removal from content retained outside Hearthline
```

Recipient-facing notifications about a sender's consent revocation are prohibited.

## 7. HearthChat Suggestion Safety

### 7.1 Suggestion states

```text
RENDER_REQUIRES_CURRENT_CONSENT
RENDER_ALLOWED
INVALIDATED_BY_SCOPE_CHANGE
EXPIRED
```

### 7.2 Suggestion lifecycle

```text
Generate suggestion
→ tag protected-field manifest and policy revision
→ evaluate current consent before every controlled use
→ render only when every required scope remains permitted
→ invalidate on scope revocation, expiry, or mismatch
→ show sender a generic explanation
→ require a newly generated suggestion after invalidation
```

An invalidated draft is not reactivated after a later grant. A later grant creates a
new consent context. The user may request a new suggestion based only on currently
allowed content and a non-sensitive user-owned intent summary.

### 7.3 Invalidation receipt

A receipt may exist only when required for integrity, user review, or bounded support.

It may contain:

```text
- Opaque receipt reference
- Opaque subject reference
- Receipt class
- Coarse invalidation epoch
- Retention expiry
- Policy version
- Content-free integrity acknowledgement
```

It must not contain:

```text
- Suggestion text
- Prompt text
- Conversation text
- Recipient reference
- Recipient identity
- Protected field name
- Invalidated field count
- Recovery context
- Raw consent value
- Exact content digest
```

## 8. AnchorLine Credentials

### 8.1 Authentication baseline

```text
- Passkey-first
- WebAuthn user verification required for sensitive authentication events
- Password-only authentication prohibited
- Platform password collection prohibited
- Credentials may include platform passkeys and optional hardware security keys
- Session state must not survive device lock when the platform can enforce that property
```

### 8.2 Account-continuity paths

```text
1. Existing primary or secondary passkey
2. Registered hardware security key
3. User-held offline recovery code
4. User-designated recovery-contact process
5. Privacy-minimized re-proofing process
6. Advanced optional multi-party continuity method
```

Recovery contacts may assist only with a time-bounded continuity request.

Recovery contacts may not:

```text
- View profiles
- View messages
- View matches
- View consent scopes
- View recovery context
- View account activity
- View credential material
- Rebind a passkey alone
- Link an external provider
- Take an action for the account holder
```

### 8.3 Credential continuity lifecycle

```text
CONTINUITY_REQUESTED
→ CONTINUITY_PATH_SELECTED
→ EVIDENCE_VALIDATED
→ RISK_REVIEW
→ NEW_PASSKEY_BINDING
→ INDEPENDENT_NOTIFICATIONS
→ COOLDOWN_ACTIVE
→ CONTINUITY_COMPLETED
```

Cooldowns may protect high-impact account operations but may never block:

```text
- Consent revocation
- Account pause
- Block
- Safety reporting
- Support-resource access
- Viewing security history
```

## 9. MemoryAidCoordinator

### 9.1 Purpose

MemoryAid reduces cognitive burden through neutral reminders, plain-language setup
guidance, and user-selected notification cadence. It is not an authenticator,
credential store, recovery-secret delivery channel, or recovery-state classifier.

### 9.2 Reminder delivery classes

```text
CLASS_A_LOCAL_UI_ONLY
CLASS_B_NEUTRAL_DEVICE_NOTIFICATION
CLASS_C_USER_INITIATED_GUIDANCE
```

### 9.3 Safe notification examples

```text
Hearthline is ready when you are.
A saved account step is ready for review.
You asked for a privacy check-in.
You can continue a setup step when ready.
A connection setting is ready for review.
```

### 9.4 Prohibited notification content

```text
Passwords
Passkeys
Credential identifiers
Verification codes
Recovery codes
OAuth tokens
Recovery-contact names
Recovery-share material
Authenticator attestation data
Recipient identity
Match identity
Consent field names
Recovery context
Health information
```

## 10. SteadyPath Pacing

### 10.1 Connection states

```text
DISCOVERABLE
MUTUAL_INTEREST
CONSENT_REVIEWED
LIMITED_CONVERSATION
USER_CONFIRMED_EXPANSION
OPTIONAL_MEETING_PLANNING
PAUSED
```

### 10.2 No-penalty pause

A pause is a user-owned control overlay.

```text
When paused:
- New exposure stops
- New connection pressure stops
- No rank penalty occurs
- No visibility penalty occurs
- No inactivity label appears
- No streak is created or lost
- No pause reason is stored
- No pause reason is shown to another user
```

### 10.3 Low-energy mode

Low-energy mode may:

```text
- Show one candidate at a time
- Use digest-only notifications
- Simplify the message composer
- Offer save-and-return drafting
- Reduce visible choices
- Use plain-language explanations
```

Low-energy mode must not:

```text
- Change matching
- Change consent scopes
- Change fraud or integrity state
- Infer health or recovery state
- Reveal a reason to another user
- Reduce account-authentication assurance
```

## 11. TrueCompass Candidate Presentation

### 11.1 Purpose

TrueCompass privately presents candidates based on mutually available, declared,
consent-visible preferences. It does not calculate human worth, public compatibility,
safety, reliability, recovery compatibility, popularity, or desirability.

### 11.2 Allowed inputs

```text
- Adult eligibility
- Reciprocal age preferences
- Declared connection intent
- User-visible interests
- User-visible pacing preference
- User-visible broad area
- Current consent visibility state
```

### 11.3 Prohibited inputs

```text
- Recovery status or recovery history
- Health information
- Lantern integrity state
- Authentication history
- Device integrity state
- Message contents
- Response speed
- Likes
- Popularity
- Match history
- Account tenure
- External social graph
- Legal history
- Financial status
- Employment status
- Housing status
- Accessibility profile
```

### 11.4 Presentation format

TrueCompass may show:

```text
Shown because:
- You selected compatible connection intentions.
- You both chose a similar conversation pace.
- You share interests that you both chose to list.
- Your chosen broad areas overlap.
```

TrueCompass must not show:

```text
Compatibility: 84%
Trust score: 8.9
Highly compatible
Most desirable
Safer than average
Likely to respond
Best match
```

Private ordering values are session-scoped implementation details and must not be
persisted as person scores, exposed to candidates, used by analytics, or used to
modify anyone's visibility.

## 12. Lantern Action Integrity

### 12.1 Purpose

Lantern reduces narrowly defined technical abuse pressure. It does not decide whether
a person is trustworthy, deceptive, safe, desirable, in recovery, medically stable,
socially valuable, or suitable as a match.

### 12.2 States

```text
NORMAL
ELEVATED_SCRUTINY
RATE_LIMITED
```

These apply to a specific account action and short time window, not to a person.

### 12.3 Allowed actions

```text
- Require fresh user verification before linking a provider
- Slow a burst of message requests
- Temporarily limit suspicious profile-creation velocity
- Delay a high-impact credential continuity modification for review
- Require retry after repeated failed credential events
- Open a review case after a concrete report
```

### 12.4 Forbidden judgments

```text
This person is trustworthy.
This person is deceptive.
This person is undesirable as a match.
This person should appear lower in search.
This person is in recovery.
This person has a medical, behavioral, legal, financial, or social condition.
```

### 12.5 Minimal technical signal categories

```text
- Current WebAuthn assertion result where required for the action
- Bounded action velocity
- Bounded failed-attempt count for the same action
- Request replay anomaly
- Case-review state from a concrete report
```

Lantern must not use timing alone to restrict an action. A single report must create
case intake, not an automatic restrictive state.

### 12.6 Structural separation

```text
Lantern has:
- Dedicated data store
- Dedicated service identity
- Dedicated encryption context
- Action-control API only
- Content-free cross-service event payloads

Matching, discovery, profiles, HearthChat, BridgeAdapters, and person-level analytics have:
- No Lantern database credential
- No Lantern API permission
- No Lantern event subscription
- No Lantern network route
```

## 13. Private Technical Capability Checklist

### 13.1 Purpose

Hearthline does not operate a progressive trust ladder. It provides a private,
user-visible technical capability checklist based only on direct prerequisites.

### 13.2 Prohibited ladder stages

```text
MUTUAL_MATCH_HISTORY
CONSENT_HONORING_STREAK
LONG_TERM_PARTICIPANT
TRUST_LEVEL
REPUTATION_LEVEL
RELIABILITY_LEVEL
SAFETY_SCORE
RELATIONSHIP_READINESS
```

### 13.3 Universal safety floor

Every user may always:

```text
- Pause connection activity
- Revoke or narrow consent
- Block or mute another account
- Submit a safety report
- View privacy controls
- View their security history
- Request review of an active action pause
- Use low-energy presentation
- Save supported local drafts
- Access support-resource information
- Start account-continuity guidance
- Use limited in-app conversation after mutual current consent
```

### 13.4 Direct-purpose optional tools

```text
Second passkey enrollment:
- Requires current secure verification

Account export:
- Requires fresh secure verification

Supported provider connection:
- Requires user consent, current secure verification, and provider support

Optional meeting-planning checklist:
- Requires current consent and dual participant confirmation

User-selected visibility window:
- Requires user selection only

Local preference storage:
- Requires user opt-in and available protected device storage
```

No optional tool may depend on tenure, matches, reports, popularity, response speed,
consent compliance, recovery information, Lantern state, or accessibility profile.

## 14. BridgeAdapters

### 14.1 Supported integration tiers

```text
FULL_AUTHORIZATION
FEDERATED_SIGN_IN
USER_MEDIATED_IMPORT
NO_SUPPORTED_CONNECTION
```

### 14.2 Required adapter properties

```text
platform_id
adapter_version
integration_tier
authorization_endpoint
token_endpoint
revocation_endpoint
redirect_uri_allowlist
authorization_code_flow_required = true
pkce_required = true
pkce_challenge_method = S256
minimal_scopes
refresh_token_storage_model
refresh_replay_protection
token_lifetime_ceiling_seconds
disclosure_scope_map
audit_event_type_map
cross_adapter_data_sharing_prohibited = true
external_action_authorized = false
```

### 14.3 Token storage models

```text
NO_REFRESH_TOKEN
OS_PROTECTED_NATIVE_STORE
SERVER_SIDE_CONFIDENTIAL_BROKER
```

Long-lived provider tokens must not be stored in unprotected browser storage.

### 14.4 Adapter isolation

A provider connection must not permit:

```text
- Token use at another provider
- Scope reuse at another provider
- Identity linkage across adapters
- Cross-adapter recipient mapping
- Cross-adapter profile lookup
- One adapter failure controlling another adapter session
- Password collection
- Password storage
```

## 15. Afterlight Ledger

### 15.1 Purpose

Afterlight records privacy-minimized operational decisions and lifecycle events for
user review, security investigation, retention enforcement, and policy accountability.

It is not:

```text
- A message archive
- A relationship diary
- A recovery-status record
- A credential vault
- A behavioral score
- A public reputation system
- A raw-content forensic store
```

### 15.2 Required audit fields

```text
event_ref
actor_role
subject_ref
operation_type
decision
policy_version
occurred_at
retention_expires_at
optional_resource_ref
optional_correlation_ref
reason_family
```

### 15.3 Required exclusions

```text
content_included = false
credential_material_included = false
identity_token_included = false
biometric_material_included = false
recovery_material_included = false
recipient_reference_included = false
protected_field_name_included = false
external_action_authorized = false
```

### 15.4 User-readable history

The user may see:

```text
- You updated a privacy choice.
- An unsent suggestion became unavailable under your current privacy choices.
- A sign-in method was added or removed.
- A connection step moved forward with your confirmation.
- You paused connection activity.
- A provider connection was linked or disconnected.
- A specific action was briefly paused.
- You requested a review.
- A review was completed.
```

The user must not see raw event references, anti-abuse thresholds, other-user data,
credential material, recovery data, protected-field names, or invalidated text.

## 16. Waypoint Safe Introduction Protocol

### 16.1 Progression

```text
DISCOVERABLE
→ MUTUAL_INTEREST
→ CONSENT_REVIEWED
→ LIMITED_CONVERSATION
→ USER_CONFIRMED_EXPANSION
→ OPTIONAL_MEETING_PLANNING
```

A user may pause from any state. Either participant may narrow a connection from
expanded interaction or optional planning back to limited conversation.

### 16.2 Transition rule

```text
advance(connection, current_state, next_state, time) =
  valid_current_state
  AND each_participant_independently_confirmed
  AND current_consent_permits_transition
  AND neither_participant_is_paused
```

No connection transition automatically grants a sensitive profile scope.

### 16.3 State visibility

```text
DISCOVERABLE:
- Alias or display name
- Broad connection intent
- Broad region
- User-approved interests

MUTUAL_INTEREST:
- Mutual-interest acknowledgement only

CONSENT_REVIEWED:
- Current user-selected visibility choices only

LIMITED_CONVERSATION:
- In-app conversation
- Only currently granted fields

USER_CONFIRMED_EXPANSION:
- User-selected additional preferences
- No permanent or unilateral sharing

OPTIONAL_MEETING_PLANNING:
- Private optional checklist
- No tracking
- No booking
- No external contact
- No mandatory check-in
```

## 17. Threat Model and Limits

### 17.1 In-scope threats

```text
- Stale unsent AI-generated disclosures
- Cached platform-controlled rendering
- Queued platform notifications
- Burst message or profile action abuse
- Request replay
- Credential-event bursts
- Cross-service data misuse attempts
- False-positive technical action controls
- Unsupported provider integration requests
```

### 17.2 Residual risks

```text
- A recipient retaining content already sent
- Screenshots and clipboard copies
- Browser extensions and compromised endpoints
- Side-channel inference
- Insider misuse
- Legal process
- Operator succession or governance change
- Subjective experience of a technical restriction as negative or stigmatizing
```

### 17.3 User-facing limitation

```text
Changing a privacy choice stops Hearthline from showing or sending unsent content
that depends on that choice. It cannot remove information another person already
received, copied, screenshotted, or saved outside Hearthline.
```

## 18. Service Wiring

```text
AnchorLine
→ CommonGround
  Current authentication context for sensitive consent operations

CommonGround
→ HearthChat
  Current scope decision for suggestion generation, rendering, copy, export,
  notification preparation, send preview, and final send submission

CommonGround
→ Waypoint
  Current transition permission

CommonGround
→ TrueCompass
  Current visibility decision for declared candidate attributes

SteadyPath
→ TrueCompass
  User-selected candidate presentation cadence

SteadyPath
→ Waypoint
  Pause and pacing gate

MemoryAidCoordinator
→ AnchorLine
  Non-secret account-step status only

MemoryAidCoordinator
→ SteadyPath
  User-selected reminder cadence only

TrueCompass
→ User interface
  Private explanations only

Lantern
→ Action gateway
  Bounded action-control decision only

Lantern
× TrueCompass
  No read path

Lantern
× HearthChat
  No read path

Lantern
× Profiles
  No read path

BridgeAdapters
→ AnchorLine
  Fresh secure verification requirement

BridgeAdapters
→ CommonGround
  User-approved scope map

Afterlight
← AnchorLine
← CommonGround
← HearthChat
← SteadyPath
← TrueCompass
← Lantern
← BridgeAdapters
← Waypoint

Afterlight
→ My privacy and security history
  Allowlisted plain-language projection only
```

## 19. Directory Layout

```text
docs/hearthline/
  hearthline-production-blueprint.md
  threat-model.md
  known-limitations.md
  my-security-history-spec.md
  capability-governance.md

schemas/
  hearthline-identity-continuity.schema.json
  hearthline-consent-scope.schema.json
  hearthline-suggestion-invalidation.schema.json
  hearthline-minimized-invalidation-receipt.schema.json
  hearthline-memory-aid-reminder.schema.json
  hearthline-lantern-interaction-integrity.schema.json
  hearthline-lantern-access-boundary.schema.json
  hearthline-private-safety-readiness.schema.json
  hearthline-capability-decision.schema.json
  hearthline-bridge-adapter.schema.json
  msfp-audit-event.schema.json

schemas/sql/
  hearthline_identity_continuity_registry.sql
  hearthline_consent_registry.sql
  hearthline_afterlight_ledger.sql
  hearthline_lantern_registry.sql
  hearthline_capability_decision_registry.sql

src/hearthline/
  consent/common-ground-render-guard.js
  consent/common-ground-prompt-budget.js
  chat/hearth-chat-suggestion-guard.js
  chat/hearth-chat-scope-guard.js
  identity/anchor-line-webauthn-options.js
  identity/anchor-line-recovery-ceremony.js
  integrations/bridge-adapter-validator.js
  integrity/lantern-reason-codes.js
  matching/true-compass-alignment.js
  governance/boundary-assurance-evaluator.js

kotlin/
  hearthline-credentials/src/main/kotlin/org/augmentedhub/hearthline/accessibility/MemoryAidCoordinator.kt
  hearthline-consent/src/main/kotlin/org/augmentedhub/hearthline/consent/ConsentDecisionService.kt
  hearthline-chat/src/main/kotlin/org/augmentedhub/hearthline/chat/SuggestionInvalidationService.kt
  hearthline-pacing/src/main/kotlin/org/augmentedhub/hearthline/pacing/SteadyPathPacingService.kt
  hearthline-matching/src/main/kotlin/org/augmentedhub/hearthline/matching/TrueCompassService.kt
  hearthline-identity/src/main/kotlin/org/augmentedhub/hearthline/identity/IdentityContinuityService.kt
  hearthline-capabilities/src/main/kotlin/org/augmentedhub/hearthline/capabilities/DirectPurposeCapabilityService.kt
  hearthline-introductions/src/main/kotlin/org/augmentedhub/hearthline/waypoint/WaypointProtocolService.kt

java/
  hearthline-accessibility/src/main/java/org/augmentedhub/hearthline/MemoryAidNotificationValidator.java
  hearthline-fraud/src/main/java/org/augmentedhub/hearthline/LanternIntegrityEvaluator.java
  hearthline-integrations/src/main/java/org/augmentedhub/hearthline/BridgeTokenValidationPolicy.java
  hearthline-audit/src/main/java/org/augmentedhub/hearthline/AfterlightAuditWriter.java

lua/
  hearthline_suggestion_invalidation_router.lua
  hearthline_steady_path_visibility_router.lua
  hearthline_waypoint_transition_router.lua

cpp/hearthline_integrity/include/
  lantern_window_counter.hpp

policies/
  hearthline-common-ground-and-anchor-line.aln
  hearthline-hearthchat-lantern.aln
  hearthline-steady-path.aln
  hearthline-true-compass.aln
  hearthline-bridge-adapters.aln
  hearthline-memory-aid.aln
  hearthline-identity-continuity.aln
  hearthline-direct-purpose-capabilities.aln
  hearthline-waypoint-introductions.aln
  hearthline-boundary-mechanism.aln
```

## 20. Acceptance Matrix

### 20.1 HearthChat and Lantern

```text
HC-INV-001:
Protected suggestion is revoked before reopening.
Expected: original text is unavailable; sender sees generic privacy-change explanation.

HC-INV-002:
Revocation occurs in another tab.
Expected: active tab invalidates before additional controlled interaction.

HC-INV-003:
Client is offline during revocation.
Expected: protected cached content remains unavailable until fresh scope synchronization.

HC-INV-004:
Scope is later granted again.
Expected: invalidated original remains unavailable; new suggestion required.

HC-INV-005:
Audit query occurs.
Expected: opaque receipt, epoch, state, and policy version only.

LAN-001:
Normal authenticated action pace.
Expected: NORMAL; no matching, profile, or visibility effect.

LAN-002:
Short action burst.
Expected: bounded action-specific scrutiny or rate limit with explanation and expiry.

LAN-003:
Replay anomaly during credential continuity.
Expected: action-specific temporary restriction; continuity review remains available.

LAN-004:
Assistive-technology or irregular timing profile.
Expected: no action restriction from timing alone.

LAN-005:
Matching service requests Lantern state.
Expected: denied by network, identity, API, and store boundaries; denial recorded.

LAN-006:
Aggregate integrity report is generated.
Expected: no person-level decision is published or perturbed.
```

### 20.2 Pacing and adapters

```text
SP-001:
Pause during limited conversation.
Expected: requests and pressure prompts stop; no rank or visibility penalty.

SP-002:
Low-energy mode enabled.
Expected: simpler presentation; no consent, profile, or integrity-state change.

SP-003:
One participant requests expansion.
Expected: remains limited conversation; no new field renders.

SP-004:
Visibility window closes.
Expected: interactions are held without urgency or disclosure.

SP-005:
User returns after absence.
Expected: discoverable only through current preferences; no inactivity label.

BA-001:
Adapter requests implicit or password grant.
Expected: adapter registration rejected.

BA-002:
Adapter receives unlisted redirect URI.
Expected: authorization response rejected.

BA-003:
Adapter A token offered to adapter B.
Expected: issuer, audience, namespace, and platform validation reject it.

BA-004:
Refresh token storage without replay protection.
Expected: adapter registration rejected.

BA-005:
Provider lacks supported authorization interface.
Expected: no adapter registration; Hearthline Core remains usable.

BA-006:
One adapter compromise is simulated.
Expected: other adapter namespaces, sessions, and token contexts remain isolated.
```

### 20.3 Red-team verification

```text
RT-001:
Revocation occurs between draft rendering and send.
Expected: server rejects protected content at send preview and final submission.

RT-002:
Counterparty attempts timing inference.
Expected: no recipient invalidation notice or counterparty-visible state exists.

RT-003:
Telemetry captures composer content.
Expected: build and runtime egress controls reject the payload.

RT-004:
Offline client has stale protected draft.
Expected: redaction until current scope is synchronized.

RT-005:
Matching service reads Lantern.
Expected: all technical boundaries deny access.

RT-006:
Legitimate irregular activity triggers repeatedly.
Expected: review pathway activates; no permanent person-level profile is created.

RT-007:
Coordinated false reports target an account.
Expected: case intake only; no automatic restrictive action without corroborated evidence
or narrowly reviewed emergency control.

RT-008:
Low-and-slow abuse remains under thresholds.
Expected: system does not overclaim Lantern prevention; mutual consent, scope limits,
block, report, and account security reduce exposure.

RT-009:
Logs, backups, crash traces, and observability exports are inspected.
Expected: no suggestion content, field names, recipient references, raw secrets,
or recovery-revealing terms.

RT-010:
HearthChat attempts to infer Lantern state through timing.
Expected: no direct calls; bounded response design and monitoring identify
material latency differences.
```

## 21. Release Gates

```text
Gate 1: Schema review
- No health, recovery, reputation, or person-score fields.

Gate 2: Access review
- Lantern, capability, and support-preference stores are inaccessible to matching,
  discovery, profiles, HearthChat, adapters, and person-level analytics.

Gate 3: Consent review
- Revocation works across render, copy, export, notification, send preview,
  final send, active tabs, and offline recovery.

Gate 4: Credential review
- Password-only paths are absent.
- Fresh secure verification is required for sensitive actions.
- Continuity flows are tested for device loss and social engineering.

Gate 5: Accessibility review
- Neutral reminders contain no secrets.
- Low-energy mode reduces cognitive burden without weakening security.
- Review and continuity flows are understandable and resumable.

Gate 6: Integration review
- Every adapter has documented provider authorization, exact redirects, PKCE,
  minimal scopes, token storage posture, revocation behavior, and maintenance owner.

Gate 7: Red-team review
- Cross-service leakage, sink leakage, timing, stale cache, false reports,
  slow attacks, and privileged-access scenarios are tested.

Gate 8: User comprehension review
- Users distinguish future disclosure revocation from recall of sent content.
- Users understand pause, limited conversation, expansion, and optional planning
  as choices rather than obligations.
```

## 22. Maintenance

```text
Every relevant release:
- Re-run affected consent, telemetry, cache, notification, adapter, and access tests.

Quarterly:
- Review retention expiry, privileged access, denied internal queries,
  false-positive action controls, accessibility outcomes, and sink inventory.

Annually:
- Independent adversarial assessment.
- Update known limitations.
- Review policy versions and remove any rule without a direct purpose.

Material governance change:
- Review data transition, retention, user notice, user deletion options,
  and successor obligations before transfer.
```

## 23. Product Commitments

```text
Hearthline is designed to reduce password burden.
Hearthline lets users control who can view selected profile details.
Hearthline supports slower pacing and pause controls.
Hearthline does not send messages or disclose private fields automatically.
Hearthline provides user-controlled safety and support prompts.
Hearthline does not score social worth, recovery status, relationship fitness,
or human trustworthiness.
```
