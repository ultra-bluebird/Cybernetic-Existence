# Inclusive Public Space and Equal-Voice Civic Participation

## Purpose

This specification establishes:

1. Public-space planning and operations guidelines that support people using mobility aids, assistive technologies, personal devices, and self-described cybernetic or augmentation-related technologies.
2. A civic-participation platform for budgeting, policy feedback, and community initiatives that ensures equal voice without participation ranking, reputation scores, social scoring, popularity weighting, or behavioral profiling.

The specification does not determine whether a person's self-description, health status, assistive technology, augmentation, institutional record, or identity is valid. It does not request those details as a condition of public-space access or civic participation.

## Governing Principles

The systems SHALL:

- Preserve equal access regardless of augmentation status, appearance, device ownership, communication method, participation frequency, or claimed identity.
- Require no implant, augmentation, personal-device, account, government identification, biometric check, facial recognition, or continuous network connection.
- Offer non-digital and assisted alternatives for every consequential civic action.
- Separate functional environmental requirements from personal medical or technical disclosure.
- Use accessibility and safety constraints that improve public space for everyone.
- Permit anonymous or pseudonymous civic participation where legally and procedurally appropriate.
- Provide accessible explanations, correction paths, appeal routes, and human review.
- Avoid social ranking, reputation scores, participation streaks, activity badges tied to influence, follower counts, leaderboards, and engagement-based voting weight.
- Use only the minimum data necessary for the stated public purpose.

## Part One: Inclusive Public Space

### Accessible Circulation

Accessible routes should be designed as civic commons rather than minimum-compliance corridors.

The legal baseline in the United States is generally a continuous clear width of at least 36 inches for accessible walking surfaces, with limited short-distance exceptions. Wider routes are preferable for two-way passage, mobility-aid maneuvering, service-animal space, companions, heat mitigation, and emergency circulation. [115][117]

Recommended public-realm planning targets:

| Element | Minimum baseline | Inclusive planning target | Design rationale |
|---|---:|---:|---|
| Continuous accessible route | 36 in / 915 mm | 72 in / 1830 mm where feasible | Supports two-way movement, passing, and varied mobility-aid geometry |
| Passing space where route is constrained | Site-specific accessible-route requirement | 60 in by 60 in / 1525 mm by 1525 mm at regular intervals | Supports turning and safe passing |
| Seating-adjacent circulation | Must preserve accessible route | Keep a continuous 72 in clear movement zone where feasible | Prevents furniture, queues, and retail spillover from blocking access |
| Turning space | Site-specific accessible-turn requirement | 60 in diameter or equivalent T-turning space | Supports wheelchair and mobility-device turning |
| Drinking-water access | Accessible approach required | Multiple heights plus bottle-fill and tactile/high-contrast controls | Supports independent use without requiring a device |
| Charging access | Not universally required | Optional low-power, publicly visible, maintained outlets and USB-C PD where safely feasible | Supports personal assistive and communication devices without tying access to identity |
| Information access | Signage requirements vary | Visual, high-contrast, tactile, plain-language, and digital formats | Supports varied sensory and communication access |

Public seating, sidewalk dining, retail displays, planters, temporary events, and construction controls must preserve the accessible route. The Access Board and disability-access resources emphasize that furniture and other obstructions cannot reduce required accessible-route clearance. [115][120]

### Seating and Social Cohesion

Provide varied seating rather than a single standardized bench type:

- Seats with backs, armrests, varied heights, and stable transfer-adjacent space.
- Companion seating and wheelchair/mobility-device spaces integrated into the same social areas.
- Shade, drinking water, cooling, wind protection, and accessible rest opportunities.
- Quiet zones that are optional, visible, and socially integrated rather than isolating.
- Public tables with clear knee and toe space, nearby charging access, and clear circulation.
- Lighting that supports safety while minimizing glare, flicker, and visual overload.
- Clear wayfinding that does not depend only on color, smartphone use, or spoken instructions.

Design should not segregate people who use assistive or cybernetic technologies. The goal is shared public life: people choose their preferred levels of sensory stimulation, device access, privacy, and social contact.

