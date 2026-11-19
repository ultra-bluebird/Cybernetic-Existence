# ECO-05 and ACC-01 Methodology

## Purpose

This specification joins two public-interest continuity systems.

- ECO-05 selects infrastructure maintenance windows that minimize avoidable ecological disruption while never allowing reliability risk to cross a declared safety threshold.
- ACC-01 verifies that each essential service has fully functioning non-digital, offline, and human-mediated routes that remain available during technology, electricity, communications, vendor, and account-access failures.

The combined design principle is:

\[
\text{ecological timing}
+
\text{reliability protection}
+
\text{non-digital continuity}
=
\text{resilient public infrastructure}
\]

Neither ecological protection nor reliability maintenance may be used to eliminate accessible public service. Likewise, digital modernization cannot become an excuse to remove paper, radio, telephone, posted, mailed, staffed, or in-person access.

## ECO-05: Maintenance Optimizer

### Objective function

For each candidate maintenance window \(t \in T\):

\[
J(t)
=
\alpha E_{\text{disruption}}(t)
+
\beta I_{\text{reliability}}(t)
+
\gamma C_{\text{cost}}(t)
\]

The selected maintenance window is:

\[
t^*
=
\arg\min_{t \in T_{\text{feasible}}}
J(t)
\]

Subject to:

\[
I_{\text{reliability}}(t)
\leq
I_{\max}
\]

\[
S_{\text{continuity}}(t)=1
\]

\[
\alpha+\beta+\gamma=1
\]

\[
\alpha,\beta,\gamma \geq 0
\]

Where:

| Symbol | Meaning |
|---|---|
| \(E_{\text{disruption}}(t)\) | Ecological disruption score for candidate window \(t\) |
| \(I_{\text{reliability}}(t)\) | Probability-weighted or normalized reliability risk created by deferring work to \(t\) |
| \(C_{\text{cost}}(t)\) | Normalized lifecycle cost, including mobilization, labor, access, and mitigation |
| \(I_{\max}\) | Publicly declared maximum allowable reliability risk |
| \(S_{\text{continuity}}(t)\) | Essential-service continuity predicate; one only where equivalent service remains available |
| \(\alpha,\beta,\gamma\) | Publicly reviewable weights for ecological disruption, reliability, and cost |

No candidate is eligible merely because it has low ecological disruption. It must also preserve essential-service continuity and remain within the reliability threshold.

### Ecological disruption score

The ecological-disruption score is a transparent weighted composition:

\[
E_{\text{disruption}}(t)
=
w_b B(t)
+
w_m M(t)
+
w_n N(t)
+
w_h H(t)
+
w_r R(t)
\]

Where:

| Component | Meaning |
|---|---|
| \(B(t)\) | Breeding and reproductive-period sensitivity |
| \(M(t)\) | Migration, movement-corridor, or seasonal refuge sensitivity |
| \(N(t)\) | Nesting, roosting, denning, or habitat-structure sensitivity |
| \(H(t)\) | Habitat-condition sensitivity, including heat, water stress, flood, or drought |
| \(R(t)\) | Work-method risk, including noise, vibration, lighting, vegetation removal, sediment disturbance, and access disruption |

Ecological calendars should be treated as reviewable planning inputs, not as a demand for continuous monitoring or individual wildlife surveillance.

### Calendar encoding without continuous monitoring

ECO-05 encodes ecological time through a versioned calendar made of seasonal constraints:

```text
constraint:
  ecological feature: nesting habitat
  period: locally declared spring nesting period
  activity restriction: avoid non-emergency mechanized work
  disruption score: 0.85
  evidence quality: validated
  mitigation: defer, reduce noise, use manual inspection, or seek ecological review
```

The permitted inputs are:

- Published local ecological guidance.
- Tribal, community, land-stewardship, or agency seasonal calendars.
- Pre-registered independent ecological review.
- Habitat-condition inspections that are bounded in time and purpose.
- Aggregate noninvasive ecological evidence, where lawful and appropriate.
- Weather, hydrology, vegetation phenology, and infrastructure-condition data.

