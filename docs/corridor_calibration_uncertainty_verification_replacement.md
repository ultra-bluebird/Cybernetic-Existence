# Corridor Calibration: Uncertainty, Verification, Replacement, and Purpose

## Scope

This specification extends local-only corridor calibration with:

1. Declared error propagation.
2. Explicit sensor-unavailability state.
3. Bounded local verification.
4. Append-only sensor replacement.
5. Closed declared-purpose vocabulary.

The model does not create:

- A corridor quality score.
- A sensor trust score.
- A sensor rank.
- A sensor priority order.
- A sensor eligibility class.
- A fault diagnosis.
- A damage diagnosis.
- A maintenance obligation.
- An external certification.
- A personal-context record.
- An authority, funding, procurement, or institutional-status claim.

## Core Separation

The following concepts remain separate:

\[
\text{uncertainty}
\neq
\text{score}
\]

\[
\text{unavailability}
\neq
\text{fault}
\]

\[
\text{local verification}
\neq
\text{external certification}
\]

\[
\text{replacement}
\neq
\text{history rewrite}
\]

\[
\text{declared purpose}
\neq
\text{priority or eligibility}
\]

## Error Propagation

### Individual uncertainty

Every locally declared sensor reading carries its own uncertainty boundary:

\[
u_i \geq 0
\]

where \(u_i\) is the declared uncertainty bound for sensor record \(i\).

The uncertainty remains tied to that sensor-record context:

\[
U_i =
(
\text{sensor record digest},
\text{metric},
\text{unit},
u_i,
\text{reference relation},
\text{time alignment state}
)
\]

The model must not replace individual uncertainty declarations with a hidden corridor score.

### Edge-level propagation

For a declared topology edge \(e_{ij}\) connecting sensor records \(i\) and \(j\), the local difference uncertainty is:

\[
u_{ij} =
\sqrt{u_i^2 + u_j^2}
\]

This formula applies only to the declared pairwise comparison context. It does not establish that readings are independent, physically representative, or externally validated.

If a declared geometry relation introduces an additional bounded geometry uncertainty \(u_{g,ij}\), the edge-level context may record:

\[
u_{ij,g} =
\sqrt{u_i^2 + u_j^2 + u_{g,ij}^2}
\]

The geometry contribution is optional and must be explicit. It must never be inferred from topology alone.

### Corridor-level uncertainty vector

The corridor does not receive a total uncertainty score. It receives a declared uncertainty vector:

\[
U_{\text{corridor}} =
\{
U_i,
U_{ij},
U_{ij,g}
\}
\]

A local summary may identify the maximum declared bound without converting it into a score:

\[
u_{\max} =
\max
(
\{u_i\}
\cup
\{u_{ij}\}
\cup
\{u_{ij,g}\}
)
\]

The permitted summary is:

```text
maximum_declared_uncertainty_bound
```

The following are prohibited:

\[
\sum_i u_i
\]

\[
\frac{1}{n}\sum_i u_i
\]

\[
\text{corridor quality score}
\]

\[
\text{sensor reliability rank}
\]

\[
\text{priority}(i)
\]

A corridor uncertainty record must preserve all source uncertainty references. It must not collapse individual uncertainty declarations into a hidden total.

### Missing or unavailable sources

If a sensor is unavailable, its uncertainty is not estimated, imputed, replaced, or silently omitted from a pairwise edge that requires it.

For edge \(e_{ij}\):

\[
\operatorname{available}(i) = \text{false}
\lor
\operatorname{available}(j) = \text{false}
\Longrightarrow
u_{ij} = \text{not established}
\]

The remaining edges and sensor records retain their own independent uncertainty declarations.

## Sensor Unavailability

A sensor is unavailable only when a record explicitly declares that its local bytes could not be read or could not be locally resolved.

The state is:

```text
sensor_bytes_unavailable_locally
```

It does not imply:

```text
sensor_faulty
sensor_damaged
sensor_offline
sensor_removed
sensor_untrusted
sensor_low_priority
```

The unavailability record has the form:

\[
A_s =
(
\text{sensor artifact digest},
\text{sensor node label},
\text{availability state},
\text{local read attempt state},
\text{declared timestamp},
\text{non-claims},
\text{record hash}
)
\]

Permitted availability states:

```text
sensor_bytes_available_locally
sensor_bytes_unavailable_locally
sensor_bytes_verification_failed
sensor_state_not_declared
```

The corridor calibration is not globally downgraded because one sensor is unavailable:

\[
\operatorname{Unavailable}(s_i)
\not\Rightarrow
\forall j \neq i:
\operatorname{Invalid}(s_j)
\]

Instead:

- Calibration records for other sensors remain independently reviewable.
- Edges requiring the unavailable sensor become `not_established`.
- Corridor summaries must identify unavailable dependencies explicitly.
- No imputation is allowed without a separately declared, materially reviewed model.

