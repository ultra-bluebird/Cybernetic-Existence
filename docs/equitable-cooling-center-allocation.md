# Equitable Cooling Center Allocation via Vulnerability-Adjusted Minimax Fairness

## Purpose

This algorithm determines which candidate cooling centers to activate during a heat emergency and how to assign neighborhood demand to active sites.

It minimizes the worst normalized heat-access burden experienced by any protected planning group while maintaining accessible, non-discriminatory, privacy-preserving access.

A cooling center is generally an air-conditioned or cooled location designated to provide respite and safety during extreme heat. [90][92] Cooling-center planning commonly considers social vulnerability, proximity, capacity, heat exposure, and access barriers, although research also notes that placement alone does not establish actual use or effectiveness. [86][88]

## Rights and Privacy Invariants

The algorithm must satisfy all of the following:

- Entry to a cooling center must not require a declaration of age, income, disability, health condition, augmentation status, citizenship, address, account, device ownership, payment, biometric identifier, or continuous connectivity.
- No person may be denied ordinary cooling-center access because they decline to disclose a health or augmentation-related need.
- Cybernetic-host or augmentation-related heat sensitivity must be represented only as an opt-in, aggregated planning factor or a community-governed service requirement.
- Individual augmentation, health, neural, biometric, and assistive-technology information must not be stored in the allocation model.
- The model must not identify residences of cybernetic hosts, people with disabilities, or people with health conditions.
- Sites must support universal physical access, accessible communications, restrooms, seating, charging where safely available, water, sensory accommodation, and non-digital entry paths.
- If no candidate site can meet an accessibility requirement, the system must report an unmet-access constraint rather than silently treating the population as served.
- Human emergency managers and community representatives must review activation outputs before operational deployment, except where a pre-approved emergency plan delegates a narrowly defined activation action.

Accessibility of public facilities, services, communications, and transportation is an established inclusion principle; denial of reasonable accommodation is recognized as a form of disability discrimination under the CRPD framework. [84][91]

## Planning Units and Groups

Define:

- \(i \in I\): planning demand zones, such as census tracts, accessible service areas, or privacy-preserving grid cells.
- \(j \in J\): candidate cooling-center sites.
- \(g \in G\): vulnerability groups represented only by aggregated demand estimates.

Groups may include:

- Older adults.
- Young children and caregivers.
- Low-income households and households without reliable cooling.
- People with chronic health-related heat vulnerability.
- Outdoor workers and people with high outdoor exposure.
- People requiring accessible mobility, communication, sensory, or medical-support accommodations.
- An opt-in aggregate category for heat-sensitive assistive or augmentative technology requirements.

The final category must be governed as a service-capacity signal, not as an identity class. For example, it can represent the expected number of cooling-center seats requiring reliable low-heat charging, accessible repair-space, reduced sensory stimulation, or specific device-safe ambient conditions.

## Input Variables

For each zone \(i\), group \(g\), and candidate site \(j\):

- \(p_{i,g}\): aggregate heat-vulnerable population estimate.
- \(h_i\): normalized local heat burden, from a heat-risk or UHI indicator.
- \(a_{i,g}\): non-heat vulnerability factor, including age, income, health-access barriers, cooling access, and mobility barriers.
- \(r_{i,g}\): aggregate, opt-in service-requirement factor for heat-sensitive assistive or augmentative technology.
- \(c_j\): usable cooling-center capacity.
- \(b_j\): activation cost.
- \(u_j\): binary accessibility certification indicator.
- \(q_j\): site service-quality score, including water, restroom, backup power, accessible entry, charging safety, transit access, and trained staff.
- \(\tau_{i,j}\): accessible travel time from zone \(i\) to site \(j\).
- \(\tau^{\max}_{g}\): maximum acceptable accessible travel time for group \(g\).
- \(B\): available activation budget.
- \(K\): maximum number of sites that can be opened.
- \(M\): sufficiently large numeric constant.

## Vulnerability Weight

Compute a bounded zone-group vulnerability weight:

\[
w_{i,g}
=
\operatorname{clip}
\left(
0.34h_i
+
0.22a^{\mathrm{age}}_{i,g}
+
0.18a^{\mathrm{income}}_{i,g}
+
0.18a^{\mathrm{health}}_{i,g}
+
0.08r_{i,g},
0,
1
\right)
\]

The augmentation-related term is intentionally limited and opt-in. It does not assume that all cybernetic hosts have heat-sensitive systems, and it does not reduce the model’s obligation to serve any other group. Its purpose is to support concrete universal-service features where a community identifies a real need.

## Service Burden

For each zone-group pair, calculate the expected normalized burden:

\[
\operatorname{Burden}_{i,g}
=
w_{i,g}
\left[
0.55
\sum_{j \in J}
x_{i,j,g}
\frac{\tau_{i,j}}{\tau^{\max}_g}
+
0.25(1-\operatorname{Coverage}_{i,g})
+
0.20(1-\operatorname{Quality}_{i,g})
\right]
\]

