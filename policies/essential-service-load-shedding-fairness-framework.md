# Essential Service Load Shedding Fairness Framework

## Purpose

This framework governs emergency electricity load-shedding decisions. It protects life-sustaining and community-critical services, distributes unavoidable hardship equitably, preserves accessibility, and makes every decision explainable, reviewable, and contestable.

It is a governance and technical policy specification. It is not a substitute for electric-system reliability standards, emergency-management law, utility tariffs, disability-rights obligations, or jurisdiction-specific legal review.

## Safety and Rights Boundary

No automated system may independently authorize a load-shedding action that:

- Removes power from a protected essential-service load.
- Creates a known, immediate, avoidable threat to life, health, bodily integrity, or continuity of an assistive technology.
- Relies on augmentation status, disability status, health data, neural data, biometric data, identity records, consumer profiling, or inferred vulnerability.
- Makes access to emergency assistance conditional on a digital identity, an online account, a smartphone, continuous connectivity, or proprietary equipment.
- Uses aggregate fairness results to justify a localized, rights-incompatible outage.

Grid stability and immediate electrical safety remain hard constraints. Where a protective constraint conflicts with preventing cascading system failure, the operator must use the least rights-restrictive technically feasible intervention, activate emergency support measures, document the conflict, and route the decision for rapid independent review.

## Definitions

### Essential service

An essential service is a function whose interruption is reasonably likely to create an immediate or near-term threat to life, health, safety, access to basic necessities, or the ability of a community to respond to an emergency.

Essential classification is based on service function and dependency evidence, not on the social status, wealth, identity, augmentation, disability, or political influence of a service user.

Protected essential-service functions include:

- Emergency dispatch, firefighting, rescue, emergency medical response, and public safety communications.
- Acute and ongoing health care, urgent care, dialysis, pharmacies with cold-chain or life-critical dispensing needs, and medically necessary shelter operations.
- Drinking-water treatment, wastewater treatment, pumping, sanitation, and flood-control functions.
- Emergency communications, public warning, accessible emergency-information delivery, and designated community communications hubs.
- Cooling, heating, food, hydration, and sanitation services activated for life-safety conditions.
- Mobility, charging, and communications functions necessary for people who depend on assistive, medical, or augmentative technologies during an emergency.
- Publicly designated evacuation, respite, disaster-recovery, and mutual-aid sites.

A protected service designation does not imply unlimited electricity use. It establishes a minimum continuity floor and a controlled reduction sequence.

### Non-essential discretionary load

A non-essential discretionary load is electricity demand that can be reduced, shifted, or interrupted for a defined period without reasonably undermining protected essential-service functions, emergency access, basic habitability, or accessibility.

### Neighborhood

A neighborhood is an operational aggregation used only to evaluate geographic burden distribution. It must be defined from stable electrical-service zones and published before an emergency whenever feasible. Boundaries must not be drawn or changed to dilute, conceal, or manufacture inequity.

### Burden

Burden is the harm-relevant amount of unavoidable reduction borne by a neighborhood after protected essential-service floors and feasible mitigation have been applied.

Burden must be normalized. Raw megawatt reduction alone is not a fair comparison because neighborhoods differ in population, baseline demand, critical-load concentration, and ability to withstand interruption.

## Anti-Gaming Essential Classification

### Pre-event service registry

A utility or public authority may maintain a facility and function registry for continuity planning, provided that it contains only the operational minimum:

- Facility or service function category.
- Electrical feeder or service-zone relationship.
- Verified minimum continuity requirement in kilowatts or kilowatt-hours.
- Safe reduction sequence and maximum interruption duration.
- Backup capability category and tested duration range.
- Verification date, review date, and responsible operational contact.
- Appeal, correction, and emergency-update path.

The registry must not require or collect:

- Individual medical diagnoses.
- Disability, augmentation, neural, biometric, or identity data.
- Individual household device inventories.
- Consumer behavior histories unrelated to continuity planning.
- Information obtained through coercive consent or mandatory disclosure.

