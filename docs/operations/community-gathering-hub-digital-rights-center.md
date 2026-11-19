# Community Gathering Hub: Offline Digital Rights Center

## Purpose

A Community Gathering Hub is a physical, publicly reachable space such as a library, community center, neighborhood resource site, or mobile service unit. It enables people to access essential-service information, submit correction and appeal requests, obtain accessible paper materials, and receive respectful human assistance without requiring:

- A personal device.
- A smartphone, app-store account, email account, or continuous internet connection.
- A government identity document.
- Disclosure of a diagnosis, assistive technology, augmentation status, cybernetic-host status, biometric identifier, or institutional record.
- Consent to unrelated analytics, behavioral profiling, or optional telemetry.

The hub is an access pathway, not an eligibility authority. It must never determine a person's identity, status, medical condition, institutional standing, or entitlement to essential services.

## Service Model

The hub provides four equivalent service channels:

| Channel | Core capability | Privacy and accessibility control |
|---|---|---|
| Walk-in assisted support | A trained staff member helps a visitor find information, complete a form, and request a receipt | Visitor may decline to state a name; staff use least-data assistance |
| Accessible public terminal | A visitor independently accesses approved public-service portals and forms | Guest session, automatic sign-out, sanitized browser state, no retained local files |
| Offline paper pathway | A visitor receives forms, instructions, appeal packets, and postage or submission assistance | Large print, plain language, tactile and alternative formats on request |
| Low-connectivity workflow | A staff member captures a minimum request locally and submits it when the approved service connection is restored | Encrypted queue, visible submission status, no hidden retry or external sharing |

The same outcome must be available through more than one channel. A person must not lose access because a terminal fails, a network is unavailable, a device cannot be used, or a digital account cannot be created.

## Physical Infrastructure

### Public access area

A minimum viable hub includes:

- A barrier-free entrance, clear routes, seating, quiet waiting space, accessible service counter, and visible privacy notice.
- Two general public terminals and one adjustable accessible workstation.
- A privacy screen and a choice of open-area, semi-private, or private assistance.
- A print station with no-charge rights, appeal, correction, and essential-service forms.
- A locked document-drop option for paper submissions outside staffed hours.
- A telephone or relay-compatible contact method for organizations that accept requests by phone.
- A battery-backed local workstation or paper fallback kit for network outages.
- A public display showing service availability, outage status, current printed-resource versions, and the route to human assistance.

### Accessible workstation

The accessible workstation should include:

- Height-adjustable desk or table and adjustable monitor position.
- Keyboard, mouse, trackball, touch alternative, and switch-access compatibility.
- Screen-reader software, magnification, high-contrast display mode, and text-to-speech.
- Headphones, microphone with a physical mute control, and a volume-control option.
- Large-print keyboard labels and tactile orientation markers.
- Accessible document creation, scanning, printing, and secure deletion tools.
- A non-camera identity option. Webcam, voice, face, and biometric controls must remain disabled unless the visitor specifically elects to use them for a chosen service.

Assistive technology should be visible, maintained, and available without requiring a visitor to justify its use. Public-library accessibility guidance specifically recommends audits of public workstations and assistive tools, including screen readers, magnifiers, communication boards, and listening devices, alongside recurring staff training. [88]

## Offline-First Request Workflow

### Request types

The hub may support:

- Correction requests for an inaccurate service record.
- Appeal requests following a service decision.
- Public-record or public-information navigation.
- Complaint and grievance submission.
- Essential-service referral and access information.
- Device-independent printing or scanning of visitor-provided materials.
- Assistance with voluntary applications that the visitor chooses to complete.

The hub must not make a final determination on an external agency's request unless the hub itself is the authorized decision-maker and a lawful, accessible procedure exists.

### Local request envelope

A low-connectivity workflow stores only the fields required to convey the person's request:

```json
{
  "requestType": "appeal",
  "submissionChannel": "hub_assisted",
  "contactPreference": "none",
  "accessibilityFormatRequested": "plain_language_print",
  "statement": "Visitor-provided request text",
  "attachmentsPresent": false,
  "createdAt": "2026-09-01T00:00:00Z",
  "submissionState": "queued_for_approved_destination",
  "retentionDeadline": "2026-09-08T00:00:00Z"
}
```

The local envelope must not contain:

- A visitor's augmentation, cybernetic-host, disability, health, neural, biometric, or identity status.
- A profile score, risk score, trust score, reputation score, or service-priority ranking.
- Precise location history.
- Browser history, keystroke data, camera footage, or unnecessary device metadata.
- An account identifier unless the visitor explicitly supplies it because the destination requires it.

### Submission states

```text
DRAFT
READY_FOR_VISITOR_REVIEW
QUEUED_FOR_SUBMISSION
SUBMITTED
SUBMISSION_CONFIRMATION_PRINTED
DELIVERY_UNCONFIRMED
EXPIRED_AND_DELETED
```

A request may leave `READY_FOR_VISITOR_REVIEW` only after the visitor or assisting staff member confirms the displayed content. The hub must show whether the request was submitted, queued, failed, or requires a manual alternative.

If connectivity is unavailable, the hub shall provide a dated receipt stating that the request is queued and shall offer a paper or telephone alternative. A queue state is not proof of external-agency receipt.