Where:

\[
\operatorname{Coverage}_{i,g}
=
\frac{
\sum_{j \in J}x_{i,j,g}
}{
\max(1,p_{i,g})
}
\]

\[
\operatorname{Quality}_{i,g}
=
\frac{
\sum_{j \in J}x_{i,j,g}q_j
}{
\max(1,p_{i,g})
}
\]

The allocation variable \(x_{i,j,g}\) is the number of people in zone \(i\), group \(g\), assigned to site \(j\).

Travel time, unmet demand, and site-quality gaps are all included so that a technically open cooling center does not count as full service if it is too distant, inaccessible, unsafe, or poorly equipped.

## Minimax Objective

Let \(z\) be the largest normalized burden across all zone-group pairs.

\[
\min z
\]

Subject to:

\[
\operatorname{Burden}_{i,g} \le z
\quad
\forall i \in I,\; g \in G
\]

The model then uses a second-stage objective to minimize total weighted travel time while keeping the optimal maximum burden fixed:

\[
\min
\sum_{i \in I}
\sum_{j \in J}
\sum_{g \in G}
w_{i,g}x_{i,j,g}\tau_{i,j}
\]

This lexicographic structure prevents a large, easy-to-serve population from absorbing most resources while a smaller, highly burdened group remains effectively excluded.

## Constraints

### Site Activation

\[
y_j \in \{0,1\}
\quad
\forall j \in J
\]

\[
\sum_{j \in J} b_jy_j \le B
\]

\[
\sum_{j \in J} y_j \le K
\]

\[
y_j \le u_j
\]

A non-accessible site cannot be selected as a valid center unless the relevant accessibility condition has been independently remediated and certified.

### Capacity

\[
\sum_{i \in I}
\sum_{g \in G}
x_{i,j,g}
\le
c_jy_j
\quad
\forall j \in J
\]

### Assignment

\[
\sum_{j \in J}x_{i,j,g}
+
m_{i,g}
=
p_{i,g}
\quad
\forall i \in I,\; g \in G
\]

Where \(m_{i,g}\) is unmet demand. It is visible in output and heavily penalized; it may never be silently dropped.

### Accessible Travel

\[
x_{i,j,g}
=
0
\quad
\text{when }
\tau_{i,j} > \tau^{\max}_{g}
\]

A group-specific accessible travel threshold can account for transit frequency, pedestrian safety, mobility limitations, extreme heat exposure during travel, and the availability of accessible shuttle service.

### Minimum Service Floor

\[
\sum_{j \in J}x_{i,j,g}
\ge
\alpha_{i,g}p_{i,g}
\]

When feasible, each zone-group pair receives at least its published emergency service floor \(\alpha_{i,g}\). If infeasible, the model reports the deficit and identifies the additional capacity, transport, or site remediation required.

### No Group Disproportionately Exposed

Let \(\overline{\operatorname{Burden}}\) be the population-weighted mean burden.

\[
\operatorname{Burden}_{i,g}
\le
\gamma
\overline{\operatorname{Burden}}
+
\delta
\]

Where:

- \(\gamma\) is the approved fairness multiplier.
- \(\delta\) is a small operational tolerance.

This constraint supplements minimax optimization by preventing a group from being repeatedly assigned a much worse access condition than the citywide service level.

## Heatwave Activation

Activate the optimization when a heat-health alert, forecast threshold, or observed local heat burden meets the jurisdiction’s approved emergency trigger.

The model should update:

- Forecast and observed heat burden.
- Site availability and backup-power state.
- Accessible transport status.
- Cooling-center staffing and capacity.
- Aggregate demand assumptions.
- Public-service outages.
- Community-reported accessibility barriers.

No last-minute activation process may depend on collecting personal health or augmentation status.

## Outputs

The algorithm must publish:

- Selected site set.
- Capacity and accessible-service features for each selected site.
- Zone-to-site aggregate assignment plan.
- Maximum and mean group burden.
- Unmet demand by zone and group.
- Distance and accessible travel-time distributions.
- Which constraints were binding.
- Required remediation if accessibility, capacity, transport, or budget constraints prevented the service floor.
- A privacy statement describing what the model did not collect.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.92 | Uses explicit optimization variables, capacity, accessibility, travel, vulnerability, and fairness constraints |
| eco_impact_value | 0.71 | Supports heat resilience, reduces preventable heat harm, and can coordinate use of existing conditioned public spaces |
| harm_risk | 0.19 | Controlled through aggregate planning, no identity registry, human review, accessibility gates, and transparent unmet-demand outputs |
| accessibility_impact | 0.99 | Makes accessible entry, travel, communications, power, restrooms, service features, and non-digital access hard constraints |
| rights_alignment | 0.98 | Prohibits exclusionary eligibility, personal profiling, mandatory disclosure, and hidden unmet-demand treatment |