The system must not require continuous tracking of individual animals, people, workers, residents, assistive devices, or personal movement patterns.

A calendar may include uncertainty ranges:

\[
E_{\text{disruption,conservative}}(t)
=
\max_{s \in \mathcal{S}}
E_{\text{disruption},s}(t)
\]

The optimizer uses the highest plausible disruption score across supported ecological scenarios, rather than selecting the most favorable scenario.

### Reliability failure modes

Reliability risk increases when preventive work is delayed. The failure-mode record for each asset should include probability, consequence, detectability, service impact, and repair lead time.

\[
I_{\text{reliability}}(t)
=
\operatorname{clamp}
\left(
P_{\text{failure}}(t)
\cdot
C_{\text{service}}
\cdot
L_{\text{repair}}
\cdot
(1-D_{\text{detection}})
,
0,
1
\right)
\]

Where:

| Term | Meaning |
|---|---|
| \(P_{\text{failure}}(t)\) | Estimated probability of failure if work is delayed until \(t\) |
| \(C_{\text{service}}\) | Severity of lost service, safety hazard, ecological harm, or cascading impact |
| \(L_{\text{repair}}\) | Normalized repair or replacement lead time |
| \(D_{\text{detection}}\) | Detection effectiveness; earlier detection lowers unanticipated failure risk |

Common failure modes include:

| Asset class | Failure modes from delayed maintenance |
|---|---|
| Urban trees and canopy systems | Limb failure, irrigation failure, root-zone compaction, pest escalation, canopy loss, blocked accessible paths |
| Green roofs and green walls | Drainage blockage, membrane failure, vegetation die-off, substrate erosion, structural load risk |
| Bioswales and rain gardens | Sediment clogging, standing water, overflow, erosion, invasive species spread, pollutant bypass |
| Wetlands and riparian infrastructure | Hydraulic blockage, invasive spread, bank instability, water-quality decline, habitat loss |
| Stormwater assets | Blocked inlets, pump failure, sediment accumulation, overflow, roadway flooding, water-quality release |
| Water-distribution assets | Main break, pressure loss, pump failure, treatment interruption, cross-connection risk, contamination exposure |
| Cooling-center infrastructure | HVAC failure, backup-power failure, water outage, accessibility-equipment failure, unsafe indoor conditions |
| Transit-shade assets | Structural damage, heat-exposure increase, blocked routes, lighting failure, inaccessible waiting conditions |
| Habitat-corridor features | Fence or crossing degradation, vegetation failure, lighting intrusion, invasive encroachment, unsafe passage |

EPA asset-management guidance identifies preventive, routine, emergency/reactive, and deferred maintenance as distinct maintenance categories. Its asset-management materials also describe reliability as the ability of an asset to perform required functions under stated conditions for a specified period, and recognize failure modes as causal sequences leading to asset failure. [98][100][102]

### Emergency override

An emergency override is not an automatic ecological exception. It is available only when delay creates imminent danger to life, essential-service continuity, infrastructure safety, or irreversible environmental harm.

An override requires:

- Human authorization by the accountable operations authority.
- Documentation of the reliability threat and why ordinary windows are infeasible.
- The least disruptive work method that controls the imminent threat.
- Ecological mitigation such as reduced hours, low-noise equipment, temporary habitat protection, replacement planting, or post-work restoration.
- Preserved essential-service continuity through alternate routes.
- Post-action ecological and community review.

The fail-closed rule is:

\[
\text{missing reliability evidence}
\Rightarrow
\text{hold for review}
\]

\[
\text{reliability threshold exceeded}
\Rightarrow
\text{ordinary delay prohibited}
\]

This aligns with the project’s safety-spine approach: incomplete corridor evidence blocks routine progression, and risk worsening cannot be silently accepted. [97]

### Transparent decision explanation

Every scheduling decision should produce an accessible explanation:

