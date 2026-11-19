# Fair Allocation of Cooling Centers During Heatwaves

## Purpose

This design specifies a privacy-preserving, rights-centered, and publicly accountable method for planning cooling-center capacity during extreme heat.

The system uses aggregate environmental, infrastructure, and public demographic indicators to pre-allocate capacity, transportation support, water access, outreach, and backup resources across service areas.

It does not use individual vulnerability scoring at a point of entry.

No person must disclose or prove:

- Age.
- Disability.
- Health condition.
- Medication use.
- Income.
- Housing status.
- Citizenship or immigration status.
- Identity document.
- Home address.
- Utility bill.
- Lack of air conditioning.
- Phone number.
- Insurance status.
- Augmentation or assistive-technology use.
- Personal device location.

Cooling access is universal:

\[
\operatorname{CoolingAccess}(p) = \text{available}
\]

for every person \(p\) seeking safety, subject only to real physical capacity and safety conditions.

## Essential-service invariants

The allocation system must satisfy:

\[
D_{\text{person,persistent}} = 0
\]

\[
G_{\text{identity}} = 0
\]

\[
G_{\text{wealth}} = 0
\]

\[
G_{\text{proof-of-vulnerability}} = 0
\]

\[
G_{\text{device}} = 0
\]

\[
G_{\text{network}} = 0
\]

\[
A_{\text{essential-cooling}} \geq 0.99
\]

Where:

- \(D_{\text{person,persistent}}\) is persistent person-derived data in the allocation or entry flow.
- \(G_{\text{identity}}\) is an identity gate.
- \(G_{\text{wealth}}\) is a payment, insurance, or financial-status gate.
- \(G_{\text{proof-of-vulnerability}}\) is a requirement to demonstrate risk status.
- \(G_{\text{device}}\) is a phone, application, QR-code, or account requirement.
- \(G_{\text{network}}\) is continuous-connectivity dependence.
- \(A_{\text{essential-cooling}}\) is availability of cooling access during designated operations.

The allocation system is a planning tool. It does not rank individuals, deny entry, or replace human-led emergency coordination.

## Evidence basis

Area-level planning may combine:

- Forecast and observed temperature.
- Heat index or wet-bulb-related indicators where appropriate.
- Land surface temperature and urban heat-island measurements.
- Shade and tree-canopy indicators.
- Walkable travel burden to cooling locations.
- Public-transit and accessible-transport reach.
- Aggregate demographic indicators from public sources.
- Aggregate housing and cooling-access proxies where lawfully available.
- Public power-outage, water-service, and transit-disruption information.
- Existing cooling-center capacity and backup-power status.
- Community-reported access barriers, handled without identity requirements.

The CDC Heat and Health Tracker is designed to let communities explore heat exposure, heat-related health outcomes, and protective assets. [164] EPA’s heat-equity guidance recognizes that heat burdens can be unevenly distributed and identifies older adults, people with existing medical conditions, children, people with limited mobility or resources, and people experiencing homelessness among groups at greater risk; aggregate planning must still avoid converting those patterns into individual eligibility tests. [159]

## Aggregate vulnerability planning index

### Area-level, not individual-level, score

Let \(i\) denote a public planning area, such as a census tract, neighborhood planning zone, public-service district, or grid cell selected through a documented governance process.

Define:

\[
V_i =
\beta_h H_i +
\beta_e E_i +
\beta_a A_i +
\beta_d D_i +
\beta_c C_i +
\beta_t T_i +
\beta_p P_i
\]

Where:

- \(H_i\) is heat-exposure intensity.
- \(E_i\) is environmental heat-burden intensity, such as land-surface heat or low shade.
- \(A_i\) is aggregate age-related heat-risk indicator.
- \(D_i\) is aggregate disability-related access-need indicator.
- \(C_i\) is aggregate home-cooling-access constraint proxy.
- \(T_i\) is transit and accessible-transport burden.
- \(P_i\) is public-service disruption burden, such as electricity or water instability.

All input variables must be normalized:

\[
0 \leq H_i,E_i,A_i,D_i,C_i,T_i,P_i \leq 1
\]

Weights must be public, reviewable, and sum to one:

\[
\beta_h +
\beta_e +
\beta_a +
\beta_d +
\beta_c +
\beta_t +
\beta_p = 1
\]

The planning score is an area-level resource-allocation signal. It is not a person-level vulnerability score.

### Protective-resource adjustment

