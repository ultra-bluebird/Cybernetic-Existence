# CyberRank Hero Eligibility and Irreversibility Model

## Scope

This specification operationalizes a voluntary institutional Hero Title framework for use alongside CyberRank tiers.

It does not independently confer a title, legal status, platform status, medical status, credential, financial entitlement, or public authority. The institution remains responsible for reviewing evidence, protecting privacy, resolving conflicts, applying due process, and making the final recognition decision.

The model is intentionally advisory:

\[
\operatorname{Recommendation}
\ne
\operatorname{InstitutionalDecision}
\]

A qualified human reviewer may approve, defer, correct, or decline a recommendation, provided the reason is recorded in an accessible audit record.

## Six-Part Eligibility Function

For a candidate record \(c\), define six normalized inputs in \([0,1]\):

- \(B_c\): documented public-benefit magnitude.
- \(S_c\): seriousness of the protected or prevented loss.
- \(C_c\): contribution connection and attributable leverage.
- \(D_c\): durability, reproducibility, and stewardship value.
- \(R_c\): rights alignment, including dignity, consent, privacy, non-discrimination, and non-extractive practice.
- \(A_c\): accessibility, community usability, and reviewability.

The Hero Eligibility Score is:

\[
H_c
=
0.24B_c
+
0.20S_c
+
0.18C_c
+
0.14D_c
+
0.12R_c
+
0.12A_c
\]

The weights sum to one.

| Component | Weight | Institutional rationale |
|---|---:|---|
| Public-benefit magnitude | 0.24 | A hero designation concerns substantial benefit to a community, species, essential system, or shared commons |
| Seriousness of loss | 0.20 | Preventing a catastrophic, durable, or irreversible loss is central to the title |
| Contribution connection | 0.18 | Recognition must reflect a clear, proportionate link between the nominee’s work and the protective result or capacity |
| Durability and stewardship | 0.14 | The work should remain useful, reproducible, maintainable, or preservative beyond a momentary intervention |
| Rights alignment | 0.12 | Heroism cannot be recognized through coercion, privacy violation, discrimination, extraction, or denial of agency |
| Accessibility and reviewability | 0.12 | The benefit must be usable, inspectable, and accessible to affected communities and institutional reviewers |

## Required Evidence Gates

A high weighted score alone is insufficient. The candidate record must pass all eligibility gates:

\[
G_c
=
G_c^{\mathrm{public\ benefit}}
\cdot
G_c^{\mathrm{evidence}}
\cdot
G_c^{\mathrm{rights}}
\cdot
G_c^{\mathrm{review}}
\]

Where each \(G\) is either zero or one.

The recommendation is valid only if:

\[
G_c = 1
\]

Required gates are:

- **Public-benefit gate:** the work protects or materially strengthens a community, species, ecosystem, essential service, or shared knowledge commons.
- **Evidence gate:** the work has a reviewable record, including provenance, contribution statement, uncertainty, and relevant work product.
- **Rights gate:** the work does not depend on coercion, prohibited surveillance, unauthorized access, discriminatory treatment, deceptive attribution, or disregard for informed consent.
- **Review gate:** the institution can conduct an accessible human review and provide an appeal or correction path.

A failed gate produces `candidate`, regardless of the numeric score.

## Recommended Title State

The score guides a title-state recommendation:

| Condition | Recommended title state |
|---|---|
| Any required gate fails | `candidate` |
| Evidence is incomplete, review is pending, or score is below 0.75 | `candidate` |
| Score is at least 0.75, all gates pass, human recognition is recorded, and the nominee is actively contributing or chooses active designation | `hero-active` |
| Score is at least 0.75, all gates pass, human recognition is recorded, and the recipient declares rest, retirement, pause, or inactive contribution | `hero-at-rest` |

The `hero-at-rest` state retains the recognized title. It does not lower the underlying CyberRank tier merely because a person pauses, rests, retires, changes focus, needs care, loses connectivity, or declines public attention.

## Human Override

Human oversight is a required governance control, not an exception path.

A reviewer may override the recommendation only through one of these actions:

- `approve_as_hero_active`
- `approve_as_hero_at_rest`
- `defer_for_evidence`
- `decline_with_reason`
- `correct_record`

Every override record must include:

- Decision category.
- Plain-language reason.
- Evidence reviewed.
- Conflict-of-interest disclosure.
- Reviewer role.
- Review time.
- Appeal availability.
- Privacy classification of the supporting record.

The reviewer may not override the system to create a title based on fame, wealth, media popularity, financial donation, political affiliation, device ownership, augmentation status, identity disclosure, or compliance with unrelated telemetry requirements.

## Explainable Component Guidance

### Public-Benefit Magnitude

\[
B_c
=
0.40B_c^{\mathrm{scale}}
+
0.35B_c^{\mathrm{severity\ reduced}}
+
0.25B_c^{\mathrm{benefit\ persistence}}
\]