```text
Selected window: late-winter maintenance period

Why this window:
It has the lowest combined ecological-disruption, reliability-risk,
and cost score among feasible options.

Ecological protection:
The selected period avoids the locally declared nesting restriction
and uses low-noise, daylight-only work methods.

Reliability protection:
Deferral beyond the selected period would exceed the maximum allowed
risk of drainage or structural failure.

Service continuity:
Cooling, water, transit, or other affected essential services remain
available through equivalent alternate arrangements.

Review:
The calendar basis, weights, evidence quality, uncertainty, and
mitigation plan are available for public and community review.
```

## ACC-01: Non-Digital Pathway Verification

### Minimum pathway quality

A non-digital pathway is acceptable only when it produces the **same core outcome** as its digital counterpart.

\[
Q_{\text{non-digital}}(s)
=
O_s
\cdot
F_s
\cdot
A_s
\cdot
H_s
\cdot
U_s
\]

Where:

| Term | Meaning |
|---|---|
| \(O_s\) | Same core outcome: the route can actually deliver information, submit a request, receive a service, correct a record, or lodge an appeal |
| \(F_s\) | Fully offline availability during internet, application, account, vendor, or device failure |
| \(A_s\) | Accessible format and communication support |
| \(H_s\) | Human-mediated assistance available |
| \(U_s\) | Published and usable hours, response target, and escalation route |

Each factor is binary for minimum conformance. A pathway passes only if:

\[
Q_{\text{non-digital}}(s)=1
\]

A brochure that merely describes an online portal is not a non-digital service pathway. A paper form that requires online account activation is not fully non-digital. A telephone line that cannot submit or escalate a request is not an equivalent human-mediated pathway.

### Required service matrix

| Essential service | Digital pathway | Non-digital pathway | Offline pathway | Human-mediated pathway | Minimum continuity result |
|---|---|---|---|---|---|
| Emergency information | Web alerts, applications | Radio, sirens, community broadcast | Printed notices, static signage | 24-hour phone line and staffed information point | Equivalent information and escalation access |
| Cooling-center access | Online maps, applications | Posted directory, radio, public announcements | Static signage and printed location list | Staffed desk or telephone information route | Location, hours, transport and accessibility information |
| Transit updates | Real-time feeds | Schedule posters, radio notices, station announcements | Pre-printed schedules and route maps | Station agent, transit phone line or staffed transfer point | Route, schedule, disruption and assistance information |
| Water-service outage support | Online outage map and request portal | Posted notices, local radio, mailed or hand-delivered notice | Printed distribution and service-restoration information | Utility phone line and staffed water-distribution point | Outage information, safe-water instructions and assistance request |
| Correction intake | Web form | Written form, mail-in request, fax | Printed forms and secure drop box | Walk-in appointment or staffed intake | Request receipt, correction processing, status and appeal |
| Appeal submission | Online portal | Written letter, fax, mail | Printed appeal form and in-person drop box | Ombuds office and walk-in appointment | Timely appeal submission, receipt and review |
| Public-benefit renewal | Online account | Mail-in renewal packet | Printed renewal form and staffed drop box | In-person worker or telephone support | Renewal submission and confirmation |
| Public participation | Online meeting and comment portal | Written comments, telephone comment line, posted notices | Printed agenda and materials | In-person meeting with accessible assistance | Equivalent ability to receive information and submit comment |

FEMA’s IPAWS infrastructure supports multiple public alert pathways, including emergency telephone networks, sirens, and digital road signs, which demonstrates the operational value of multi-channel warning systems rather than app-only communication. [101]

### Identity-neutral operation

Verification must confirm that a non-digital pathway does not require:

- A smartphone, app, digital account, email address, or personal device.
- Biometric capture.
- Neural data.
- Augmentation telemetry.
- Disclosure of disability, cybernetic status, health status, housing status, immigration status, or unrelated identity characteristics.
- Identity inference from speech, handwriting, communication method, device use, or assistance request.

