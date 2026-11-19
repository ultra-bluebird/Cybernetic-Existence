# Private Municipal Wi-Fi and Urban Farming Data Cooperative

## Purpose

This specification defines:

1. Free municipal Wi-Fi that minimizes collection of MAC addresses, browsing history, account information, device identifiers, and user-level traffic records while reserving capacity for essential public-service access.
2. An urban-farming data cooperative that shares aggregated yield, soil, and microclimate evidence for local food resilience without exposing individual gardens, growers, addresses, practices, or financial circumstances.

These systems must not create participant rankings, behavioral profiles, financial scores, eligibility scores, reputation scores, CyberRank tiers, targeted advertising records, or identity-linked service restrictions.

## Shared Rights Baseline

The systems SHALL:

- Require no account, government identity, personal device registration, biometric identifier, health disclosure, augmentation disclosure, or self-described cybernetic-host disclosure for baseline public access.
- Minimize metadata collection, retention, and sharing.
- Preserve public and essential-service access during congestion, outages, and local equipment failures.
- Provide accessible notices, public documentation, correction channels, human support, and non-digital alternatives where an outcome is consequential.
- Use aggregate metrics for public accountability.
- Apply small-cell suppression, coarsening, delayed release, and complementary suppression before publishing cooperative metrics.
- Separate technical abuse prevention from identity, health, wealth, appearance, disability, device ownership, augmentation, or participation frequency.
- Support repairable equipment, signed updates, local diagnostics, and transparent maintenance processes.

## Part One: Municipal Wi-Fi Without Tracking

### Service Model

The municipal service provides open or low-friction public connectivity for:

- Essential public-service portals.
- Public-health, emergency, cooling, water, sanitation, housing, transit, and accessibility information.
- Public-library, educational, civic-participation, and correction or appeal workflows.
- General public internet access within transparent capacity limits.

Essential-service portal access must remain available through public terminals, telephone or relay services, print resources, staff support, and other non-Wi-Fi channels. Wi-Fi is an additional access path, not the sole method for obtaining essential assistance.

### Data-Prohibition Rules

The network SHALL NOT retain:

- Client MAC addresses.
- Wi-Fi probe-request identifiers.
- Browsing history.
- DNS query history attributable to a device or person.
- Full URLs, page content, search terms, application content, or packet payloads.
- Persistent IP-to-person mapping.
- Advertising identifiers.
- Browser fingerprints.
- Device model, operating-system profile, or persistent radio fingerprint.
- Geolocation history.
- Identity, health, disability, augmentation, cybernetic-host, or assistive-technology information.

The network may retain only short-lived operational counters that cannot reasonably be linked to a person or device, such as:

- Aggregate radio utilization by access point.
- Aggregate queue depth by traffic class.
- Aggregate packet loss, retransmission rate, and airtime use.
- Aggregate gateway health and backhaul capacity.
- Aggregate essential-service class availability.
- Equipment fault, firmware, and maintenance state.

MAC address randomization reduces persistent linkability, but it is not complete traffic-analysis protection because link-layer addresses remain observable during an active association session. RFC 9797 specifically notes that source and destination MAC addresses are not encrypted even where Wi-Fi encryption is used, and that randomization generally requires a disconnect/reconnect cycle. [199] The municipal network must therefore avoid server-side retention of MAC identifiers and must minimize metadata independently of client-side MAC randomization.

### Encryption and Traffic-Analysis Limits

Use a layered protection approach:

| Layer | Required control | Privacy contribution |
|---|---|---|
| Wireless link | WPA3-Enhanced Open where hardware supports it, with WPA2 fallback only when necessary for compatibility | Encrypts local radio traffic without requiring a person-level account |
| DNS | Encrypted DNS resolver using DoH or DoT, with privacy-reviewed resolver policy | Reduces local visibility into DNS traffic |
| Essential portals | HTTPS with modern TLS configuration and HSTS | Protects page content and authenticated session data |
| Public-information mirror | Local cache of approved public-service information | Keeps essential information available under backhaul congestion or outage |
| Network logs | Aggregate-only telemetry with short retention | Avoids creation of user browsing and movement histories |
| Routing | No traffic mirroring, no content inspection, no ad-tech integration | Reduces metadata and content exposure |
| Administration | Separate privileged management network with phishing-resistant authentication | Protects network infrastructure without identifying public users |