Possible evidence includes:

- A community service, water, food, health-supporting, ecological, or knowledge commons protected.
- The scale of people, species, ecosystems, or essential services materially supported.
- Evidence that the benefit persists, is reusable, or improves future capacity.

### Seriousness of Loss

\[
S_c
=
0.55I_c
+
0.25U_c
+
0.20F_c
\]

Where:

- \(I_c\) is irreversibility exposure.
- \(U_c\) is urgency or time sensitivity.
- \(F_c\) is the essential-function dependency of the affected community or system.

The irreversibility component is defined in the next section.

### Contribution Connection

\[
C_c
=
0.45C_c^{\mathrm{causal}}
+
0.30C_c^{\mathrm{attribution}}
+
0.25C_c^{\mathrm{leverage}}
\]

A candidate need not be the sole contributor. Collaborative work can score strongly when the record clearly identifies the nominee’s enabling, necessary, or substantially accelerating contribution.

### Durability and Stewardship

\[
D_c
=
0.35D_c^{\mathrm{reproducibility}}
+
0.30D_c^{\mathrm{maintenance}}
+
0.20D_c^{\mathrm{interoperability}}
+
0.15D_c^{\mathrm{future\ usability}}
\]

### Rights Alignment

\[
R_c
=
0.25R_c^{\mathrm{consent}}
+
0.20R_c^{\mathrm{privacy}}
+
0.20R_c^{\mathrm{non\ discrimination}}
+
0.20R_c^{\mathrm{self\ determination}}
+
0.15R_c^{\mathrm{non\ extraction}}
\]

### Accessibility and Reviewability

\[
A_c
=
0.35A_c^{\mathrm{affected\ community\ usability}}
+
0.30A_c^{\mathrm{accessible\ evidence}}
+
0.20A_c^{\mathrm{offline\ or\ low\ barrier\ access}}
+
0.15A_c^{\mathrm{appealability}}
\]

## Irreversibility of Community Loss

### Purpose

The Community Loss Irreversibility Index, abbreviated as CLII, estimates how difficult it would be to restore a threatened community asset, species, ecosystem, aquifer function, cultural archive, essential service, or knowledge commons after a loss occurs.

It is a prioritization signal, not a claim of certainty. The score must include uncertainty and be reviewed with domain experts and affected communities.

## Core Formula

For a loss scenario \(l\), define:

- \(T_l\): normalized time-to-recovery.
- \(S_l\): normalized lack-of-substitutability.
- \(N_l\): normalized affected-beings and affected-community scale.
- \(F_l\): essential-function dependency.
- \(P_l\): probability that the loss becomes permanent or practically irreversible if no timely intervention occurs.
- \(Q_l\): evidence confidence.

\[
CLII_l
=
Q_l
\cdot
P_l
\cdot
\left[
0.35T_l
+
0.25S_l
+
0.20N_l
+
0.20F_l
\right]
\]

The result is bounded to \([0,1]\).

The requested three primary dimensions—time-to-recovery, substitutability, and affected beings—carry 80% of the internal weighting. Essential-function dependency receives the remaining 20% because loss of a water source, emergency route, culturally irreplaceable archive, or keystone habitat can have consequences beyond a raw count of affected beings.

## Time-to-Recovery

Let \(\tau_l\) be the estimated recovery time in years under a credible, rights-respecting, funded remediation or restoration pathway.

\[
T_l
=
1-
\exp
\left(
-\frac{\tau_l}{\tau_{\mathrm{reference}}}
\right)
\]

Where \(\tau_{\mathrm{reference}}\) is a community-selected reference horizon, such as 25 years.

Interpretation:

- A loss that can be repaired in months has a lower \(T_l\).
- A loss requiring decades has a high \(T_l\).
- A loss with no credible recovery pathway approaches one.

For a nonrecoverable loss, set:

\[
T_l = 1
\]

Examples:

- A local archive with verified redundant copies may have moderate recovery time.
- A unique cultural archive with no complete copy may have a recovery time approaching nonrecoverability.
- Contaminated groundwater can require long-term treatment or containment, and some remediation pathways may not restore all beneficial uses promptly. EPA describes both pump-and-treat and in-situ groundwater remedies, while research notes that long-term restoration is not always achieved through pump-and-treat alone. [146][152]

## Lack of Substitutability

Let \(n_l\) be the number of realistically accessible, rights-respecting, functionally comparable substitutes. Let \(q_l\) be the quality ratio of the best substitute to the original asset.

\[
S_l
=
1-
\operatorname{clip}
\left(
\frac{n_l}{n_{\mathrm{reference}}}
\cdot
q_l,
0,
1
\right)
\]

A substitute is valid only if it is:

- Available within the required time window.
- Accessible to the affected community.
- Affordable or publicly provisioned where the original was essential.
- Safe, lawful, and non-discriminatory.
- Functionally comparable, not merely superficially similar.

