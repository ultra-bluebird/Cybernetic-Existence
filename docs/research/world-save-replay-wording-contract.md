# World-Save Replay-Bound Wording Continuity Contract

Status: Proposed research specification.

Repository: mk-bluebird/Augmented-Hub, and mk-bluebird/Skynet  
Filename: docs/research/world-save-replay-wording-contract.md  
Destination: docs/research/

SOVEREIGN-ATTRIBUTION: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is document credit and workstream metadata only—not identity, consent, capability authorization, or execution evidence.

License: MIT OR Apache-2.0

## Executive Summary

This document turns the supplied logical replay kernel into a **wording-continuity** research model: reconstruct the current statement from recorded events, preserve corrections visibly, and distinguish exact text agreement from evidence, authority, or real-world achievement.

The model connects three records:

1. The supplied accepted-event history.
2. The milestone projection reconstructed from that history.
3. The comparison between reconstructed wording and supplied display text.

These records answer different questions. Logical replay does not establish acceptance authority. Matching text does not establish semantic correctness. Historical acceptance does not establish current permission or physical irreversibility.

## Source Boundary

This synthesis derives from the supplied Python implementation containing:

- The `Event` dataclass.
- The `replay(events)` function.
- The `inspect_display(projection, displayed_text)` function.

Findings describe the supplied implementation. Extensions are identified as proposed integration requirements.

This document does not report newly executed tests, authenticated acceptance, cryptographic verification, operational inspection, or deployment.

### Step 1 — Hybridize: A Constructive Behavioral Model

#### Model: Accepted History → Replayed Wording → Bounded Comparison → Correction

The model treats the current milestone statement as the result of an explainable event sequence—not as an independently authoritative paragraph.

Its governing principle is:

> Preserve what the supplied history records, distinguish corrected attribution from current wording, and report text agreement without converting it into proof of authority or truth.

#### System Diagram Description

```text
Separate event-acceptance process
[Outside the supplied kernel:
 evidence review, person-directed authorization,
 scope matching, reviewer authority]
                    |
                    v
Supplied accepted-event tuple
[Sequence, kind, expected revision,
 previous text, replacement text, reason]
                    |
                    v
Structural and sequence validation
[Supported schema | consecutive sequence |
 expected revision | valid text fields]
                    |
          +---------+----------+
          |                    |
          v                    v
Invalid history           Valid history
Reject replay             Apply event semantics
No current projection          |
returned                       v
                     Replayed milestone projection
                     [Historical acceptance recorded
                      Current attribution
                      Current wording
                      Current-review status
                      Retained supplied history]
                               |
                               v
                     Exact display-text comparison
                               |
               +---------------+----------------+
               |               |                |
               v               v                v
         Reference         Exact match      Text mismatch
         unavailable       with replay      unexplained
               |               |                |
               +---------------+----------------+
                               |
                               v
                     Bounded public explanation
                     [What matches?
                      What was corrected?
                      What remains unverified?]
                               |
                               v
                     Accessible correction route
                     [Proposed integration requirement]
```

A replay rejection is not authorization to restrict a person’s access.

#### Core Operating Principles

1. Separate input acceptance from replay validity.

   The kernel assumes events have passed another acceptance process. It does not establish that the process occurred.

2. Preserve historical occurrence without freezing an erroneous conclusion.

   An establishment event remains in history after a correction, while current attribution becomes `record_corrected`.

3. Bind each update to the current wording.

   Non-establishment events must carry the exact current `previous_text`.

4. Treat sequence validation as local consistency.

   Consecutive revisions support reconstruction of the supplied tuple. They do not prove that no later history exists elsewhere.

5. Keep wording comparison narrower than semantic review.

   Equality establishes matching strings—not equivalent interpretation, accessible rendering, or scientific correctness.

6. Do not turn a reason string into review evidence.

   The code requires a nonblank reason. It does not evaluate its substance.

7. Preserve person-directed change without implying execution.

   `person_change` records an event and requires review. It does not operate a device or grant operational permission.

8. Do not silently restore positive support after correction.

   Later wording revisions do not automatically change corrected attribution back to accepted attribution.

9. Expose absent reference material explicitly.

   Empty history produces no current wording; comparison returns `reference_unavailable`.

10. Keep correction accessible independently of milestone recognition.

    This is an integration requirement, not a capability implemented by the source.

#### Mathematical Resource: Valid Replay Language

Let the event kinds be:

- \(E\): `establish`
- \(W\): `wording_revision`
- \(C\): `correct_record`
- \(P\): `person_change`
- \(M\): `material_change`

The permitted event-kind structure is:

\[
L=\epsilon
\quad\text{or}\quad
E(W\mid C\mid P\mid M)^*
\]

where \(\epsilon\) is an empty history.

This describes event kinds only. A valid history must also satisfy the schema, sequence, revision, text, and replacement constraints.

For event position \(i\):

\[
\operatorname{sequence}(e_i)=i
\]