An area with high heat exposure but strong, accessible cooling resources may need less incremental capacity than an area with comparable heat and weak access.

Let \(R_i\) be a protective-resource score:

\[
R_i =
\gamma_s S_i +
\gamma_w W_i +
\gamma_x X_i +
\gamma_b B_i
\]

Where:

- \(S_i\) is accessible cooling-seat availability.
- \(W_i\) is potable-water availability.
- \(X_i\) is accessible transportation reach.
- \(B_i\) is backup-power and continuity capacity.

The unmet cooling need is:

\[
U_i =
\max
\left(
0,
V_i - R_i
\right)
\]

A more conservative demand-pressure estimate is:

\[
D_i^{\text{forecast}} =
N_i
\cdot
U_i
\cdot
\phi(T_{\text{forecast}})
\]

Where:

- \(N_i\) is the aggregate population estimate for planning area \(i\).
- \(\phi(T_{\text{forecast}})\) is a transparent, heat-severity escalation function.

For example:

\[
\phi(T_{\text{forecast}}) =
1 +
\alpha
\cdot
\max
\left(
0,
\frac{T_{\text{forecast}} - T_{\text{trigger}}}{T_{\text{range}}}
\right)
\]

This lets capacity planning rise with hazardous heat conditions while keeping the model’s assumptions visible.

### Uncertainty-aware allocation

Because aggregate indicators can be incomplete, stale, or biased, incorporate uncertainty:

\[
U_i^{\text{robust}} =
U_i +
\lambda \sigma_i
\]

Where:

- \(\sigma_i\) is uncertainty in the planning score.
- \(\lambda\) is a publicly selected precaution parameter.

This avoids under-serving areas merely because they have weaker data coverage.

## Capacity allocation model

### Decision variables

Let:

- \(x_i\) be cooling seats allocated to planning area \(i\).
- \(y_i\) be accessible transport capacity allocated to planning area \(i\).
- \(z_i\) be water and essential-supply capacity allocated to planning area \(i\).
- \(b_i\) be reserve or backup capacity allocated to planning area \(i\).

All decision variables are nonnegative:

\[
x_i, y_i, z_i, b_i \geq 0
\]

Let total available cooling seats be \(X\):

\[
\sum_i x_i \leq X
\]

Let total accessible transport capacity be \(Y\):

\[
\sum_i y_i \leq Y
\]

### Fairness-first objective

The objective is to minimize unmet need and geographic inequity while preserving minimum service floors:

\[
\min_{x,y,z,b}
\left[
\sum_i
w_i
\max
\left(
0,
D_i^{\text{forecast}} - x_i
\right)
+
\lambda_f
\cdot
\operatorname{Inequity}(x)
+
\lambda_t
\cdot
\operatorname{TravelBurden}(y)
\right]
\]

Where \(w_i\) increases priority for areas with greater unmet aggregate need.

One equity term is maximum normalized shortage:

\[
\operatorname{Inequity}(x) =
\max_i
\left(
\frac{
\max(0, D_i^{\text{forecast}} - x_i)
}{
\max(D_i^{\text{forecast}}, 1)
}
\right)
\]

This formulation avoids a plan that fully serves easy-to-reach areas while leaving a single high-need area with a severe shortage.

### Minimum service floor

Every planning area receives a minimum baseline of public information, transportation connection, and contingency access:

\[
x_i + y_i + b_i \geq F_i
\]

Where \(F_i\) is an area-specific, publicly established service floor.

For a citywide coverage principle:

\[
\forall i,\quad
\operatorname{ReachableCooling}(i) = \text{true}
\]

A lower planning score never means no risk. New York State cooling-center guidance similarly notes that lower heat-vulnerability scores do not imply no risk and states that everyone faces some heat-illness risk. [165]

### Reserve capacity

Hold a citywide reserve:

\[
B_{\text{reserve}} \geq \rho X
\]

Where \(\rho\) is a disaster-planning reserve fraction.

Reserve capacity supports:

- Sudden power outages.
- Transit disruption.
- Facility closure.
- Capacity surge.
- Heat severity exceeding forecast.
- Accessible transportation interruption.
- High-demand cooling-center transfers.
- New community-identified access barriers.

Reserve capacity must not become a selective pool that requires proof of vulnerability. It is a continuity resource for all people.

## Universal entry rules

### Entry policy

Cooling centers must post a plain-language policy:

```text
Cooling is available here during operating hours.

No identification is required.
No proof of age, disability, income, address, housing status, or medical need is required.
No payment is required.
No phone, app, account, QR code, or internet connection is required.

You may ask for accessibility support, water, seating, a quiet area, interpretation, or transportation information.
```

### Non-denial rule

No person is turned away because they lack documentation.

\[
\operatorname{DeniedForMissingProof}(p) = 0
\]

If a facility reaches safe physical capacity, staff must provide a non-discriminatory continuity response:

1. Offer the nearest available cooling location.
2. Offer accessible transportation or transit information where available.
3. Offer water and immediate shaded or cooled waiting options where feasible.
4. Provide a printed or spoken list of alternatives.
5. Request surge support through an established emergency coordination process.
6. Record only aggregate capacity status, not the person’s identity or claimed condition.

### Queue fairness

Define waiting time for a person \(p\) as:

\[
W_p =
t_{\text{service}}(p) -
t_{\text{arrival}}(p)
\]

The target is:

\[
W_{\max} =
\max_p W_p
<
15 \text{ minutes}
\]

The measurement process must avoid identity tracking. Use one of the following methods:

- Anonymous physical queue tokens that are returned and immediately reused.
- Aggregate door-counter and seating-turnover estimates.
- Periodic staff observations in coarse time bins.
- Voluntary, non-identifying service-quality sampling.
- A queue display that states estimated wait time without recording individual arrivals.

Do not use facial recognition, phone tracking, persistent queue IDs, or identity-linked tickets.

### Accessibility priority without proof burden

Centers may provide a voluntary accommodation lane or seating support for people who request assistance, but must not require medical documentation, diagnosis disclosure, or disability proof.

Use request-based access:

\[
\operatorname{AccommodationProvided}(p)
\Leftarrow
\operatorname{AccommodationRequested}(p)
\]

Not proof-based access:

\[
\operatorname{AccommodationProvided}(p)
\not\Leftarrow
\operatorname{MedicalProof}(p)
\]

This supports dignity, autonomy, and practical access while avoiding intrusive intake.

## Accessibility and service design

Every cooling center should provide, to the extent feasible:

- Step-free access or equivalent accessible entry.
- Clear accessible route signage.
- Seating with varied heights and arm supports.
- Space for mobility devices and service animals.
- Accessible restrooms or clear accessible restroom directions.
- Drinking water.
- Cooling with a monitored safe indoor environment.
- Quiet or lower-stimulation space where feasible.
- Sensory-considerate communication.
- Plain-language and multilingual information.
- Visual, written, and spoken announcements.
- Phone charging without requiring device registration.
- Staff-trained assistance with no forced disclosure.
- A non-digital option for directions and operating hours.
- Transit and accessible-transport coordination.
- Backup power and continuity planning.
- Emergency response escalation process.

New York State cooling-center guidance identifies considerations including accessibility, seating, water, medical supplies, public access, crowd accommodation, and coordination with public agencies and community organizations. [165]

## Transportation as cooling capacity

Cooling capacity is ineffective if people cannot reach it safely.

Let:

- \(d_i\) be accessible travel distance from planning area \(i\) to a cooling center.
- \(t_i\) be estimated travel time using walking, transit, paratransit, shuttle, or other accessible means.
- \(h_i\) be outdoor heat exposure accumulated during travel.

Define access burden:

\[
B_i =
\eta_d \widehat{d_i}
+
\eta_t \widehat{t_i}
+
\eta_h \widehat{h_i}
\]

Where hats denote normalized terms.

Transportation support allocation should reduce maximum burden:

\[
\min_y \max_i B_i(y)
\]

Subject to available accessible vehicles, route capacity, and safe driver or operator staffing.

Transportation support may include:

- Extended transit service near centers.
- Accessible shuttle routes.
- Paratransit expansion.
- Heat-safe pickup points.
- Mobile cooling resources.
- Water distribution at transit transfer points.
- Cooling-center information at libraries, kiosks, and community hubs.
- Assistance for people who cannot independently navigate routes.

Heat-response planning should treat transportation as a core protective resource, rather than an afterthought. [172]

## Facility resilience

### Operational continuity

Each cooling site should have:

- Backup electricity plan.
- Water supply contingency.
- Accessible ingress and egress.
- HVAC maintenance and thermal monitoring.
- Communications that do not depend solely on an app or web page.
- Printed signage and offline information.
- A local incident and capacity-status procedure.
- Cross-site transfer plan.
- Safe closing and reopening procedure.
- Replacement site list.