CISA recommends encrypted DNS as a cybersecurity and privacy control, and recommends WPA3-capable equipment where possible because WPA3 is the strongest listed Wi-Fi link encryption option. [191][193]

Encryption does not eliminate traffic analysis. Packet sizes, timing, destination network information, radio association state, and physical proximity can still reveal patterns. The network therefore must also:

- Avoid captive portals that require personal details.
- Avoid behavioral analytics and audience measurement.
- Avoid third-party advertising, analytics, and tracking scripts on municipal portal pages.
- Avoid retaining DHCP leases or translation records beyond the shortest technically necessary operational interval.
- Aggregate and rotate operational counters.
- Apply rate limits and abuse controls to traffic flows rather than maintaining identity histories.
- Separate operational security incidents from routine public-use telemetry.
- Publish a clear notice describing what is not collected and what limited aggregate operations data exists.

### QoS Without Per-User Identification

Quality of service is applied by **destination class and traffic class**, not by user identity.

Let:

- \(B\) be total usable backhaul bandwidth.
- \(B_E\) be bandwidth reserved for essential-service destination classes.
- \(B_G\) be bandwidth allocated to general public traffic.
- \(n\) be the number of active anonymous connections.
- \(b_{\min}\) be the minimum connection service objective.

\[
B = B_E + B_G
\]

\[
b_{\min} = 1\ \mathrm{Mbps}
\]

The target is:

\[
\frac{B_G}{n} \geq 1\ \mathrm{Mbps}
\]

when physical capacity permits.

If general capacity cannot support that target, the system shall apply fair queueing and temporary per-flow shaping without retaining a stable identifier. It must preserve the essential-service reservation and publish a congestion notice.

For essential-service traffic:

\[
B_E =
\max
\left(
B_{\mathrm{essential\ floor}},
\alpha B
\right)
\]

where \(\alpha\) is a publicly documented capacity fraction selected through service-demand and resilience review.

Essential-service classification should use a signed, transparent, narrow destination allowlist of official public portals and community-service endpoints. It must not inspect content, infer a user's reason for visiting a service, or record which user accessed which portal.

Permitted traffic classes:

```text
ESSENTIAL_PUBLIC_SERVICE
EMERGENCY_AND_PUBLIC_SAFETY_INFORMATION
ACCESSIBLE_PUBLIC_INFORMATION
GENERAL_INTERACTIVE
BEST_EFFORT_BULK
NETWORK_MANAGEMENT
```

Prohibited traffic classes:

```text
USER_REPUTATION_HIGH
PAYING_USER
DEVICE_TYPE_PRIORITY
FREQUENT_USER
IDENTITY_PRIORITY
AUGMENTATION_PRIORITY
HEALTH_STATUS_PRIORITY
PROPERTY_VALUE_PRIORITY
```

### Congestion Behavior

During congestion:

1. Preserve network-management capacity needed for safety and repair.
2. Preserve the essential public-service traffic floor.
3. Preserve accessible public-information traffic.
4. Apply fair, anonymous per-flow shaping to best-effort and bulk traffic.
5. Display a plain-language public status message.
6. Ensure kiosks, printed information, phone, relay, and staff-assisted options remain available for essential services.
7. Do not degrade access based on identity, device type, health, disability, augmentation, account status, payment ability, or user history.

### Public Accountability Metrics

Permitted public Wi-Fi metrics:

```json
{
  "event_type": "municipal_wifi_aggregate_status",
  "time_window": "hourly",
  "access_point_zone": "public_connectivity_zone",
  "aggregate_connected_sessions_bucket": "50_to_99",
  "essential_service_capacity_available": true,
  "general_service_minimum_target_mbps": 1.0,
  "aggregate_packet_loss_percent": 0.0,
  "aggregate_backhaul_utilization_percent": 0.0,
  "mac_addresses_retained": false,
  "browsing_history_retained": false,
  "dns_history_retained": false,
  "identity_data_retained": false,
  "retention_class": "short_aggregate_operations"
}
```

## Part Two: Urban Farming Data Cooperative

### Cooperative Purpose

