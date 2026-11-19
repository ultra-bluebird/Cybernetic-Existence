# Nanoswarm Governance Validator Findings

## Purpose

This taxonomy defines local, machine-readable finding codes for a non-actuating
validator. A finding reports schema or governance-contract conformance only.
It does not diagnose, verify a person, assess treatment efficacy, determine
legal status, establish eligibility, rank a person, or authorize action.

## Structural-block findings

| Finding code | Meaning | Required local response |
|---|---|---|
| `invalid_repository_relative_path` | A declared artifact reference is absolute, contains parent traversal, uses a remote URL, or is otherwise outside local repository scope | Block the affected artifact and correct the reference |
| `invalid_json` | A JSON artifact cannot be parsed | Block the affected artifact and correct syntax |
| `invalid_schema_contract` | An object does not conform to its declared local schema contract | Block the affected artifact and correct the contract violation |
| `missing_non_authorization_boundary` | Required non-authorization object or required const field is absent | Block the affected artifact |
| `external_action_authorization_detected` | Any required non-authorization invariant is false or an action-authorizing field is present | Block the affected artifact |
| `missing_privacy_boundary` | Privacy boundary is absent or incomplete | Block the affected artifact |
| `identity_or_medical_inference_enabled` | Inference, profiling, ranking, credentialing, or medical inference is permitted | Block the affected artifact |
| `missing_unknown_preservation` | Unknown-preservation boundary is absent or allows causal/default resolution | Block the affected artifact |
| `missing_silence_non_decision` | Silence or time passage can be interpreted as consent, refusal, approval, denial, closure, or resolution | Block the affected artifact |
| `missing_clinical_floor` | A clinical-floor object is required by the declared object family but absent | Block the affected artifact |
| `missing_revision_trigger_entry` | A required artifact lacks revision-trigger coverage | Block the affected artifact |
| `unresolved_drift_finding` | A dependency, revision relationship, or supersession state requires explicit local review | Block only the affected dependency chain |
| `unexpected_sensitive_field` | A closed object contains an undeclared field or a prohibited category of sensitive data | Block the affected artifact |
| `remote_reference_detected` | A schema, manifest, or object attempts to reference a remote resource | Block the affected artifact |

## Non-blocking, review-required findings

| Finding code | Meaning | Required local response |
|---|---|---|
| `review_status_pending` | The artifact is structurally conformant but not marked ready | Preserve as pending; do not upgrade review status automatically |
| `supersession_review_required` | A newer artifact references a predecessor but the relationship has not completed local review | Preserve both states and request local review |
| `documentation_schema_drift` | Human-facing documentation is missing required schema-boundary language | Create a bounded documentation update task |
| `unrecognized_private_vocabulary` | An optional private term is not described in local documentation | Preserve the term as private vocabulary; do not infer meaning |

## Invariants

```text
external_action_authorized == false
identity_inference_permitted == false
profiling_permitted == false
ranking_permitted == false
credentialing_permitted == false
unknown_remains_unknown == true
silence_is_not_decision == true
minimum_disclosure == true
```

A validation pass does not change an artifact, contact any party, publish data,
operate a system, or authorize an action.
