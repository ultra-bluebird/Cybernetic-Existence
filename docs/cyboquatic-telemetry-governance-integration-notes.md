# Cyboquatic Telemetry Governance and Integration Notes

## Purpose

This document operationalizes the Governed Impact Shard, cross-layer policy synchronization, and three-plane autonomy architecture for Cyboquatic Telemetry.

It connects validated environmental measurements to accountable planning evidence without allowing automated ecological metrics, optional accessibility preferences, identity claims, augmentation information, biometric information, or private learning-continuity information to determine eligibility, credibility, service access, or personal rank.

## Governed Impact Shard

A Governed Impact Shard is an immutable, versioned policy-aware record that references validated environmental evidence and expresses a bounded, reviewable ecological impact claim.

A shard may inform planning, maintenance prioritization, restoration analysis, and bounded operational review. It does not independently authorize an external action.

### Required fields

| Field | Type | Purpose |
|---|---|---|
| `shard_id` | UUID or content-addressed string | Unique impact shard identifier |
| `schema_version` | Semantic version | Version of the shard contract |
| `issued_at_utc` | ISO 8601 UTC | Time the shard was generated |
| `environmental_asset_id` | String | Identifier for the monitored environmental asset |
| `telemetry_artifact_ids` | Array[String] | Source Telemetry Envelope identifiers |
| `validation_result_ids` | Array[String] | Validation Kernel output identifiers |
| `evidence_hashes` | Array[String] | Integrity identifiers for source evidence |
| `intended_use` | String | Bounded decision-support purpose |
| `non_goals` | Array[String] | Explicit prohibited uses |
| `impact_metric_name` | String | Name of assessed ecological metric |
| `impact_metric_value` | Number | Calculated ecological result |
| `impact_metric_unit` | String | Unit associated with the impact metric |
| `impact_uncertainty` | Number | Non-negative uncertainty value |
| `knowledge_factor` | Number | Evidence confidence from 0 to 1 |
| `eco_impact_value` | Number | Evidenced ecological benefit from 0 to 1 |
| `harm_risk` | Number | Anticipated harm risk from 0 to 1 |
| `accessibility_impact` | Number | Accessible-use impact from 0 to 1 |
| `rights_alignment` | Number | Rights-centered alignment from 0 to 1 |
| `limitations` | String | Known data, model, coverage, or uncertainty limits |
| `plain_language_explanation` | String | Accessible explanation of the claim |
| `human_review_status` | Enum | Current stage of accountable review |
| `accessibility_review_status` | Enum | Accessibility review state |
| `community_review_status` | Enum | Community review state when applicable |
| `appeal_or_correction_path` | URI | Accessible recourse route |
| `external_action_status` | Enum | Whether a separate action authorization exists |
| `policy_shard_id` | String | Governing ALN policy reference |
| `provenance_hash` | String | Content-integrity reference |

### Impact-shard states

| State | Meaning | Permitted effect |
|---|---|---|
| `candidate_for_review` | Evidence is assembled and awaits applicable review | Information only |
| `hold_for_review` | Uncertainty, evidence coverage, or policy conditions require attention | No planning or external action |
| `qualified` | Review confirms a bounded use with stated limitations | Planning analysis only |
| `approved_for_planning` | Required reviewers approve use as planning evidence | Planning and prioritization support |
| `superseded` | A newer evidence object replaces this shard | Historical audit only |
| `appealed` | A correction or challenge is active | No new dependent action until resolution |

### External-action invariant

A Governed Impact Shard is not an action command.

Any repair dispatch, field intervention, public notification, funding allocation, equipment actuation, or service change requires a distinct approval object that records:

- The proposed action and responsible role.
- The action-specific evidence references.
- Environmental, accessibility, privacy, and community-impact considerations.
- Required human approvals.
- A bounded duration and scope.
- An accessible appeal or correction path.
- A revocation or expiry condition.

## ALN Policy Layer

ALN policy shards express purpose, prohibited integrations, retention, review, external-action gates, and accountability requirements in machine-readable form.

### Core policy assertions

