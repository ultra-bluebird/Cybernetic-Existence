# Hearthline Claim-Scope and Threat Model

## Status

- **Artifact class:** Demonstration-shell governance specification
- **Applies to:** The reviewed Hearthline static demonstration deployment only
- **Does not apply to:** Forks, derivative deployments, browser extensions,
  hosting providers, operating systems, devices, future relays, or AI providers
  unless they independently adopt and satisfy these requirements
- **Review status:** Initial implementation baseline; requires accessibility,
  security, privacy, and community-governance review before production use
- **Normative language:** “MUST”, “MUST NOT”, “SHOULD”, and “MAY” describe
  requirements for a conforming Hearthline deployment

## 1. Precise product statement

Hearthline currently is a local-first, static, single-page demonstration shell.

In the reviewed demonstration deployment, Hearthline:

1. Renders a community-conversation interface in the participant’s browser.
2. Stores a message draft in browser-local storage only when the browser permits
   that storage.
3. Adds submitted demonstration messages to the currently rendered local message
   log only.
4. Makes no chat-relay, AI-provider, analytics, advertising, identity, account,
   telemetry, or moderation-service request.
5. Does not create an account, authenticate a participant, retain a message on
   an operator service, or synchronize browser-local data to a Hearthline
   service.
6. Provides non-networking demonstration controls that explain possible future
   AI-assistance request types.
7. Must render participant-entered text as text, not trusted HTML.

Hearthline is **not currently** a live multi-participant chat service.

Hearthline is **not currently** a community-governance system, moderation
service, identity system, private-messaging service, encrypted messenger,
federated protocol, durable message store, accessibility certification, legal
compliance certification, or privacy guarantee against every local-device or
third-party risk.

## 2. Claim ledger

| Claim | Accurate scope | Evidence required | Not guaranteed |
|---|---|---|---|
| “Static” | The reviewed demonstration deployment is served as static client assets and performs no intentional application-network requests. | Network test that fails on `fetch`, XHR, `WebSocket`, `EventSource`, `sendBeacon`, unexpected image loads, and navigation to remote origins. | That future versions, forks, host pages, extensions, service workers, or browser features are static. |
| “Local-first” | Draft text is stored only in browser-local storage by this shell. Local message additions are held only in the active rendered page. | Source review and storage tests covering creation, restoration, and clearing of local draft state. | Confidentiality from a device co-tenant, browser sync, backups, extensions, accessibility software, screenshots, clipboard history, or operating-system services. |
| “No third-party telemetry” | The reviewed shell includes no third-party telemetry, analytics, advertising, tracking pixels, remote fonts, or model SDK calls. | Build inventory, CSP verification, network test, and deployment-header inspection. | Absence of browser, device, DNS, network, CDN, hosting, or download-page logs outside the shell’s control. |
| “No operator-side surveillance pipeline” | The shell has no Hearthline-controlled backend receiver, event collector, session service, or message store. | No backend endpoint configuration; network tests; deployment topology review. | That another party observing the device or network cannot collect information. |
| “No explicit algorithmic ranking” | The reviewed shell does not calculate, infer, label, score, sort, recommend, or determine eligibility for participants. | Source review and invariant tests. | Social hierarchy, user interpretation, chronological ordering, moderator judgment in a future system, or a fork’s added ranking behavior. |
| “No hidden profiling module” | The reviewed shell does not collect person-level behavioral data for segmentation, prediction, targeting, classification, or inference. | Source review, runtime storage/network inventory, reproducible build evidence. | That a future relay, hosting layer, fork, browser extension, or external service cannot profile participants. |
| “Explicit and revocable AI consent” | AI-assistance controls remain unavailable until the participant actively enables them locally; the preference can be withdrawn locally. | UI, keyboard, storage, and revocation tests. | That a participant fully understands every future provider’s terms, output behavior, or data handling without additional disclosures. |
| “Accessible design posture” | The shell includes specified accessibility features and must be tested against defined tasks. | Manual assistive-technology tests, keyboard tests, automated checks, and a published gap statement. | Universal accessibility, certification, or success for every device, browser, disability, language, communication preference, or future workflow. |
| “Future approved relay” | No relay exists in this shell. Any future relay is a separate system and must pass a defined approval gate before this deployment may connect to it. | Signed approval record, threat-model update, policy conformance tests, and deployment configuration review. | That an unnamed future relay, another deployment, or a fork will satisfy this specification. |