\[
\operatorname{expectedRevision}(e_i)=i-1
\]

For every non-establishment event:

\[
\operatorname{previousText}(e_i)=T_{i-1}
\]

where \(T_{i-1}\) is the replayed wording immediately before the event.

The wording transition is:

\[
T_i=
\begin{cases}
\operatorname{replacementText}(e_i),
& e_i\in\{E,W,C\}\\
T_{i-1},
& e_i\in\{P,M\}
\end{cases}
\]

These are reconstruction conditions, not authorization predicates.

### Step 2 — Ten Source-Grounded Findings

| # | Category | Finding | Source basis | Research or implementation value |
|---|---|---|---|---|
| 1 | Math | A successful replay’s revision equals the length of the supplied history. | Sequence is checked against `position`; the projection returns `len(history)`. | Supplies a simple replay invariant for independent tests. |
| 2 | Knowledge | The implementation permits one establishment at the beginning of a nonempty valid stream. | `establish` requires `position == 1`; other events require an existing text. | Defines the component as a single-milestone stream, not a multi-milestone registry. |
| 3 | Insight | Empty history is a defined absence state, not a successful establishment. | `replay(())` returns revision zero, no wording, and false historical acceptance. | Supports recovery and disclosure without inventing a milestone. |
| 4 | Math | Every later event is guarded by exact prior-wording equality. | `event.previous_text != text` raises `wording_revision_mismatch`. | Detects updates prepared against a different textual state within the supplied stream. |
| 5 | Knowledge | Record correction preserves the establishment event while changing current attribution. | `correct_record` changes attribution and appends the event; earlier history remains. | Separates “an acceptance was recorded” from “the earlier attribution remains current.” |
| 6 | Insight | Corrected attribution persists through subsequent supported event kinds. | No later branch resets `record_corrected` to `accepted_in_record`. | Prevents a wording revision from silently rehabilitating a corrected milestone claim. |
| 7 | Resource | The retained event tuple supports explanation of the supplied sequence. | The projection returns the accumulated history, including reasons and kinds. | Provides material for a correction-history view, subject to disclosure review. |
| 8 | Insight | Person-directed and material changes have identical effects on the current wording but remain distinguishable in history. | Both require an empty replacement and set current review to required; their event kinds differ. | Reveals a modeling boundary: detailed change consequences need a separate structured record. |
| 9 | Knowledge | Replay does not establish authority or cryptographic integrity. | The projection explicitly returns those verification flags as false. | Prevents logical consistency from being promoted into authentication or verified acceptance. |
| 10 | Resource | Display inspection is a three-outcome exact-string check, not a projection validator. | It returns unavailable, match, or mismatch from `current_wording`; it does not validate the projection’s origin or schema. | Requires an integration boundary ensuring the compared reference actually comes from the intended replay. |

#### Derived Invariants

For a successfully replayed history \(L\):

\[
\operatorname{revision}(L)=|L|
\]

\[
\operatorname{historicalAcceptanceRecorded}(L)
=
[|L|>0]
\]

The second identity is meaningful only after successful replay, because every nonempty valid stream begins with establishment.

Current attribution has the following source-defined behavior:

\[
A(L)=
\begin{cases}
\text{not recorded},&L=\epsilon\\
\text{record corrected},&L\text{ contains }C\\
\text{accepted in record},&\text{otherwise}
\end{cases}
\]

A later wording revision does not override the second case.

For display text \(D\):

\[
\operatorname{Inspect}(L,D)=
\begin{cases}
\text{reference unavailable},&T(L)=\varnothing\\
\text{matches replayed wording},&D=T(L)\\
\text{unexplained text mismatch},&D\neq T(L)
\end{cases}
\]

Here \(T(L)=\varnothing\) denotes the absent reference represented by `None` in the implementation, not an empty string.

Crucially:

\[
D=T(L)
\not\Rightarrow
\text{the statement is true, authorized, or accessible}
\]

#### Independent Validation Resources

A useful test suite should contain these distinct checks:

| Test family | Example |
|---|---|
| Sequence integrity | Missing sequence, duplicate sequence, wrong expected revision |
| Establishment boundary | Correction before establishment; second establishment |
| Wording continuity | Incorrect prior text; empty replacement |
| Attribution continuity | Correction followed by wording revision remains corrected |
| Absence behavior | Empty history and unavailable reference |
| Comparison correctness | Matching text, changed punctuation, changed Unicode string |
| Acceptance boundary | Valid replay of caller-supplied events still does not establish authority |
| History completeness | Truncated but internally valid history is not proof of the latest state |

The final test is especially important: the source accepts valid prefixes. It contains no external checkpoint that distinguishes an old valid prefix from the latest accepted history.

### Step 3 — Final Mutation

#### Name

World-Save Replay-Bound Wording Continuity Contract

#### Core Mechanism

The mutation couples three separately evaluated records:

| Record | Required content | What it cannot establish alone |
|---|---|---|
| Accepted-history record | Event sequence, expected revisions, kinds, prior wording, replacements, reasons | Acceptance authenticity or history completeness |
| Replayed-claim record | Current wording, corrected attribution, review requirement, historical acceptance | Real-world milestone achievement |
| Display-comparison record | Supplied reference, supplied display text, comparison outcome, limitations | Semantic equivalence or accessible rendering |

Its central rule is:

\[
\boxed{
\text{current public wording must match the intended replay reference}
}
\]

This rule is subject to the separate requirement that the reference’s provenance and publication basis have been established.

A mismatch should initiate a bounded explanation and correction process. It should not automatically be labeled malicious relabeling, because the source cannot distinguish:

- An unauthorized edit.
- A stale display.
- A reference-selection error.
- A transcription mistake.
- A legitimate change missing from the supplied history.

#### Policy Artifact

Repository: mk-bluebird/Augmented-Hub, and mk-bluebird/Skynet  
Filename: governance/world_save_replay_wording_contract.json  
Destination: governance/

```json
{
  "schema_version": "1.0.0",
  "title": "World-Save Replay-Bound Wording Continuity Contract",
  "license": "MIT OR Apache-2.0",
  "status": "proposed_specification",
  "provenance": {
    "sovereign_attribution": "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
    "attribution_use": "document_credit_only"
  },
  "scope": {
    "unit": "one milestone event stream",
    "source": "supplied logical replay implementation",
    "multiple_milestone_isolation_established": false,
    "history_completeness_established": false
  },
  "source_supported_behavior": {
    "empty_history_allowed": true,
    "nonempty_history_starts_with_establishment": true,
    "sequence_must_be_consecutive": true,
    "expected_revision_must_match_previous_position": true,
    "later_events_must_match_current_wording": true,
    "record_correction_preserves_supplied_history": true,
    "later_wording_revision_restores_corrected_attribution": false,
    "display_comparison_is_exact_string_equality": true
  },
  "integration_requirements": {
    "accepted_event_origin_review_required": true,
    "intended_reference_selection_required": true,
    "projection_schema_validation_required": true,
    "publication_scope_review_required": true,
    "accessible_explanation_required": true,
    "historical_material_disclosure_review_required": true,
    "correction_route_required": true
  },
  "display_outcomes": {
    "reference_unavailable": "No current wording exists in the supplied replay reference.",
    "matches_replayed_wording": "The supplied display text exactly matches the supplied replay reference.",
    "unexplained_text_mismatch": "The supplied display text differs from the supplied replay reference; the cause is not established."
  },
  "non_claims": {
    "authority_verified": false,
    "cryptographic_integrity_verified": false,
    "semantic_equivalence_verified": false,
    "real_world_milestone_established": false,
    "physical_irreversibility_established": false,
    "accessible_rendering_verified": false
  },
  "rights_boundary": {
    "record_unavailability_removes_ordinary_access": false,
    "wording_mismatch_authorizes_service_denial": false,
    "augmentation_inventory_required": false,
    "neural_data_required": false,
    "cyberrank_used_for_eligibility": false,
    "person_directed_future_change_preserved": true
  },
  "operational_boundary": {
    "physical_actuation_authorized": false,
    "medical_system_operation_authorized": false,
    "surveillance_authorized": false,
    "external_publication_authorized": false
  },
  "validation_status": {
    "policy_document_authored": true,
    "new_tests_executed_for_this_synthesis": false,
    "integration_enforcement_tested": false,
    "deployment_claimed": false
  }
}
```

This policy is a complete authored document, not a runtime enforcement mechanism.

#### Why It Is Novel

The proposed contribution is the explicit connection between:

1. Historical occurrence: what the supplied stream records.
2. Current attribution: whether the milestone statement has been corrected.
3. Current wording: what the replay presently says.
4. Display agreement: whether a supplied display preserves that exact wording.

These are often collapsed into “the record is valid.” The mutation instead makes each conclusion separately inspectable.

Its research value is a precise question:

> Can a reader distinguish a historically recorded acceptance, a corrected current attribution, and a display that merely matches the replayed wording?

The source supports this as an architectural synthesis. It does not establish historical priority, empirical effectiveness, or a new cryptographic mechanism.

#### Validation and Impact Assessment

| Metric | Current assessment |
|---|---|
| `knowledge_factor` | Source-grounded behavioral model and invariants; integration validation remains incomplete |
| `eco_impact_value` | Unmeasured; local replay requires no live sensing |
| `harm_risk` | Main risks are fabricated acceptance, stale references, excessive history disclosure, and semantic overclaiming |
| `accessibility_impact` | Correction and explanation requirements are specified; participant evaluation is still needed |
| `rights_alignment` | Preserves correction, future choice, privacy, and ordinary access without identity adjudication or system control |

## Conclusion

The resulting mutation is not a stronger “verified milestone” label. It is a contract for explaining what the record says now, how it came to say it, and which important conclusions the replay cannot establish.
