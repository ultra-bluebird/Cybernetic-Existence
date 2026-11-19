# ACC-04 and ACC-05 Methodology

## Purpose

ACC-04 verifies that correction and appeal mechanisms are reachable and effective through digital, telephone, mail, in-person, and relay channels. ACC-05 models whether human fallback capacity can meet published response-time commitments during normal operation, digital outages, weather emergencies, and other surge conditions.

The operational principle is:

\[
\text{accessible correction}
=
\text{equivalent submission}
+
\text{acknowledgement}
+
\text{status access}
+
\text{human review}
+
\text{outage continuity}
\]

A correction or appeal route is not meaningful merely because a form exists. The route must be usable, acknowledged, tracked, responsive, available during outages, and able to produce the same core outcome without penalizing a person for using a non-digital channel, relay, human assistance, or privacy-preserving submission method.

## ACC-04: Accessibility Audit

### Core outcome equivalence

For a service \(s\) and access channel \(c\):

\[
Q_{s,c}
=
O_{s,c}
\cdot
A_{s,c}
\cdot
R_{s,c}
\cdot
T_{s,c}
\cdot
H_{s,c}
\cdot
F_{s,c}
\]

Where:

| Term | Meaning |
|---|---|
| \(O_{s,c}\) | The channel can complete the same core correction or appeal outcome |
| \(A_{s,c}\) | The channel provides acknowledgement or receipt |
| \(R_{s,c}\) | The person can obtain status and next-step information without a digital account |
| \(T_{s,c}\) | The response-time target is published and operationally monitored |
| \(H_{s,c}\) | Human assistance, escalation, and review are available |
| \(F_{s,c}\) | The channel has an equivalent fallback through a primary-system outage |

For minimum conformance:

\[
Q_{s,c}=1
\]

Every required channel must meet the condition. A lower-quality mail, phone, relay, or walk-in option cannot be described as equivalent simply because it accepts an initial contact.

### Required channel matrix

| Dimension | Digital | Phone | Mail | In-person | Relay |
|---|---|---|---|---|---|
| Same core outcome | Required | Required | Required | Required | Required |
| Published response target | Required | Required | Required | Required | Required |
| Language support | Required | Required | Required | Required | Required |
| Initial credential not required | Required | Required | Required | Required | Required |
| Digital device not required | Not applicable | Required | Required | Required | Required |
| Offline-capable route | Fallback required | Required | Required | Required | Required |
| Receipt or acknowledgement | Required | Required | Required | Required | Required |
| Status without digital account | Required | Required | Required | Required | Required |
| Human assistance | Required | Required | Required | Required | Required |
| Relay equivalence | Required | Required | Required | Required | Required |
| Anonymous or pseudonymous intake | Strongly supported | Strongly supported | Strongly supported | Strongly supported | Strongly supported |
| Outage fallback | Required | Required | Required | Required | Required |

The initial submission should not require a credential, account, biometric factor, neural signal, augmentation telemetry, device fingerprint, cybernetic-status disclosure, disability disclosure, or other identity attribute unless strictly necessary to resolve a specific transaction later. The service must provide a human-assisted least-intrusive path where identity is genuinely needed.

Accessible authentication principles recognize that authentication should not impose avoidable cognitive-function tests without an alternative, which reinforces the need for accessible, non-exclusive entry paths. [130][134]

### Auditing functional outage continuity

A correction or appeal service must be tested end to end, not only by checking that a backup contact number or paper form exists.

The annual outage test protocol is:

1. Simulate a network outage.
2. Simulate loss of electric power at the primary digital-service facility.
3. Simulate loss of the online portal, cloud provider, or workflow vendor.
4. Simulate loss of the digital identity provider or account-recovery system.
5. Submit a correction or appeal through every declared phone, mail, in-person, and relay path.
6. Confirm receipt or acknowledgement.
7. Confirm the request reaches the accountable case, review, or escalation workflow.
8. Confirm the person can check status without a digital account.
9. Confirm an appeal can proceed to a human reviewer.
10. Publish an accessible, aggregate summary of test results, gaps, correction actions, and retest dates.

The result is:

\[
\operatorname{OutageContinuity}(s)
=
\bigwedge_{c \in C_s}
\operatorname{endToEndPass}(s,c)
\]

A broken portal, vendor outage, power interruption, or identity-provider failure must transition the service into a working non-digital process. It must not merely display an error directing the person to return later.

FEMA continuity guidance frames the preservation of essential functions and critical services as shared, whole-community responsibilities and supports planned continuity capabilities rather than improvised outage responses. [127][135]

### Accessibility-gap detection

The audit detects the following gaps.