The cooperative enables gardens, farms, schools, community hubs, and food-security organizations to contribute or use aggregated regional evidence about:

- Crop yield.
- Planting and harvest windows.
- Soil moisture, temperature, pH, and nutrient measurements.
- Microclimate conditions.
- Water use in aggregate.
- Compost and soil-amendment outcomes.
- Pest and disease observations at safe aggregation levels.
- Seed availability and crop-diversity indicators.
- Community food-distribution capacity.

Urban agriculture includes cultivation, processing, and distribution of agricultural products in urban and suburban areas, and federal programs recognize community farms, gardens, rooftop, indoor, and vertical growing operations as part of this landscape. [192][194]

The cooperative serves local food resilience, ecological learning, and community planning. It is not a surveillance platform, a property-value tool, an insurer dataset, a worker-performance system, or an investor-ranking system.

### Privacy-Preserving Aggregation

Raw garden records remain under contributor control. The cooperative receives or publishes only coarsened, aggregated, or differentially private summaries.

Let:

- \(y_i\) be a contributor's observed yield.
- \(A_i\) be cultivated area.
- \(z(i)\) be the contributor's coarse regional zone.
- \(t\) be a time window.
- \(G_{z,t}\) be the set of contributors in zone \(z\) and period \(t\).

The regional yield density is:

\[
Y_{z,t} =
\frac{
\sum_{i \in G_{z,t}} y_i
}{
\sum_{i \in G_{z,t}} A_i
}
\]

Release is permitted only when:

\[
|G_{z,t}| \geq k
\]

where \(k\) is the community-governed minimum contributor count.

Before publication, the cooperative must apply:

- Coarse zone mapping rather than exact garden coordinates.
- Minimum contributor thresholds.
- Complementary suppression for tables that could reveal a suppressed cell through subtraction.
- Time aggregation that avoids revealing an individual harvest or planting event.
- Crop-category grouping when rare crops or specialized practices create uniqueness risk.
- Delayed release where current-season data could reveal a particular participant.
- Optional differential privacy for public metrics.
- Review for linkage risk with public parcel, address, tax, satellite, social-media, or business-directory data.

The system shall not publish or share:

- Exact garden coordinates.
- Parcel identifiers, ownership records, rent, income, property value, insurance data, or tenant status.
- Contributor names, contact information, account identifiers, device identifiers, or participation frequency.
- Individual soil practices, water use, labor practices, harvest calendars, security measures, or market arrangements.
- Individual crop yields or revenue.
- Individual health, disability, identity, cybernetic-host, or augmentation-related information.

### Differential Privacy for Public Summaries

For a bounded aggregate query \(q(D)\), release:

\[
\tilde{q}(D) =
q(D) + \eta
\]

where \(\eta\) is calibrated random noise appropriate to the selected differential privacy mechanism and documented sensitivity bound.

The release budget must satisfy:

\[
\epsilon_q \leq 0.1
\]

and cumulative release accounting must satisfy:

\[
\epsilon_{\mathrm{total}} =
\sum_{q=1}^{m}
\epsilon_q
\leq
\epsilon_{\mathrm{cap}}
\]

The privacy cap applies to the dataset, region, release window, and declared public purpose. It must not become a reputation score or behavioral profile for individual growers.

### Cooperative Governance

The cooperative is governed through one-member, one-voice rules or another transparent community-approved equal-participation model.

Required governance roles:

| Role | Responsibility | Personal ranking permitted |
|---|---|---|
| Contributor | Controls whether and what aggregate evidence is contributed | No |
| Data steward | Applies minimization, aggregation, release, and deletion rules | No |
| Community review group | Reviews community benefit, privacy, ecological impact, and access | No |
| Technical maintainer | Maintains software, data validation, and reproducible releases | No |
| Food-security partner | Uses aggregates to coordinate support and planning | No |

The cooperative shall publish:

- Data classes accepted.
- Aggregation and suppression rules.
- Privacy budget and release schedule.
- Data-use restrictions.
- Retention and deletion rules.
- Community-benefit allocation rules.
- Conflict-resolution and correction process.
- Security and incident-response process.
- Source provenance and uncertainty documentation.
- A list of prohibited downstream uses.

### Benefit Sharing Without Ranking

Participation incentives must be reciprocal, not competitive.