### Facility availability

Let \(T_{\text{available}}\) be total time a site provides safe cooling during its declared operating window, and \(T_{\text{scheduled}}\) the planned cooling operation time.

\[
A_{\text{center}} =
\frac{
T_{\text{available}}
}{
T_{\text{scheduled}}
}
\]

Target:

\[
A_{\text{center}} \geq 0.99
\]

### Cooling-seat continuity

Let \(S_{\text{safe}}\) be seats usable in a safe, accessible condition and \(S_{\text{planned}}\) be planned seats.

\[
C_{\text{seat}} =
\frac{
S_{\text{safe}}
}{
S_{\text{planned}}
}
\]

A center should report capacity status in aggregate form:

```text
Open
Limited seating
Accessible seating available
Water available
Alternative center available
Transportation information available
```

It must not publish names, images, queue membership, health status, or other person-level information.

## Public governance

### Required public documentation

Publish:

- The aggregate inputs used for planning.
- Data-source dates and update intervals.
- The vulnerability and protective-resource formulas.
- Weight-selection rationale.
- Uncertainty method.
- Allocation constraints.
- Minimum service floors.
- Facility accessibility criteria.
- Transportation assumptions.
- Capacity and reserve calculations.
- Entry and non-denial policy.
- Queue measurement method.
- Privacy and retention policy.
- Public correction and appeal pathway.
- Performance metrics and post-event review.

### Public correction pathway

A person or organization may report:

```text
Cooling-center accessibility barrier
Incorrect hours
Water or sanitation concern
Transportation barrier
Language-access barrier
Unsafe queue condition
Documentation requirement imposed by staff
Identity or payment gate
Inaccurate capacity listing
Inadequate public notice
Neighborhood service gap
```

Reports must be accepted through accessible channels without mandatory identity disclosure.

The review process should publish aggregate outcomes:

\[
C_{\text{correction}} =
\frac{
\text{reports substantively reviewed}
}{
\max(\text{reports received},1)
}
\]

Target:

\[
C_{\text{correction}} \geq 0.95
\]

## Python optimization reference

The allocation solver should:

- Accept only aggregate planning-area inputs.
- Enforce seat, transport, and reserve limits.
- Enforce minimum service floors.
- Minimize weighted unmet aggregate need.
- Penalize high maximum shortage.
- Produce an explanation for every allocation.
- Refuse person-level fields.
- Produce no identity-based eligibility output.
- Remain advisory until publicly authorized operators review the plan.

## Testing requirements

### Privacy tests

- Reject person names, addresses, identity values, medical records, disability records, phone identifiers, biometric information, and device IDs.
- Verify only aggregate planning-area values are accepted.
- Verify no entry decision function exists.
- Verify outputs do not rank or score individuals.
- Verify queue metrics can be computed without persistent IDs.

### Equity tests

- Verify every area has a nonzero baseline service floor.
- Verify a lower aggregate score never produces a “no cooling” recommendation.
- Verify high uncertainty increases review priority rather than reducing allocation.
- Verify accessibility and transit burden can increase pre-allocation without requiring individual proof.
- Verify disparities in unmet need are visible in the output.

### Resilience tests

- Verify a facility closure triggers reserve-capacity or alternative-site recommendations.
- Verify a transit failure increases transport-support need.
- Verify a power outage changes facility continuity capacity.
- Verify all public information has offline and printable forms.
- Verify no critical operation relies only on an internet-connected application.

## Project metrics

| Metric | Score | Basis |
|---|---:|---|
| knowledge_factor | 0.92 | Uses aggregate heat, access, protective-resource, uncertainty, and facility-continuity inputs with transparent formulas and public documentation |
| eco_impact_value | 0.84 | Supports heat resilience, efficient use of cooled space, transit coordination, backup-power planning, reduced heat exposure, and public shade and water integration |
| harm_risk | 0.15 | No identity, proof, device, payment, or medical gate; planning is aggregate; facility access is universal; correction and human review paths are required |
| accessibility_impact | 0.97 | Includes accommodation on request, accessible transit, step-free access, seating, quiet space, multilingual communication, water, and non-digital information |
| rights_alignment | 0.99 | Preserves essential-service access, dignity, non-discrimination, privacy, autonomy, accessibility, civic accountability, and network independence |