| Gap | Why it matters | Required control |
|---|---|---|
| Form-only channel | A submission form does not guarantee intake, receipt, routing, review, or remedy | End-to-end completion test |
| Digital status lockout | A person may submit by mail or phone but is forced online to learn the case status | Status by chosen reference, telephone, mail, relay, or staff support |
| Unequal queue treatment | Non-digital, relay, or assisted cases wait longer without a justified operational reason | Channel queue-equity measurement and remediation |
| Language inequivalence | Translation exists online but not by phone, mail, relay, or in-person | Equivalent language and interpretation support |
| Anonymous-intake gap | A person cannot safely raise a correction or grievance without exposing themselves initially | Pseudonymous receipt and secure case-reference mechanism |
| Credential barrier | An account or inaccessible identity step blocks a correction before it reaches a person | Least-intrusive, human-assisted resolution process |
| Outage fragility | A backup option depends on the same portal, power, vendor, or staffing source | Independent channel and failure-mode testing |
| Relay exclusion | A relay user reaches a channel but cannot receive a receipt, status, or escalation | Relay end-to-end equivalence test |
| Human-review gap | A system acknowledges a case but cannot correct, explain, or overturn a material decision | Accountable human review and appeal |

WCAG’s error-identification guidance requires detected errors to be identified and described in text or a text alternative, which supports correction pathways that clearly state what went wrong and what action is available. [129]

### Acknowledgement without identity registration

A correction or appeal can be acknowledged and tracked without mandatory identity registration through a privacy-preserving case-reference design.

\[
r
=
\operatorname{random}
(
\text{high-entropy token}
)
\]

The person receives the reference through their selected access channel:

- Printed receipt.
- Written confirmation letter.
- Staff-provided reference card.
- Spoken reference with an optional repeat or relay-compatible confirmation.
- Braille-ready, large-print, plain-text, or accessible electronic copy when requested.
- User-selected pseudonymous phrase combined with a server-generated secret.

The system stores only the minimum information needed to route and review the matter. It must not convert the access method, language request, relay request, communication preference, handwriting, voice, assistive technology, device, or timing pattern into a protected identity profile.

Status access should support at least two non-account routes, such as a case-reference phone line, mailed status request, relay-supported inquiry, in-person desk, or signed printed notice.

## ACC-05: Human Fallback Capacity

### Queueing model

For \(c\) trained human agents, arrival rate \(\lambda\), and per-agent service rate \(\mu\):

\[
a
=
\frac{\lambda}{\mu}
\]

\[
\rho
=
\frac{\lambda}{c\mu}
\]

Where \(a\) is offered load and \(\rho\) is system utilization.

Stability requires:

\[
\rho < 1
\]

Operational service-level planning is stricter:

\[
\rho \leq \rho_{\max}
\]

Where \(\rho_{\max}\) should normally be below 0.85 and is configured at or below 0.80 in the supplied implementation. The remaining capacity absorbs demand spikes, longer calls, interpretation, relay interaction, complex corrections, technical outage effects, and staff transition time.

For a multi-agent fallback service, an Erlang-C queue probability is used:

\[
P_{\text{wait}}
=
\frac{
\frac{a^c}{c!}
\cdot
\frac{1}{1-\rho}
}{
\sum_{n=0}^{c-1}\frac{a^n}{n!}
+
\frac{a^c}{c!}
\cdot
\frac{1}{1-\rho}
}
\]

A baseline expected queue wait is:

\[
W_q^{\text{base}}
=
\frac{P_{\text{wait}}}
{c\mu-\lambda}
\]

The model accounts for non-Poisson arrivals and variable service times through a variability adjustment:

\[
W_q
=
W_q^{\text{base}}
\cdot
\frac{
C_a^2+C_s^2
}{2}
\]

Where:

| Symbol | Meaning |
|---|---|
| \(C_a^2\) | Squared coefficient of variation of arrival intervals |
| \(C_s^2\) | Squared coefficient of variation of service time |
| \(P_{\text{wait}}\) | Probability an incoming request must wait |
| \(W_q\) | Expected waiting time in queue |
| \(c\) | Number of simultaneously available trained agents |
| \(\lambda\) | Arrival rate per hour |
| \(\mu\) | Service rate per agent per hour |

The user-provided single-server form:

\[
W_q
=
\frac{\rho}{\mu(1-\rho)}
\cdot
C_v^2
\]

remains useful as a conservative approximation for a single-agent pathway. The implementation expands it into a multi-agent Erlang-C model because essential public services often need parallel telephone, relay, desk, mail-processing, and escalation capacity.

### Maximum sustainable arrival rate

For scheduled staffing:

\[
\lambda_{\max}
=
c\mu\rho_{\max}
\]