### Functional qualification test

A service qualifies for a protected continuity floor only when all conditions hold:

1. The service performs a listed essential function or an equivalent locally validated function.
2. A disruption has a credible, documented pathway to life, health, safety, water, sanitation, emergency communication, accessibility, or emergency-response harm.
3. The requested floor is the minimum technically necessary to maintain the protective function.
4. The service has submitted a reduction sequence showing which internal loads can be curtailed before the continuity floor is affected.
5. The designation has a time limit and a periodic review requirement.
6. The evidence is auditable by an independent reviewer without disclosure of protected personal data.

### Controls against designation capture

- Separate verification from service ownership, political office, donor influence, and emergency-operations command.
- Publish the essential-function taxonomy, eligibility evidence categories, minimum-load methodology, review intervals, and appeal route.
- Require conflict-of-interest declarations from reviewers.
- Apply the same functional test to public, private, nonprofit, cooperative, and informal community-service providers.
- Permit confidential evidence submissions when publication would expose protected infrastructure or service users.
- Publish aggregated designation statistics and decision rationales.
- Reassess temporary designations after the emergency; expiration is automatic unless renewed through the documented process.
- Audit for systematic overclassification, underclassification, geographic concentration, and unequal approval rates.

## Decision Order

Load shedding must follow this order, subject to electrical safety and real-time grid-stability constraints:

1. Preserve grid integrity and prevent uncontrolled cascading failure.
2. Maintain protected essential-service continuity floors.
3. Reduce or shift voluntary and contractually interruptible discretionary demand, without penalizing people who cannot participate.
4. Reduce non-essential discretionary demand using the equitable burden allocation method.
5. Apply short, rotating, bounded interruptions where reductions remain necessary.
6. Activate backup power, cooling, communications, shelter, water, and accessibility supports where continuity floors cannot be maintained.
7. Restore protected functions first, then reduce accumulated burden disparities as quickly as technical conditions allow.

No household, neighborhood, or service zone may be selected because residents are presumed less likely to complain, less politically connected, less digitally connected, less able to organize, or less able to contest a decision.

## Core Metrics

### Equalized normalized burden

For each neighborhood \(i\), calculate normalized burden:

\[
x_i =
\frac{
E^{\text{unserved}}_i
+
\lambda_d D_i
+
\lambda_c C_i
+
\lambda_a A_i
}{
P_i + \epsilon
}
\]

Where:

- \(E^{\text{unserved}}_i\) is unserved energy in kilowatt-hours.
- \(D_i\) is outage duration in hours.
- \(C_i\) is the count or severity-weighted duration of continuity-floor violations.
- \(A_i\) is the count or severity-weighted duration of accessibility-support failures.
- \(P_i\) is the stable service population denominator or an approved equivalent service denominator.
- \(\lambda_d\), \(\lambda_c\), and \(\lambda_a\) are publicly adopted weights.
- \(\epsilon\) is a small, documented stabilizing constant used only when necessary to avoid division by zero.

The weights must not be selected after an event to justify a preferred outcome. They require pre-event publication, public consultation, and versioned approval.

### Load-shedding fairness metric

\[
F_{\text{shedding}} =
\frac{
\left(\sum_{i=1}^{n} x_i\right)^2
}{
n\sum_{i=1}^{n}x_i^2
}
\]

Where:

- \(x_i\) is normalized burden for neighborhood \(i\).
- \(n\) is the number of comparable neighborhoods included in the operational region.

Interpretation:

- \(F_{\text{shedding}} = 1\) means equal normalized burden among included neighborhoods.
- Lower values indicate increasing burden concentration.
- The metric is undefined when all \(x_i = 0\); report this condition as `no_shedding_burden`.
- The metric must never be the sole decision criterion. A high score cannot excuse a continuity-floor violation, inaccessible emergency communication, or a known disparate safety harm.