## Staff Practice

### Core training

Every staff member and volunteer supporting public access receives training on:

- Dignified, person-led communication and chosen forms of address.
- The distinction between self-description and eligibility evidence.
- Privacy boundaries: do not ask why an accommodation is needed when the task can be completed without that information.
- Assistive-technology respect: do not touch, disconnect, inspect, or ask for technical details about a person's device, mobility aid, communication system, or augmentation without explicit permission.
- Non-discrimination: augmentation status, self-described cybernetic-host status, appearance, assistive device use, device ownership, and communication method are not service-quality indicators.
- Accessible communication: plain language, reading aloud on request, written alternatives, interpretation pathways, relay use, and additional processing time.
- Secure public-terminal handling, document handling, print release, and session cleanup.
- De-escalation that does not treat disability, communication difference, or unfamiliar technology as a safety concern.
- How to explain an appeal, correction, or grievance process without providing legal advice.
- Escalation to a supervisor or independent advocate when a person reports discrimination, inaccessible service, or a privacy concern.

### Staff interaction standard

Staff SHALL ask:

> “What would make this process work best for you today?”

Staff SHALL NOT ask:

> “Can you prove that identity, device, condition, or status?”

unless an external service has an independently applicable and clearly explained requirement. Even then, the hub should help the visitor identify an equivalent non-digital or human-review pathway.

### Training assessment

Training is complete only when staff can demonstrate:

- A screen-reader-assisted submission.
- A paper appeal submission.
- A guest-session terminal cleanup.
- An accessible explanation of a delayed or failed submission.
- A response to a discrimination complaint that does not require the visitor to disclose sensitive identity or health information.
- A safe escalation when the staff member cannot meet an access need directly.

## Privacy and Security Controls

- Use a separate guest network for public terminals.
- Run browser sessions in a disposable, non-persistent profile.
- Clear downloads, form data, cookies, and print queues after each session.
- Encrypt queued submissions at rest with access restricted to designated staff roles.
- Use a visible, short retention schedule for queued data.
- Do not record terminal screens, keystrokes, audio, or camera streams for service analytics.
- Maintain endpoint patching, malware protection, kiosk allowlists, locked-down administrative controls, and secure print-release procedures.
- Provide an accessible privacy notice before a visitor begins a session.
- Create a documented incident process for lost printouts, misdirected submissions, or unauthorized access.
- Support visitor-requested deletion of local drafts when technically possible and compatible with a submitted external request.

## Coverage and Equity Metrics

Let:

- \(P\) be the population in the defined service area.
- \(P_{15}\) be the population whose origin point has a walk-time of 15 minutes or less to a hub.
- \(W_i\) be the network walk time from population origin \(i\) to its nearest hub.
- \(w_i\) be the population weight for origin \(i\).

The 15-minute walk coverage is:

\[
\operatorname{Coverage}_{15} =
\frac{P_{15}}{P} \times 100
\]

A population-weighted mean walk time is:

\[
\overline{W} =
\frac{\sum_i w_i W_i}{\sum_i w_i}
\]

Coverage analysis must use pedestrian-network travel time, not straight-line distance. It should identify barriers such as missing sidewalks, high-speed crossings, inaccessible curb ramps, excessive heat exposure, construction, and transit-transfer burdens.

Do not use personally identifiable mobility traces to calculate coverage. Use publicly available street networks, census or planning-zone population aggregates, community-reviewed accessibility barriers, and documented uncertainty.

### Annual operating-cost model

Let:

- \(C_s\) be staff and benefits.
- \(C_u\) be utilities, connectivity, printing, and consumables.
- \(C_m\) be maintenance, accessibility technology, replacement reserve, and security updates.

\[
C_{\text{hub}} = C_s + C_u + C_m
\]

The planning target is:

\[
C_{\text{hub}} < \$50{,}000 \text{ per year}
\]

For a small existing-library or community-center deployment, a planning envelope can reserve:

| Cost category | Planning share | Operational note |
|---|---:|---|
| Staff and benefits | 0.60 to 0.75 | Prioritize trained human assistance and scheduled coverage |
| Utilities, connectivity, printing | 0.10 to 0.20 | Include accessible printing and a low-connectivity fallback |
| Maintenance and replacement reserve | 0.15 to 0.25 | Include assistive hardware, endpoint security, and repair capacity |

The target is feasible only when the physical space, core facility operations, or staff capacity are shared with an existing trusted institution. A standalone, fully staffed center will generally require a separate locally validated budget.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.87 | Built from digital-navigator practice, accessible workstation guidance, offline-first request design, and equity-oriented walk-time analysis |
| eco_impact_value | 0.63 | Shared public infrastructure, device reuse, repair, low-power terminals, and targeted printing reduce duplicative household-device burdens |
| harm_risk | 0.28 | Risks include privacy exposure, staff discrimination, and failed submissions; mitigated by minimal data, visible states, accessible alternatives, and deletion controls |
| accessibility_impact | 0.97 | Directly supports device-independent, non-digital, assistive-technology-compatible, human-supported access |
| rights_alignment | 0.97 | Centers dignity, privacy, self-determination, appeal, correction, accessibility, and non-discrimination |