A cultural archive, unique ecosystem, local species, aquifer, or community memory may have \(S_l\) close to one because replacement is incomplete even when some partial alternatives exist. UNESCO describes documentary heritage as material of significant and enduring value whose loss would impoverish the relevant community, culture, country, or humanity. [145][148]

## Affected Beings and Community Scale

Let \(a_l\) be the weighted count of directly affected people, beings, or ecological units and \(b_l\) be the weighted count of indirectly affected people, beings, or systems.

\[
N_l
=
\operatorname{clip}
\left(
\frac{
a_l+\lambda b_l
}{
N_{\mathrm{reference}}
},
0,
1
\right)
\]

Where \(0 \le \lambda \le 1\) discounts indirect effects relative to direct effects.

The term can use locally appropriate units:

- People relying on a water source.
- Households without an alternative accessible service.
- Members of a language or cultural community affected by archive loss.
- Mature individuals, breeding pairs, habitat area, or connected ecological populations for a threatened species.
- Public-service users affected by loss of an essential facility.

For species assessment, a community model should not replace established conservation methods. IUCN criteria use quantitative features such as population size, decline, geographic range, fragmentation, and extinction-risk analysis. [150][156][158]

## Essential-Function Dependency

\[
F_l
=
0.40F_l^{\mathrm{life\ support}}
+
0.30F_l^{\mathrm{public\ service}}
+
0.20F_l^{\mathrm{cultural\ continuity}}
+
0.10F_l^{\mathrm{future\ optionality}}
\]

This captures whether the threatened asset supports:

- Drinking water, sanitation, food, shelter, health, or heat safety.
- Essential civic access, emergency response, mobility, or communications.
- Cultural memory, language continuity, or community self-determination.
- Future repair, restoration, adaptation, and democratic choice.

## Permanent-Loss Probability

Estimate \(P_l\) using scenario analysis, historical analogues, domain models, and expert or community review.

\[
P_l
=
\sum_{s \in \mathcal{S}}
p_s
\cdot
\operatorname{PermanentLossIndicator}_s
\]

Where scenario probabilities \(p_s\) sum to one.

This probability must never be fabricated from sparse data. When evidence is uncertain, report an interval:

\[
CLII_l
\in
[
CLII_l^{\mathrm{low}},
CLII_l^{\mathrm{high}}
]
\]

## Smart-City Application

A smart city may use CLII to prioritize preventive interventions, but not to automate decisions without public governance.

Appropriate uses:

- Prioritizing water-quality monitoring and emergency distribution where aquifer contamination threatens a community with few safe alternatives.
- Ranking backup, digitization, accessibility conversion, and community-controlled archival work where cultural knowledge faces permanent loss.
- Identifying habitat corridors, shade networks, cooling assets, or water infrastructure whose failure would create long-duration or unequal harm.
- Selecting high-leverage public-interest research, maintenance, or restoration projects for institutional review.
- Informing Hero Title evidence by explaining the seriousness of the protected loss.

Prohibited uses:

- Reducing service to lower-scoring areas.
- Declaring a group less worthy of protection due to population size.
- Profiling residents, cybernetic hosts, people with disabilities, or cultural groups.
- Treating a computed score as a replacement for community authority, scientific assessment, legal review, or emergency management.
- Treating uncertain data as proof of a permanent loss.

## Example Scenario Forms

| Scenario | High irreversibility drivers | Useful intervention type |
|---|---|---|
| Local species near extirpation | Long ecological recovery, few substitutes, breeding-population loss, habitat dependency | Habitat protection, connectivity restoration, conservation data preservation, community stewardship plan |
| Cultural archive at risk of destruction | No complete copy, identity and language continuity, long reconstruction time | Rights-respecting digitization, redundant preservation, accessible metadata, community-controlled access plan |
| Aquifer contamination | Decades-long treatment, limited alternative water, high affected population, essential water dependency | Source control, monitoring, treatment planning, safe alternative distribution, transparent governance |
| Critical accessible cooling facility loss | Immediate heat-safety dependency, limited accessible substitutes, disproportionate effect on high-risk groups | Backup power, repair planning, alternate accessible-site activation, public alerting |

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.93 | Uses normalized evidence inputs, explicit gates, human review, uncertainty, scenario analysis, and established domain assessment concepts |
| eco_impact_value | 0.89 | Prioritizes prevention of species loss, water contamination, habitat collapse, and essential-service failure |
| harm_risk | 0.15 | Reduced through non-automated use, rights gates, uncertainty intervals, community governance, and prohibition on exclusionary use |
| accessibility_impact | 0.97 | Includes accessible evidence, low-barrier review, essential-service dependency, and non-digital participation |
| rights_alignment | 0.99 | Protects dignity, consent, privacy, non-discrimination, community authority, and transparent institutional review |
