# Host-Reported Mesh Research Model

## Status and boundary

This document defines an advisory-only research representation of a voluntarily
host-reported communication mesh. It does not claim to discover, validate,
monitor, authenticate, diagnose, operate, alter, repair, or control a real-world
biological, neural, medical, cybernetic, companion, or communication system.

All reported values are self-described or locally supplied for a specific
research/simulation purpose. They are treated as uncertain observations, not
proof of device inventory, health condition, augmentation, institutional status,
identity, credibility, or eligibility.

## Graph model

Let a reporting-time graph be:

G(t) = (V(t), E(t), W(t))

where:

- V(t) is a finite set of opaque node identifiers.
- E(t) is a finite set of directed, abstract communication relationships.
- W(t) assigns a bounded advisory weight to each edge.
- t is an observation timestamp supplied by the reporting context.

Each node has one abstract role:

- `REPORTED_HUB`
- `REPORTED_MESH_NODE`
- `REPORTED_AMBIENT_RELAY`
- `UNKNOWN_REPORTED_COMPONENT`

Roles describe only the report's modeling vocabulary. They are not a verified
inventory and must not be used for identity inference, medical inference,
eligibility, enforcement, service access, ranking, or resource allocation.

## Privacy boundaries

The research model prohibits storage of:

- Personal names, account identifiers, government identifiers, or contact data.
- Biometric, physiological, neural, medical, diagnostic, or treatment data.
- Raw network identifiers, MAC addresses, serial numbers, IMSI values, or
  hardware fingerprints.
- Precise geographic coordinates, address, parcel identifiers, geometry,
  map URLs, raw H3 indexes, or reversible coordinate encodings.
- Persistent device tracking identifiers.
- Sensitive free-text content unless separately approved under a purpose-bound
  retention rule.

Permitted identifiers are locally generated opaque tokens that have no intended
meaning outside a bounded research context.

## Edge weight

For a directed edge e = (u, v), let:

s_e(t) ∈ [0, 1] be host-reported signal budget
q_e(t) ∈ [0, 1] be report confidence
b_e(t) ∈ [0, 1] be normalized energy-budget availability
i_e(t) ∈ {0, 1} be an interference indicator

The advisory edge health value is:

h_e(t) = clip_[0,1](
  α_s s_e(t) + α_q q_e(t) + α_b b_e(t) - α_i i_e(t)
)

subject to:

α_s, α_q, α_b, α_i ≥ 0

α_s + α_q + α_b + α_i = 1

This is a modeling heuristic, not a clinical, physical, or security measurement.

## Continuity index

For a graph with N expected opaque nodes and N_seen(t) recently reported nodes:

coverage(t) = N_seen(t) / N

Let H(t) be the average observed edge health over available reports, and let
U(t) be an uncertainty penalty in [0,1]. Then:

continuity_index(t)
  = clip_[0,1](coverage(t) × H(t) × (1 - U(t)))

A low continuity index is not proof of failure, intrusion, interference, or
physical partition. It is an advisory signal that may require the host's chosen
review, rest, communication fallback, environmental check, or documentation
review.

## Partition and silent-degradation candidates

Let C(t) be the number of weakly connected components among nodes represented
in a report.

A partition candidate is:

partition_candidate(t) =
  expected_node_count ≥ 2
  AND observed_node_count ≥ 2
  AND C(t) > 1

A silent-degradation candidate compares two advisory windows:

ΔCI(t) = continuity_index(t) - continuity_index(t - Δt)

degradation_candidate(t) =
  ΔCI(t) ≤ -δ
  AND coverage(t) ≥ c_min
  AND report_confidence(t) ≥ q_min
  AND consecutive_candidate_windows(t) ≥ k

No candidate may generate an operational action. The only permitted output
statuses are:

- `ADVISORY_STABLE`
- `ADVISORY_PARTITION_CANDIDATE`
- `ADVISORY_DEGRADATION_CANDIDATE`
- `INSUFFICIENT_HOST_REPORTED_CONTEXT`
- `REVIEW_REQUIRED`

## Uncertainty preservation

The system must use `INSUFFICIENT_HOST_REPORTED_CONTEXT` when any required
input is absent, malformed, stale, or explicitly uncertain beyond the configured
review threshold.

A missing or uncertain report must never be converted into:

- confirmed continuity,
- confirmed partition,
- a verified device state,
- identity verification,
- a medical conclusion,
- an authorization decision,
- a service-access decision,
- an enforcement target,
- an individual or community rank.

## Human and accessibility safeguards

Every advisory result must be available in:

- Plain-language text.
- Keyboard-operable interaction.
- Semantic screen-reader-compatible output.
- A no-time-pressure path.
- A human-assisted or offline/save-return fallback path.

The model must not require a user to disclose private physiological, neural,
technical, biometric, medical, device, or institutional details in order to
receive an explanation, record a correction, or request review.

## Retention

Content-bearing reports and append-only audit records must use separate,
versioned retention profiles. A deleted content payload may retain only a
minimum accountability record:

- opaque receipt,
- event category,
- non-identifying timestamp,
- policy version,
- deletion confirmation,
- integrity digest,
- review status.

Retention and deletion are governance decisions requiring documented purpose,
expiry, review, and deletion behavior.