### Electromagnetic Environment

Public-space operators should not claim that a single field-strength value protects every implant or device. Interference susceptibility depends on device design, frequency, modulation, distance, shielding, lead configuration, operating mode, and a device manufacturer's intended electromagnetic environment.

IEC 60601-1-2 addresses electromagnetic compatibility for medical electrical equipment and systems, while active implantable devices fall outside its scope and may be governed by device-specific standards and manufacturer guidance. [116][123] Therefore, public-space policy should use a layered, measurement-based process rather than declare universal “safe” electromagnetic conditions.

A designated quiet zone may adopt the following conservative local engineering target:

\[
E_{\mathrm{RMS}} < 0.1\ \mathrm{V/m}
\]

where \(E_{\mathrm{RMS}}\) is the measured root-mean-square electric-field strength over the facility's declared measurement band and survey protocol.

This is an optional local environmental-quality objective, not a certification of implant safety or a substitute for device-specific guidance.

#### Quiet-zone controls

- Place high-power transmitters, charging infrastructure, induction systems, large transformers, and antenna equipment away from designated seating and rest areas.
- Document intended equipment, operating frequency, duty cycle, and expected field conditions before installation.
- Use qualified electromagnetic compatibility assessment for new high-power or unusual RF installations.
- Survey baseline fields before opening and after material electrical changes.
- Post plain-language notices describing voluntary quiet-zone conditions, equipment limitations, and a contact path for reporting interference concerns.
- Provide alternate seating and accessible routes outside the quiet zone so quiet-zone availability never becomes a condition of public-space access.
- Do not ask visitors to disclose an implant, augmentation, diagnosis, manufacturer, device model, or technical configuration to use the space.
- Treat interference reports as maintenance and environmental-design feedback, not as identity evidence.

#### Measurement model

Let \(E(t, f, p)\) be the measured field strength at time \(t\), frequency \(f\), and location \(p\). For a designated zone \(Z\), use a survey grid \(P_Z\) and the declared frequency range \(F\).

The zone conformance indicator is:

\[
Q_Z =
\begin{cases}
1 &
\text{if }
\max_{p \in P_Z, f \in F} E_{\mathrm{RMS}}(p, f)
<
E_{\mathrm{target}} \\
0 &
\text{otherwise}
\end{cases}
\]

with:

\[
E_{\mathrm{target}} = 0.1\ \mathrm{V/m}
\]

A value of \(Q_Z = 1\) means the zone met the local measurement target under the declared survey conditions. It does not guarantee compatibility for every device, every individual, every operating condition, or future equipment configuration.

### Co-Design With Affected Community Members

Co-design must welcome people as equal contributors without asking them to validate personal identities or disclose technical/medical information.

A meaningful process includes:

1. Paid advisory participation, with compensation available through non-digital and non-financial alternatives where needed.
2. Accessible meeting formats: in-person, remote, telephone, asynchronous written input, audio input, plain-language materials, captioning, interpretation, and assistive-technology-compatible documents.
3. Independent support persons or advocates chosen by participants.
4. Voluntary functional-needs questions, such as “Which environmental conditions make this space easier or harder to use?” rather than “What condition or device do you have?”
5. Multiple prototype walk-throughs, including daytime, night, heat, rain, crowding, and construction-detour conditions.
6. Public response logs that show which recommendations were adopted, deferred, or declined and why.
7. Anonymous feedback options that are not weighted less than named feedback.
8. A community review point before final design, procurement, and post-occupancy evaluation.
9. A funded pathway for corrective work when actual use identifies an access barrier.
10. No collection of cybernetic-host, augmentation, implant, disability, health, or identity data unless a participant freely chooses to disclose it for a clearly separated research purpose.

## Part Two: Civic Participation Without Social Scoring

### Equal Voice

Every eligible participant receives the same base civic voice allocation for a given deliberation. Participation frequency, account age, prior voting history, social connections, profile completion, device quality, location precision, payment capacity, and reputation cannot increase or decrease that allocation.

The platform SHALL NOT contain:

- Reputation points, trust scores, influence scores, or participation tiers.
- Public leaderboards, follower counts, popularity counts, engagement streaks, or badges tied to voting influence.
- Ranking of comments by identity, status, frequency, wealth, or presumed expertise.
- Personalized political persuasion or content ranking based on behavioral profiling.
- Cross-topic or cross-service behavioral profiles.
- Automated moderation penalties based on inferred identity or protected characteristic.
- Smart-contract token holdings that grant greater civic influence.

### Deliberation Structure

The platform supports three separate functions:

| Function | Equal-voice design | Privacy protection |
|---|---|---|
| Budget preference | Each participant receives the same non-transferable budget of voice credits | Ballots are separated from public discussion identity |
| Policy feedback | One submission or equal-weight response per participant per consultation stage | Anonymous/pseudonymous submissions allowed where appropriate |
| Community initiatives | Equal opportunity to propose, endorse, discuss, and request review | No promoter ranking, follower weighting, or pay-to-amplify feature |
| Deliberative discussion | Chronological or randomized rotation of eligible contributions | No engagement-based ordering or user profiling |
| Moderation and review | Conduct-based, scope-limited process | No identity inference, social score, or behavior profile |

### Quadratic Voting

Quadratic voting can express intensity of preference, but it must be configured to avoid wealth, token, or participation-frequency advantages.

For participant \(i\) and issue \(j\), let \(v_{ij}\) be an integer number of positive or negative votes. The cost is:

\[
C_i =
\sum_{j=1}^{m} v_{ij}^{2}
\]

Each participant receives an equal, fixed, non-transferable budget \(B\):

\[
C_i \leq B
\]

The platform accepts a ballot only if:

\[
\sum_{j=1}^{m} v_{ij}^{2} \leq B
\]

Example: with \(B = 25\), a participant may cast:

\[
v_{i1} = 3,\quad v_{i2} = 4
\]

because:

\[
3^2 + 4^2 = 9 + 16 = 25
\]

The participant cannot purchase additional credits, transfer credits, earn credits through activity, receive credits based on reputation, or accumulate credits by waiting across unrelated civic processes.

Quadratic voting is a distributional method intended to let participants express preference intensity. Its use in participatory budgeting requires careful implementation, equal allocation, accessibility accommodations, transparency, and independent evaluation of whether its outcomes remain equitable. [119][121][125]

### Recommended Safeguards

Quadratic voting should be optional rather than mandatory. For every consultation, offer a one-person-one-vote option, a ranked-choice option, and an accessible assisted ballot path.

The platform should also:

- Publish the credit budget, vote-cost formula, tally method, audit method, and contestability process before the ballot opens.
- Provide an explanation and calculator that works offline and with screen readers.
- Use a fixed maximum absolute vote value per issue.
- Ensure that every participant receives exactly the same budget for that deliberation.
- Prevent transfer, sale, pooling, delegation for compensation, and activity-based accrual.
- Separate eligibility checks from ballot contents.
- Use privacy-preserving ballot storage and publicly verifiable aggregate tallies where appropriate.
- Permit ballot correction before the close of the voting period.
- Provide in-person, telephone, paper, and assisted methods with the same civic weight.
- Run distributional impact reviews by geographic zone and access channel using aggregate data only.
- Publish uncertainty and participation gaps without labeling or ranking individuals.

### Moderation Without Profiling

Moderation should be behavior-specific, evidence-based, and limited to the discussion context.

Permitted moderation targets include:

- Credible threats.
- Targeted harassment.
- Doxxing or non-consensual disclosure of personal information.
- Hate-based or dehumanizing attacks.
- Impersonation intended to deceive a particular civic workflow.
- Spam, malware distribution, and coordinated disruption.
- Repeated posting that prevents other people from participating.

The following are not moderation grounds by themselves:

- Self-asserted identity.
- Cybernetic-host or augmentation-related self-description.
- Disability, assistive-technology use, appearance, communication style, or device ownership.
- Unfamiliar terminology.
- Non-majority policy views.
- Low participation frequency.
- Refusal to disclose identity, diagnosis, institutional record, or technology details.

Moderation responses should follow this sequence:

```text
NOTICE
CONTENT-SPECIFIC EXPLANATION
OPPORTUNITY TO EDIT OR RESPOND
NARROW TEMPORARY BOUNDARY IF NECESSARY
ACCESSIBLE HUMAN REVIEW
APPEAL
AUTOMATIC EXPIRATION OF TEMPORARY ACTION
```

No response may use a profile score, predicted future risk, identity inference, or cross-platform behavior history.

## Privacy-Preserving Audit Requirements

The platform may retain aggregate process evidence needed to evaluate accessibility, outages, voting integrity, and moderation timeliness.

Permitted aggregate audit fields:

```json
{
  "event_type": "civic_participation_process_summary",
  "event_time": "2026-09-01T00:00:00Z",
  "consultation_type": "participatory_budgeting",
  "access_channel": "public_terminal",
  "process_state": "ballot_accepted",
  "equal_voice_budget": 25,
  "policy_version": "1.0.0",
  "appeal_available": true,
  "personal_identity_data_present": false,
  "health_or_augmentation_data_present": false,
  "reputation_or_rank_present": false,
  "retention_class": "aggregate_limited"
}
```

Audit data SHALL NOT include:

- Personal names, contact details, device identifiers, IP addresses, biometric data, precise location history, or browser fingerprints.
- Identity, health, disability, assistive-technology, augmentation, implant, or cybernetic-host declarations.
- Vote-to-person linkage after the ballot-separation procedure.
- Reputation scores, influence values, participation counts attributable to a person, or inferred political profiles.
- Raw moderation text beyond the minimum necessary for an active appeal or legally required preservation process.

## Metrics

### Public-space metrics

Let:

- \(L_{\mathrm{accessible}}\) be the length of continuously accessible, obstruction-free route.
- \(L_{\mathrm{public}}\) be total relevant public pedestrian-route length.
- \(Q_Z\) be the quiet-zone measurement conformance indicator.
- \(N_{\mathrm{resolved}}\) be the number of verified access barriers resolved.
- \(N_{\mathrm{reported}}\) be the number of verified access barriers reported.

\[
\operatorname{AccessibleRouteCoverage} =
\frac{L_{\mathrm{accessible}}}{L_{\mathrm{public}}}
\times 100
\]

\[
\operatorname{BarrierResolutionRate} =
\frac{N_{\mathrm{resolved}}}{N_{\mathrm{reported}}}
\times 100
\]

\[
\operatorname{QuietZoneConformanceRate} =
\frac{\sum_{Z=1}^{n} Q_Z}{n}
\times 100
\]

### Civic-platform metrics

Let \(B\) be the equal voice-credit allocation, \(C_i\) be a participant's quadratic cost, and \(V_m\) be the count of adversarial-test policy violations in month \(m\).

\[
C_i = \sum_{j=1}^{m} v_{ij}^{2}
\]

\[
C_i \leq B
\]

\[
V_m =
\sum_{k=1}^{N_m}
\mathbb{1}
\left[
\text{adversarial test}_k
\text{ permits ranking, profiling, or unequal vote weight}
\right]
\]

The policy target is:

\[
V_m = 0
\]

A result of zero means the automated test suite found no tested policy pathway allowing unequal influence, ranking, or profiling. It does not replace independent community oversight, accessibility testing, or appeal review.

## Metrics Summary

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.86 | Combines accessible-route standards, measurement-based electromagnetic compatibility governance, equitable deliberation design, and privacy-preserving moderation |
| eco_impact_value | 0.72 | Supports walkable, shaded, reusable public infrastructure and reduces unnecessary device dependence and travel burdens |
| harm_risk | 0.35 | Risks include inaccurate EMI assumptions, exclusion through poorly designed participation mechanisms, and moderation misuse; mitigated through local targets, co-design, alternatives, review, and audit |
| accessibility_impact | 0.98 | Provides wide routes, integrated seating, optional quiet spaces, accessible communication, no-device pathways, and equal participation weight |
| rights_alignment | 0.98 | Preserves dignity, self-determination, privacy, non-discrimination, civic voice, transparent review, and freedom from social scoring |