## Local Verification

Local verification is a bounded operation over locally supplied artifacts.

\[
V =
f(
\text{schema},
\text{canonicalization},
\text{record SHA-256},
\text{predecessor link},
\text{reference binding},
\text{drift arithmetic},
\text{time tolerance},
\text{topology binding},
\text{availability state},
\text{currentness}
)
\]

It does not require:

- Network access.
- External calibration service.
- Cloud fusion.
- Institutional review.
- Identity verification.
- Remote sensor access.
- External authority.

The closed verification outcomes are:

```text
locally_verified
not_established
needs_local_review
quarantined_not_authoritative
```

### Derivation

A record is `locally_verified` only when all required dimensions pass:

\[
V_{\text{local}} =
F
\land
C
\land
H
\land
P
\land
R
\land
D
\land
T
\land
G
\land
A
\land
W
\]

where:

- \(F\): field-complete under the declared schema;
- \(C\): canonical encoding is valid;
- \(H\): record SHA-256 matches canonical bytes;
- \(P\): predecessor or genesis relation is valid;
- \(R\): declared local reference binding is valid;
- \(D\): drift declaration is internally consistent;
- \(T\): time alignment is within declared tolerance;
- \(G\): topology and any required geometry binding are valid;
- \(A\): required local artifact bytes are available;
- \(W\): currentness is `current`.

Any missing local artifact, unavailable required sensor bytes, unavailable reference bytes, unknown state, unknown schema, unknown rule, or unlisted condition defaults to:

```text
not_established
```

`needs_local_review` is used when the record is structurally preserved but requires a human local decision, including:

- Time outside tolerance.
- Reference replacement pending review.
- Sensor replacement awaiting relationship review.
- A declared uncertainty edge whose input is unavailable.
- A purpose mismatch.
- A topology or geometry context that is valid but not applicable to the declared purpose.

`quarantined_not_authoritative` is used when local integrity evidence indicates a record mismatch, chain break, invalid digest, or conflicting replacement relation.

Verification is not a score:

\[
V
\not\Rightarrow
[0,1]
\]

## Sensor Replacement

Replacement is an append-only relationship between two distinct local sensor artifacts.

\[
R_{\text{replace}} =
(
\text{prior sensor artifact digest},
\text{prior calibration record digest},
\text{replacement sensor artifact digest},
\text{replacement node label},
\text{replacement relation},
\text{effective local timestamp},
\text{role},
\text{non-claims},
\text{record hash}
)
\]

Permitted replacement relations:

```text
sensor_replaced_same_topology_role
sensor_replaced_topology_role_revised
sensor_replacement_pending_local_review
sensor_replacement_context_not_established
```

The prior sensor history remains immutable:

\[
\operatorname{History}(s_{\text{prior}})
\text{ remains readable}
\]

The replacement sensor begins its own calibration history:

\[
\operatorname{History}(s_{\text{replacement}})
\neq
\operatorname{History}(s_{\text{prior}})
\]

The replacement record may point to prior history but must not rewrite prior calibration records to name the replacement sensor.

Required non-claims:

```text
replacement_is_not_retroactive_presence
replacement_is_not_prior_sensor_fault_claim
replacement_is_not_prior_sensor_damage_claim
replacement_is_not_sensor_rank_change
replacement_is_not_sensor_priority_change
replacement_is_not_authority_or_procurement_claim
```

## Declared Purpose

Purpose is a closed operational context. It is not a personal narrative, an identity statement, a funding request, a priority signal, or a sensor eligibility criterion.

The declared purpose form is:

\[
P =
(
\text{purpose code},
\text{scope boundary},
\text{purpose non-claims}
)
\]

Permitted purpose codes:

```text
heat_island_monitoring
air_quality_context_monitoring
traffic_flow_context_monitoring
stormwater_context_monitoring
urban_habitat_context_monitoring
maintenance_condition_monitoring
local_environmental_reference_comparison
sensor_integrity_review
```

The field must not contain:

- A person’s name.
- A community name.
- A city name.
- A home, workplace, school, or route reference.
- A health, medical, neural, biometric, or companion-system detail.
- An institutional program name.
- A funding request.
- A priority label.
- An eligibility label.
- A free-text narrative.

The required non-claims are:

```text
purpose_is_not_personal_context
purpose_is_not_eligibility_criterion
purpose_is_not_priority_signal
purpose_is_not_sensor_rank
purpose_is_not_funding_request
purpose_is_not_authority_claim
```

Purpose affects only the local applicability boundary:

\[
\operatorname{ValidForPurpose}(R,p)
\]

It does not determine whether a sensor has greater worth, priority, trust, or eligibility than another sensor.