```text
policy cyboquatic_governance_v1 {
  data_class environmental_telemetry {
    purpose "environmental measurement, restoration analysis, and bounded planning support"
    prohibited_use [
      "individual eligibility determination",
      "identity verification",
      "behavioral profiling",
      "social ranking",
      "assistive-technology surveillance",
      "private learning-continuity inference",
      "unapproved external action"
    ]
    retention "defined by environmental evidence schedule and deletion review"
    publication "precision-limited according to privacy_class"
  }

  accessibility_preferences {
    purpose "adapt presentation, interaction, export, and authentication alternatives"
    consent "explicit, specific, revocable, and optional"
    prohibited_use [
      "eligibility determination",
      "evidence weighting",
      "credibility scoring",
      "service prioritization",
      "environmental impact scoring"
    ]
    retention "user-controlled or short operational retention"
  }

  governed_impact_shard {
    requires [
      "validated_metric_reference",
      "uncertainty_statement",
      "plain_language_explanation",
      "human_review_status",
      "appeal_or_correction_path",
      "external_action_status"
    ]
    default_external_action_status "requires_separate_approval"
    default_on_insufficient_evidence "hold_for_review"
  }
}
```

### Policy synchronization requirements

- Each persisted policy has a version identifier and content hash.
- Every Telemetry Envelope, Validation Result, and Governed Impact Shard references its evaluated policy version.
- A policy change creates a new policy version rather than modifying historic policy evidence.
- CI validates that schema enumerations, SQL constraints, and C++ status types match the active policy vocabulary.
- A policy violation creates an auditable denial receipt containing the attempted purpose, policy identifier, reason code, and timestamp.
- Denial receipts contain no sensitive payload fields beyond what is required for accountable review.

## SQL Integration Model

### Core tables

| Table | Role |
|---|---|
| `telemetry_envelopes` | Stores versioned environmental observations and provenance |
| `calibration_records` | Stores calibration references and validity intervals |
| `validated_metrics` | Stores reproducible kernel outputs and uncertainties |
| `governed_impact_shards` | Stores impact claims, review state, and policy linkage |
| `review_events` | Stores append-only review transitions and explanations |
| `policy_versions` | Stores ALN policy identifiers, content hashes, and activation states |
| `action_approvals` | Stores separate, bounded external-action authorization objects |
| `accessibility_preferences` | Stores optional, encrypted presentation and interaction preferences |

### Integrity rules

- `telemetry_envelopes` contains environmental evidence only.
- `accessibility_preferences` is physically and logically separated from environmental evidence tables.
- No foreign key, view, materialized view, analytic query, or ranking query may join accessibility preferences with environmental scoring data.
- All metric results retain input evidence identifiers, formula version, uncertainty method, and calculation timestamp.
- All review-state transitions are recorded in `review_events`.
- `approved_for_planning` requires the configured review quorum.
- `external_action_status = approved_for_bounded_action` requires a linked, valid, unexpired `action_approvals` record.
- All bounded governance scalar fields use `CHECK` constraints requiring values from 0 through 1.

### Suggested review-event fields

| Field | Purpose |
|---|---|
| `review_event_id` | Immutable event identifier |
| `shard_id` | Related impact shard |
| `previous_status` | State before transition |
| `next_status` | State after transition |
| `review_role` | Accountable discipline or review function |
| `decision_basis` | Plain-language reason for the transition |
| `limitations_acknowledged` | Recorded limitations considered in review |
| `occurred_at_utc` | Event timestamp |
| `policy_version_id` | Policy evaluated for the transition |

## C++20 Integration Model

### Contract responsibilities

The C++ layer implements a typed boundary for:

- Constructing and validating Telemetry Envelopes.
- Verifying unit compatibility and required evidence provenance.
- Executing mass-balance, hydraulic-work, energy-budget, and uncertainty calculations.
- Loading a versioned policy snapshot.
- Determining whether a requested computation, publication, or status transition is permitted.
- Producing immutable Validation Results and Governed Impact Shards.
- Rejecting prohibited cross-plane data flows before calculation or persistence.

### Runtime checks

| Check | Expected behavior |
|---|---|
| Unsupported unit or phenomenon | Return a typed validation failure with an explanation |
| Missing calibration where required | Create a `hold_for_review` result rather than a planning claim |
| Negative uncertainty | Reject input at the contract boundary |
| Incompatible policy version | Deny processing and create a policy-denial receipt |
| Attempted personal-data ingestion into environmental evidence | Reject before storage |
| Attempted access-preference use in a score or eligibility path | Reject before computation |
| External action without an approval object | Deny action and preserve the shard as evidence only |
| Status transition without required reviews | Deny transition and record the unmet approval requirement |