### Essential-service preservation metric

\[
E_{\text{preserved}} =
\frac{
\sum_{j \in \mathcal{E}} w_j S_j
}{
\sum_{j \in \mathcal{E}} w_j
}
\]

Where:

- \(\mathcal{E}\) is the protected essential-service set.
- \(S_j \in [0,1]\) is the observed availability of service \(j\).
- \(w_j\) is a pre-approved function-criticality weight.

This form measures whether essential services remain available, rather than comparing essential availability against non-essential availability. Non-essential service preservation is important, but it must not mathematically offset a failure of a protected life-safety function.

Availability should be measured by the actual service outcome where feasible, not merely whether a building has electrical supply. For example, a water facility is available when safe water treatment and distribution remain functional, and an accessible cooling center is available when people can receive and use the service.

### Continuity-floor compliance

\[
C_{\text{floor}} =
\frac{
\sum_{j \in \mathcal{E}} w_j \mathbf{1}
\left[
L_j(t) \geq L^{\text{floor}}_j(t)
\right]
}{
\sum_{j \in \mathcal{E}}w_j
}
\]

Where:

- \(L_j(t)\) is delivered usable electrical capacity for service \(j\).
- \(L^{\text{floor}}_j(t)\) is the verified minimum continuity floor.
- \(\mathbf{1}\) equals 1 when the continuity floor is met and 0 otherwise.

The operational target is:

\[
C_{\text{floor}} = 1
\]

Any value below 1 requires immediate incident classification, mitigation, public notice, retrospective review, and corrective action.

### Maximum disparity constraint

Fairness is not satisfied solely by a high aggregate score. Use a direct disparity constraint:

\[
\max_i x_i - \min_i x_i \leq \Delta_{\max}
\]

Where \(\Delta_{\max}\) is a pre-approved maximum difference in normalized burden for comparable neighborhoods over the declared emergency window.

The comparison must exclude only zones that are demonstrably electrically non-comparable because of a documented safety or topology constraint. Every exclusion requires a public reason category and independent review.

### Restoration debt

When unavoidable technical conditions impose unequal burden, track restoration debt:

\[
R_i =
\max \left(
0,
x_i - \operatorname{median}(x_1,\dots,x_n)
\right)
\]

Neighborhoods with higher restoration debt receive priority for restoration, supplementary support, and future planned-outage avoidance, subject to life-safety and grid-stability constraints.

## Emergency Fairness Criteria

A load-shedding plan is rights-compatible only when all applicable conditions are satisfied:

- Essential continuity floors are preserved, or a documented grid-safety exception and compensating support plan is active.
- Every avoidable continuity-floor violation is treated as a failure, regardless of aggregate fairness performance.
- Reductions are based on technical feasibility, least harm, and bounded duration.
- Equivalent neighborhoods receive comparable normalized burden over the emergency window.
- The plan does not use protected, sensitive, or inferred personal characteristics.
- Assistive technology users can access backup-power support, accessible communications, cooling or heating support, charging, and grievance channels without proving a diagnosis or revealing augmentation details.
- Notice and emergency support are available through online and offline methods.
- The plan includes a non-retaliatory appeal and rapid human review path.
- Each operational decision has a retained, privacy-minimized audit record.
- Restoration actively corrects accumulated inequality rather than treating past outages as irrelevant.

## Transparent Public Communication

### Before an emergency

Publish:

- The essential-service taxonomy and functional qualification test.
- The continuity-floor methodology.
- The load-shedding sequence and maximum planned interruption duration.
- The metric definitions, weights, comparability rules, and known limitations.
- Accessible instructions for emergency support, charging, cooling, medication storage, communications, water, sanitation, and appeal.
- How residents can request a reasonable accommodation without unnecessary disclosure.
- A public explanation of what data are not collected or used.

### During an emergency

Each public notice must state:

- What happened and why load reduction is necessary.
- The affected service area in plain language and accessible map alternatives.
- Start time, estimated duration range, uncertainty level, and next update time.
- Which essential functions are protected and the current status of those functions.
- Available support locations and access methods.
- Accessible contact routes, including voice, text, relay-compatible, web, low-bandwidth, and in-person or community-partner pathways.
- A concise explanation of how fairness and restoration debt are being monitored.
- A route to report an urgent life-safety or accessibility failure.

Information must be available in accessible, readable, machine-readable, multilingual, captioned, text-first, screen-reader-compatible, and low-bandwidth forms. Public entities should provide communication that is effective for people with communication disabilities; federal ADA guidance describes effective communication obligations for covered public entities and public-facing organizations. [54]

### After an emergency

Publish a privacy-preserving after-action report containing:

- Total reduction required and reduction delivered.
- Essential-service preservation and continuity-floor compliance.
- Fairness score, disparity constraint result, and restoration-debt outcomes.
- Outage durations and burden distributions by service zone.
- Number and category of essential-service exceptions.
- Number, response time, and resolution status of urgent accessibility and safety reports.
- Data limitations, uncertainty, model errors, and operator overrides.
- Corrective actions, public-review dates, and independent-audit findings.

Do not publish household-level outage histories, medical needs, assistive-device dependencies, exact locations of vulnerable people, or sensitive critical-infrastructure details.

## Audit Record

For every decision interval, retain a tamper-evident, access-controlled record with:

- Decision time and effective interval.
- System emergency condition and available capacity.
- Required reduction and technically feasible alternatives considered.
- Protected essential-service floor status.
- Aggregate burden values and fairness calculations.
- Comparability exclusions and the supporting operational rationale.
- Human approvals, emergency overrides, and conflict-of-interest declarations.
- Public notice version and dissemination channels.
- Safety, accessibility, and support actions activated.
- Review outcome and retention-deletion schedule.

Audit records must be privacy-minimized. They must not become a hidden registry of disability, augmentation, health, neural, biometric, or identity information.

## Governance and Review

- Establish a standing independent review group with utility engineering, emergency management, disability and assistive-technology expertise, public-health expertise, community representation, and privacy expertise.
- Ensure participation routes do not require disclosure of cybernetic existence, augmentation use, disability status, health information, or identity.
- Provide accessible, compensated community consultation before approving weights, service classifications, and burden thresholds.
- Require post-event review for every continuity-floor failure, every emergency override, and every material disparity breach.
- Maintain a correction mechanism for facility-classification errors and a public process for challenging policy rules.
- Use aggregate analysis to identify unequal burdens; do not use it to profile or target individuals or protected groups.

## External Reference Context

FEMA describes community lifelines as the fundamental services whose stabilization enables other aspects of society to function, including energy. [53] The National Academies notes that automatic under-frequency load shedding is a common grid-stability strategy after unanticipated generation loss. [56] These sources support the need to distinguish fast grid-protection actions from the broader, reviewable public-allocation decisions governed by this framework.

## Metrics

- knowledge_factor: 0.88
  - Basis: The framework uses transparent, auditable burden-distribution and service-continuity measures, while local topology, service thresholds, and regulatory requirements require jurisdiction-specific validation.
- eco_impact_value: 0.71
  - Basis: Controlled reduction and restoration-debt accounting can reduce uncontrolled cascading failures and support resilient energy use without shifting environmental burdens onto communities.
- harm_risk: 0.22
  - Basis: Remaining risk is concentrated in real-time grid constraints and inaccurate service classification; continuity floors, human review, accessible support, and audit requirements constrain that risk.
- accessibility_impact: 0.95
  - Basis: Accessibility is a hard operational consideration through continuity floors, accessible notices, non-digital support, and rapid review pathways.
- rights_alignment: 0.96
  - Basis: The framework prohibits sensitive-data targeting, treats essential service continuity as a constraint, supports contestability, and requires privacy-minimized accountability.