## 3. Privacy and safety adversaries

### 3.1 In-scope mitigations

The current shell is designed to reduce exposure to the following:

| Adversary or risk source | Current mitigation | Residual risk |
|---|---|---|
| Hearthline application operator | No operator service receives drafts, local messages, telemetry events, account data, or AI requests from the demonstration shell. | The operator may still control the published asset version or hosting configuration. |
| Third-party analytics and advertising vendors | No third-party analytics scripts, beacons, remote fonts, ad tags, social widgets, or model SDKs are included. | A browser, network, or host page can still independently contact external services. |
| Accidental AI submission | AI assistance is off by default and current controls do not make network requests. | A participant can still manually copy content to another service. |
| Markup injection through messages | Participant text is rendered with text-node APIs rather than HTML injection. | Future rich-text features require separate sanitization, parser, and rendering review. |
| Passive application-level remote observation | A restrictive content security policy limits shell connections to same origin. | CSP cannot prevent every browser-level or device-level disclosure mechanism. |

### 3.2 Explicitly out of scope

The following are not solved by the shell and must not be implied by terms such
as “private,” “local-only,” “safe,” or “no surveillance”:

- Shared or compromised devices.
- Browser profile sharing, browser sync, automatic backups, autofill, browser
  history, downloads, cached files, crash reports, clipboard history, and
  password-manager behavior.
- Browser extensions, developer tools, malware, remote administration software,
  keylogging, screenshots, shoulder surfing, or accessibility software that can
  inspect content under participant-authorized permissions.
- Network, DNS, internet-service-provider, enterprise, school, library, or
  device-management observation.
- Legal demands, seizure, subpoena, or disclosure by parties other than the
  demonstration shell.
- Copying, quoting, screenshotting, recording, or redistributing content by
  another participant after a future messaging system exists.
- A fork, mirror, altered build, proxy, embedded deployment, or impersonating
  deployment using the Hearthline name or visual style.

## 4. Present-state boundaries

### 4.1 Network boundary

The reviewed demonstration shell MUST NOT intentionally initiate any remote
application request.

This includes:

- `fetch`
- XMLHttpRequest
- WebSocket
- EventSource
- `navigator.sendBeacon`
- Remote `<script>`, `<img>`, `<iframe>`, `<video>`, `<audio>`, stylesheet,
  font, worker, or module imports
- Remote AI provider requests
- Remote translation requests
- Remote error-reporting requests
- Remote analytics, feature flag, crash-reporting, fingerprinting, advertising,
  experiment, or attribution requests

A static asset request needed to load the reviewed shell is outside the
application-runtime “no request” claim, but must be disclosed as part of the
deployment topology.

### 4.2 Storage boundary

The reviewed demonstration shell MAY store only:

| Key | Purpose | Location | Retention | Clearing action |
|---|---|---|---|---|
| `hearthline.demo.draft.v1` | Restore an unfinished draft after a local page refresh | `localStorage` | Until the participant clears it, browser storage is cleared, or the browser removes it | “Clear draft” control |
| `hearthline.demo.ai-consent.v1` | Remember the participant’s local AI-control preference | `localStorage` | Until changed or browser storage is cleared | Unchecking AI consent |
| `hearthline.demo.appearance.v1` | Remember local high-contrast preference | `localStorage` | Until changed or browser storage is cleared | Appearance control or browser storage clearing |

The shell MUST NOT store:

- Stable account identifiers
- Fingerprints
- Device identifiers
- Biometric, neural, physiological, health, or companion-system information
- Message archives
- Read receipts
- Presence records
- Typing indicators
- Contact graphs
- Location
- Message-derived classifications
- Moderation scores
- Identity scores
- Eligibility fields
- Behavior profiles
- Advertising identifiers

### 4.3 Person-level inference prohibition

A conforming Hearthline deployment MUST NOT use any self-description,
communication pattern, accessibility preference, interface event, draft,
message, device characteristic, network attribute, or AI interaction to infer,
assign, or predict:

- Personal identity or identity authenticity
- CyberRank status, eligibility, or verification
- Social worth, trustworthiness, credibility, importance, influence, risk, or
  desirability
- Disability, health, neural state, biometric status, cognitive state,
  physiological condition, religion, ethnicity, gender, sexuality, political
  view, income, legal status, or other sensitive category
- Engagement propensity, retention value, advertising value, or conversion
  likelihood
- Access eligibility, service priority, moderation outcome, or allocation of
  support

This prohibition applies whether the inference is named “ranking,”
“personalization,” “safety score,” “quality score,” “relevance,” “trust,”
“insight,” “engagement,” “behavioral signal,” “risk,” or any equivalent term.

## 5. Community-language correction

The reviewed shell MUST NOT claim that it is itself a complete community.

Permitted language:

> “A conversation interface that may support people who choose to form or
> participate in a community.”

Not permitted without implemented governance and accountable staffing:

> “A safe community,” “a moderated community,” “a trusted community,”
> “community protection,” or equivalent assurances.

The shell currently supports only a local, illustrative text-conversation
workflow. It does not yet support public multi-party rooms, private messages,
identity-bearing accounts, persistent threads, attachments, presence,
federation, moderation reports, blocking, access delegation, or dispute repair.

## 6. AI-assistance boundary

### 6.1 Current status

The current shell does not invoke an AI model. Its AI controls are explanatory
demonstrations only.

### 6.2 Required properties of a future AI request

A future AI request MUST have all of the following before any content crosses
the shell-to-relay boundary:

1. A participant-initiated action.
2. A single declared purpose.
3. A clear disclosure of the provider or relay identity.
4. An explicit statement of what exact text will be sent.
5. A meaningful no-AI path that does not reduce community access.
6. A revocable, single-request consent record.
7. A declared retention and deletion policy.
8. A prohibition on training use unless a separate, specific, affirmative
   authorization is collected.
9. A prohibition on identity inference, participant ranking, automated
   eligibility decisions, or unreviewed moderation decisions.
10. A user review step before output is transmitted to another person.
11. Plain-language error and refusal behavior when the request is outside
    supported scope.
12. An accessible human fallback for matters that affect access, moderation,
    safety, or dispute repair.

### 6.3 Facilitation versus mediation

A future feature is participant-side facilitation only when all conditions hold:

- The output is visible first to the requesting participant.
- The requesting participant may revise, reject, or discard it.
- The output is not transmitted to another participant without a deliberate
  participant action.
- The system does not make a hidden interpretation of one participant for
  another participant.
- The system does not alter message priority, visibility, routing, credibility,
  or access based on inferred participant traits.

A feature becomes mediation and requires separate governance when it:

- Interprets, summarizes, classifies, scores, reframes, or translates one
  participant’s content for another person without granular approval.
- Chooses which person sees an output.
- Alters a conversation outcome, message visibility, or participant standing.
- Provides advice or adjudication about a conflict between participants.
- Produces information used in moderation, access, eligibility, or safety
  determinations.

## 7. Future relay approval gate

No deployment conforming to this specification may enable a relay endpoint until
all of the following conditions are met.

### 7.1 Named approver

The approver for a future relay is not yet named.

Until a named governance body, decision procedure, conflict-of-interest rule,
appeal route, and public approval record are established, the relay MUST remain
disabled.

A future approver MUST be accountable to a documented governance process and
must not treat voluntary CyberRank personal-layer self-description as a
verification credential, status signal, or decision criterion.

### 7.2 Minimum approval evidence

The following evidence is required:

1. A public relay-interface schema.
2. A completed data-flow inventory.
3. A threat model identifying in-scope and out-of-scope adversaries.
4. A retention, deletion, and incident-response specification.
5. A privacy impact assessment.
6. Security testing of authentication, authorization, origin validation,
   transport encryption, rate limiting, input validation, abuse handling, and
   denial-of-service controls.
7. Accessibility testing with defined tasks and a published known-limitations
   statement.
8. A human moderation, correction, appeal, and grievance path.
9. A statement of applicable operational jurisdiction and legal review
   boundaries.
10. Reproducible build and release provenance sufficient for users to inspect
    the deployed version.
11. A documented rollback and relay-disable procedure.
12. Independent review appropriate to the service’s risk level.

### 7.3 Refusal-to-connect rule

The client MUST refuse relay configuration when any of the following is absent
or invalid:

- A `wss://` endpoint in production.
- A known, approved endpoint origin.
- A matching public interface version.
- A signed or otherwise verifiable approval record.
- A valid relay privacy declaration.
- A declared data-retention policy.
- A declared model/provider and training-use status, if AI is involved.
- A user-visible change notice when a material privacy or governance property
  has changed.
- A current approval expiration date.

## 8. Fork and deployment provenance

This specification binds only a deployment that publishes a matching conformance
statement.

A conforming deployment SHOULD make the following visible in the interface or
an accessible “About this deployment” page:

- Product name and deployment operator.
- Release version and source revision.
- Build timestamp.
- Source repository location.
- Integrity hash or signed release reference.
- Current network policy and configured relay state.
- Current telemetry declaration.
- Current storage declaration.
- Current accessibility statement.
- Current approval status and, if a relay exists, approval expiration.
- A clear warning that forks and mirrors may not preserve these properties.

A fork MUST NOT represent itself as a conforming Hearthline deployment unless it
publishes its own matching conformance statement and evidence.

## 9. Accessibility claim scope

The shell MAY claim:

> “Designed to support keyboard operation, visible focus, reduced-motion
> preferences, contrast adjustment, and polite assistive-technology
> announcements for the currently implemented local conversation workflow.”

The shell MUST NOT claim “fully accessible,” “universally accessible,” or
“WCAG conformant” until those claims are supported by a scoped assessment.

Before a production accessibility claim, testing MUST include at minimum:

- Keyboard-only message composition, local submission, draft clearing, consent
  withdrawal, contrast control, and announcement pause/resume.
- Screen-reader testing of the same workflow on supported browser and operating
  system combinations.
- Zoom and reflow testing.
- Contrast and non-color cue review.
- Reduced-motion review.
- Voice-control or switch-access review where supported.
- Plain-language review.
- Review with people using assistive technologies and varied communication
  methods.

## 10. User-facing disclosure copy

### 10.1 Current shell disclosure

> **About this demonstration**
>
> This version of Hearthline is a local browser demonstration, not a live chat
> service. Messages you add remain in this page and are not sent to a Hearthline
> server. Draft text may be stored in this browser so that it can return after a
> refresh. “Local” means Hearthline does not receive the draft; it does not mean
> the draft is protected from other people or software that can access this
> device or browser profile. Do not enter information you would not want visible
> to someone with access to your device.
>
> AI controls in this version do not contact an AI service. A future connected
> version would be a separate system with its own provider, data-use, retention,
> security, accessibility, and approval disclosures.

### 10.2 AI-assistance disclosure

> **Optional AI assistance**
>
> AI assistance is not required for participation. If a future feature sends
> selected text to a reviewed service, Hearthline will show the exact text,
> purpose, service identity, retention terms, and request-specific consent
> choice before transmission. You can decline or withdraw permission without
> losing access to the human conversation features. Review all AI output before
> choosing whether to share it.

### 10.3 Scope disclosure

> Hearthline’s current privacy and non-ranking claims apply to this identified
> deployment and release. They do not automatically apply to forks, mirrors,
> browser extensions, device software, hosting providers, or future connected
> services.