### C++ artifact boundaries

| Artifact | Responsibility |
|---|---|
| `cpp/cyboquatic_telemetry_contract.hpp` | Envelope, units, quality state, provenance, and privacy-boundary types |
| `cpp/cyboquatic_validation_kernel.hpp` | Typed inputs, conservation calculations, uncertainty propagation, and result structures |
| `cpp/cyboquatic_governance.hpp` | Policy snapshot, impact shard, review transition, and action-approval interfaces |
| `cpp/cyboquatic_policy_loader.cpp` | ALN parsing and policy snapshot validation |
| `tests/cyboquatic_governance_tests.cpp` | Policy, review, separation, and approval-gate conformance tests |

## Three-Plane Autonomy Architecture

### Environmental Evidence Plane

Contains only information necessary for defined environmental and ecological purposes.

Examples include:

- Water flow, temperature, pH, turbidity, conductivity, and contaminant concentration.
- Hydraulic head, machinery energy use, maintenance events, and calibration records.
- Spatial references at a precision level appropriate for ecological analysis and publication safety.
- Mass-balance results, energy budgets, and uncertainty statements.

This plane does not contain identity, biometric, neural, health, behavioral, augmentation, assistive-device, or private learning-continuity information.

### Accessibility Preferences Plane

Contains optional, self-asserted settings that adapt interaction without requiring diagnostic proof.

Examples include:

- Preferred text, speech, tactile, visual, or simplified-language outputs.
- Keyboard, switch, voice, or alternate-input support.
- Pacing, notification, offline synchronization, and export preferences.
- Preferred authentication alternatives and accessible review formats.

This plane changes presentation and interaction only. It does not modify eligibility, credibility, environmental impact scores, civic-service priority, rights of access, or review weight.

### Governance and Review Plane

Contains the procedural records that make environmental claims and decisions accountable.

Examples include:

- Policy versions, policy-denial receipts, review events, appeal paths, and action-approval objects.
- Reviewer roles, time-bounded authority records, and explanation requirements.
- Community, accessibility, privacy, ecological, and technical review states.

The Governance and Review Plane may mediate an accessible response format, but it does not expose accessibility-preference content to environmental scoring or eligibility processes.

## Non-Discrimination and Access Invariant

No environmental, civic, repair, accessibility, or planning decision may be based on:

- Claimed identity.
- Augmentation or assistive-technology status.
- Neural, biometric, health, or disability-related information.
- Private learning-continuity or cognitive-practice information.
- The absence of optional telemetry.
- The absence of continuous network connectivity.
- The use or non-use of a proprietary device or external identity-verification provider.

Essential environmental information, civic participation, accessible review, and correction pathways remain available through accessible and non-proprietary interaction routes.

## Implementation Sequence

1. Publish the typed Telemetry Envelope and Validation Result contracts.
2. Publish the ALN policy vocabulary and policy-version record structure.
3. Implement the SQL schema, check constraints, append-only review events, and cross-plane separation controls.
4. Implement C++20 policy loading, contract checks, conservation kernels, and typed policy-denial receipts.
5. Build conformance tests that exercise valid flow, invalid flow, review gating, policy versioning, accessibility adaptation, and prohibited cross-plane use.
6. Add planning dashboards that render plain-language explanations, uncertainty, evidence provenance, and accessible correction pathways.

## Metrics

- `knowledge_factor`: 0.91 — measurement claims remain linked to calibrated evidence, formulas, units, uncertainty, and policy versions.
- `eco_impact_value`: 0.91 — supports verifiable restoration, remediation, energy, water, and maintenance decision support.
- `harm_risk`: 0.10 — reduced through physical data-plane separation, prohibited-use rules, review gates, and bounded external action.
- `accessibility_impact`: 0.95 — makes adaptable interaction a first-class interface capability without forced disclosure.
- `rights_alignment`: 0.97 — supports autonomy, privacy, self-asserted access needs, non-discrimination, explainability, and meaningful review.