This is the maximum planned arrival rate before the utilization guard is crossed. It is not a guaranteed SLA capacity because the service-level objective also depends on queue probability and waiting time.

For example, with four agents, each completing five cases per hour, and a maximum utilization of 0.80:

\[
\lambda_{\max}
=
4 \cdot 5 \cdot 0.80
=
16
\text{ cases per hour}
\]

At higher arrival rates, the service may remain mathematically stable below \(20\) cases per hour but fail its public response-time commitment. The system should therefore activate surge capacity before reaching full utilization.

### Surge capacity

Define:

\[
c_{\text{required}}
=
\min
\left\{
c \in \mathbb{N} :
\rho(c) \leq \rho_{\max}
\land
W_q(c)\leq W_{q,\max}
\land
P_{\text{wait}}(c)\leq P_{\text{wait},\max}
\right\}
\]

Then:

\[
c_{\text{surge}}
=
\max
(
0,
c_{\text{required}}-c_{\text{scheduled}}
)
\]

Surge activation should begin before an SLA is breached:

\[
\rho
\geq
\rho_{\text{activate}}
\Rightarrow
\text{activate backup staffing}
\]

The supplied configuration uses an activation guard of 0.70 utilization. This is a planning parameter, not a universal threshold. Local services should calibrate it using demand history, outage scenarios, accessibility requirements, emergency conditions, and staff activation time.

A surge plan includes:

- Cross-trained staff with correction, appeal, privacy, relay, language, and accessibility training.
- Mutual-aid agreements with independently operated public or community service teams.
- Offline and paper intake that continues even if the primary case-management system is unavailable.
- A non-discriminatory priority process that never ranks people by disability, cybernetic status, device type, augmentation status, telemetry, biometric attribute, wealth, digital access, or social score.
- Backup power, alternate work locations, and telecommunication alternatives.
- Published escalation and response commitments.
- Human review authority sufficient to correct, pause, route, and appeal cases.

### Hybrid human-AI support

Automation may assist capacity only under strict boundaries:

| Permitted support | Prohibited support |
|---|---|
| Draft plain-language explanations for staff review | Denying, closing, rejecting, or silently deprioritizing a correction or appeal |
| Translate or summarize with human verification | Treating language, modality, speech pattern, or device use as an eligibility or credibility score |
| Identify duplicate documents for human confirmation | Requiring biometric, neural, augmentation, or behavioral telemetry data |
| Route a case to the appropriate human queue using user-provided issue type | Blocking a human handoff |
| Offer a voluntary, accessible form-completion aid | Replacing the person’s correction, evidence, or appeal statement |
| Provide queue status with a non-digital alternative | Hiding uncertainty, limitations, or automated triage rules |

The governing condition is:

\[
\text{automation assistance}
\Rightarrow
\text{human authority remains available}
\]

NIST’s AI risk-management material emphasizes that human roles and responsibilities for using and overseeing AI systems should be explicitly defined and differentiated. [128][132]

### Capacity-validation protocol

1. Collect aggregate arrival and service-time data without storing sensitive identity, disability, cybernetic-status, biometric, neural, augmentation, or individual behavior profiles.
2. Estimate \(\lambda\), \(\mu\), \(C_a^2\), and \(C_s^2\) for baseline, peak, digital-outage, heat emergency, water outage, and other relevant scenarios.
3. Set public response-time, queue-probability, completion, acknowledgement, and escalation targets.
4. Calculate scheduled capacity, required capacity, and backup staffing requirement.
5. Run tabletop and live continuity tests with simulated surges.
6. Measure actual queue outcomes by channel while preserving privacy.
7. Adjust staffing, cross-training, mutual aid, intake channels, and service commitments using documented review.
8. Publish aggregate performance, limitations, corrective actions, and retest results in accessible plain language.

## Metrics

| Metric | Score | Basis |
|---|---:|---|
| `knowledge_factor` | 0.94 | The artifacts combine channel-equivalence rules, outage testing, privacy-preserving receipts, multi-agent queueing, surge planning, and human-oversight controls |
| `eco_impact_value` | 0.60 | Reusable non-digital and human-fallback patterns reduce emergency rework, failed service trips, unnecessary device replacement, and duplicated intake |
| `harm_risk` | 0.11 | Identity-neutral intake, outage testing, receipt and status guarantees, human escalation, utilization limits, and surge activation controls reduce exclusion and delay risk |
| `accessibility_impact` | 0.99 | Digital, phone, mail, in-person, relay, offline, anonymous or pseudonymous, and human-assisted routes are validated as complete service pathways |
| `rights_alignment` | 0.99 | The framework supports correction, appeal, due process, privacy, autonomy, non-discrimination, accessible explanation, and meaningful human review |