Permitted benefit structures:

- Shared access to regional planting calendars and climate summaries.
- Shared seed libraries, compost programs, soil-test days, and tool-lending.
- Cooperative procurement for water-saving equipment, mulch, shade materials, and repairable sensors.
- Skills exchange, training, and peer support.
- Equal access to contributed public knowledge resources.
- Community-governed grants or in-kind support based on documented project needs, not personal popularity or yield ranking.
- Recognition of collective milestones without contributor leaderboards.
- Opt-in attribution for people or groups who wish to be publicly credited.

Prohibited benefit structures:

- Yield leaderboards.
- Participation streaks that determine access or voice.
- Individual financial scores.
- Crop-efficiency ranking of people, gardens, or neighborhoods.
- Property-value rewards.
- Priority based on account age, wealth, device ownership, land ownership, or data volume.
- Token holdings that increase governance power.
- Tradeable tokens derived from contributor data.

### Crop-Rotation Planning

Regional planning should recommend crop rotations as optional decision support, not dictate private garden practices.

Let:

- \(x_{c,p}\) be the cultivated area assigned to crop group \(c\) in planning period \(p\).
- \(Y_c\) be expected regional yield density for crop group \(c\).
- \(W_c\) be water requirement per unit area.
- \(N_c\) be nutrient demand or soil-restoration coefficient.
- \(A_p\) be available aggregate cultivated area in period \(p\).
- \(W_p^{\max}\) be the aggregate water budget.
- \(D_c\) be the community food-security demand target.

A simplified regional optimization objective is:

\[
\max
\sum_{c,p}
Y_c x_{c,p}
\]

subject to:

\[
\sum_c x_{c,p} \leq A_p
\]

\[
\sum_c W_c x_{c,p}
\leq
W_p^{\max}
\]

\[
\sum_p Y_c x_{c,p}
\geq
D_c
\]

\[
x_{c,p} \geq 0
\]

Rotation and soil-restoration constraints may be added:

\[
x_{c,p} + x_{c,p+1}
\leq
A_p
\]

for crop groups that should not occupy the same aggregate bed allocation in consecutive periods.

This produces regional scenario options. It must not reveal an individual garden's crop plan, prescribe a participant's practices, or be used to allocate land, water, funding, or public recognition through a personal score.

## Security and Retention

### Municipal Wi-Fi

- Maintain network equipment with signed firmware and documented rollback procedures.
- Separate public traffic from management and maintenance networks.
- Use encrypted administration channels and phishing-resistant authentication for infrastructure administrators.
- Retain only aggregate equipment-health and capacity data for the shortest defined operational period.
- Prohibit behavioral analytics, advertising technology, captive-portal tracking, and sale or sharing of public-use metadata.
- Publish a plain-language privacy notice and a public contact route for correction or concern reporting.

### Urban Farming Cooperative

- Encrypt data in transit and at rest.
- Store raw contributor submissions separately from released aggregates.
- Require explicit consent before each new data class, public release category, or downstream sharing arrangement.
- Allow contributors to withdraw future contributions and request deletion of locally attributable records where technically and legally feasible.
- Maintain a public aggregate release ledger without contributor identity.
- Use versioned transformation code, data dictionaries, release manifests, and synthetic fixtures for reproducible review.
- Retain raw contributions only for the minimum period necessary to generate approved aggregate outputs.
- Delete expired raw records and rotate any internal pseudonyms on the documented schedule.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.90 | Privacy-preserving networking, traffic-class QoS, encrypted DNS, aggregate data governance, cooperative food-system planning, and linear optimization |
| eco_impact_value | 0.88 | Supports efficient community food production, water-aware planting, local resilience, repairable connectivity, and reduced duplicated data infrastructure |
| harm_risk | 0.33 | Residual risks include network metadata leakage, abuse of traffic-class allowlists, garden-location inference, and unequal cooperative participation; minimization, aggregation, review, and non-ranking rules reduce exposure |
| accessibility_impact | 0.97 | Provides account-free connectivity, essential-service prioritization, accessible public alternatives, and equal cooperative access without device or financial barriers |
| rights_alignment | 0.99 | Enforces privacy, non-discrimination, no tracking, no social or financial scoring, consent, repairability, community governance, and public-benefit access |