Identity may be required only where genuinely necessary for a specific service transaction, and the system must offer the least intrusive lawful verification route with a human-assisted resolution path. The pathway may not use a person’s inability or decision not to use digital tools as an adverse eligibility, queue, quality, or credibility signal.

### Outage verification protocol

Each essential service is tested at least annually and after material system change.

1. Simulate loss of internet connectivity.
2. Simulate loss of electric power at primary digital-service facilities.
3. Simulate loss of the primary application, cloud vendor, identity provider, or telecommunications vendor.
4. Attempt end-to-end completion through each declared non-digital route.
5. Confirm receipt, routing, response, escalation, and final outcome.
6. Verify accessible formats, relay support, language access, mobility access, and human assistance.
7. Verify that a person can use the route without a digital account, app, device, biometric identifier, neural data, augmentation telemetry, or cybernetic-status disclosure.
8. Publish an accessible summary of results, failures, corrective actions, and retest status.

The continuity objective is:

\[
\forall s \in \text{essential services},
\quad
\exists p \in \text{non-digital pathways}(s)
:
\operatorname{complete}(p,s)=1
\]

### Redundancy and single-point-of-failure prevention

Each essential service requires at least two independent non-digital channels. Independence means the channels do not share the same primary failure mechanism.

| Failure mode | Required non-digital resilience control |
|---|---|
| Internet outage | Printed materials, radio, physical signage, telephone service where available, staffed locations |
| Power outage | Battery-backed radio, printed materials, manual forms, staffed sites with backup power |
| Cloud or vendor outage | Paper intake, telephone intake, local manual logs, independent broadcast route |
| Digital identity outage | Human-assisted identity resolution, mail, physical intake, paper receipt |
| Telecommunications outage | Posted notices, radio, public-address systems, staffed locations, door-to-door outreach where appropriate |
| Staffing shortage | Alternate staffing agreements, cross-training, ombuds escalation, mutual aid |
| Physical-material depletion | Restock plan for forms, signage, batteries, radios, paper receipts, translation materials |
| Facility closure | Alternate public site, mobile desk, transit-accessible backup location, local community partner route |

FEMA’s continuity resources are designed for whole-community partners, and federal emergency-communications guidance emphasizes accessible, plain-language communication and multiple delivery methods. [99][105][107]

## Validation and integration

- Validate JSON inputs against the schema before running either TypeScript evaluator.
- Run ECO-05 whenever planned maintenance affects habitat, green infrastructure, shade, cooling, stormwater, water, transit, or essential public-service infrastructure.
- Run ACC-01 before releasing any essential-service digital portal, account system, alerting system, or vendor-integrated intake workflow.
- Treat `no_safe_window`, `emergency_override_review_required`, and ACC-01 `fail` results as release or scheduling blockers until accountable human review occurs.
- Preserve maintenance and pathway-test records as purpose-limited evidence; do not add identity, biometric, neural, health, augmentation, or individual behavior data.
- Publish plain-language decision summaries, weights, evidence quality, limitations, continuity arrangements, and remedy paths.

## Metrics

| Metric | Score | Basis |
|---|---:|---|
| `knowledge_factor` | 0.93 | The design combines seasonal ecological constraints, reliability engineering, public weights, outage testing, and end-to-end service verification |
| `eco_impact_value` | 0.92 | It reduces avoidable disruption to breeding, nesting, migration, habitat, green infrastructure, water systems, and heat-mitigation assets |
| `harm_risk` | 0.13 | Fail-closed reliability thresholds, emergency-review gates, identity-neutral access, and redundant non-digital pathways constrain operational and exclusionary risk |
| `accessibility_impact` | 0.97 | Offline, paper, radio, posted, telephone, staffed, relay-compatible, and in-person routes are treated as first-class essential-service infrastructure |
| `rights_alignment` | 0.98 | The framework preserves autonomy, non-discrimination, privacy, human review, accessible remedies, and universal public-service continuity |
