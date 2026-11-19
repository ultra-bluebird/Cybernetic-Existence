# Checkpoint Supersession CLI Specification

## Status and purpose

**Document status:** Draft technical specification  
**Specification version:** 1.0.0  
**Applies to:** `mk-bluebird/Augmented-Hub` and `mk-bluebird/Skynet`

This specification defines a local, non-actuating CLI contract for preparing and validating a checkpoint-supersession record when a later MCMC run is proposed to supersede an earlier checkpoint or run for a stated internal research purpose.

The CLI does not delete, overwrite, alter, publish, upload, send, commit, merge, deploy, or externally synchronize checkpoint material. It validates declared metadata, produces a draft supersession record, and fails closed when required evidence is absent or inconsistent.

## Non-authorization notice

The checkpoint supersession CLI does not authorize:

- Replacing or deleting an earlier checkpoint.
- Treating a later checkpoint as the binding unit for an older output.
- Publishing a model result, issuing a correction, or communicating externally.
- Claiming model validity, convergence, calibration, scientific correctness, or applicability.
- Accessing remote storage, repositories, APIs, accounts, credentials, cloud systems, or external compute systems.
- Performing field activity, environmental intervention, infrastructure control, public alerting, external data transfer, or operational action.
- Determining identity, representation, consent, rights-holder status, eligibility, institutional status, or authority.

\[
\text{checkpoint supersession draft}
\not\Rightarrow
\text{repository mutation, output rebinding, or external authorization}
\]

## Command model

The CLI command namespace is:

```text
checkpoint-supersession
```

Supported commands:

```text
checkpoint-supersession validate
checkpoint-supersession plan
checkpoint-supersession render
```

The command must operate only on explicitly supplied local metadata files or standard input. It must not discover, scan, upload, download, clone, write outside an explicitly selected local output path, or use network access.

## Required input contract

The CLI must accept a structured request containing:

```json
{
  "request_type": "checkpoint_supersession_request",
  "request_id": "checkpoint-supersession-example-001",
  "predecessor_checkpoint_reference": "checkpoints/mcmc-run-001-iter-05000.json",
  "successor_checkpoint_reference": "checkpoints/mcmc-run-002-iter-12000.json",
  "supersession_scope": "internal_research_output_recomputation",
  "model_identity": {
    "predecessor_model_id": "model-example",
    "predecessor_model_version": "1.0.0",
    "successor_model_id": "model-example",
    "successor_model_version": "1.1.0"
  },
  "evidence_set": {
    "predecessor_chain_resolution_reference": "manifests/checkpoint-chain-resolution-run-001.json",
    "successor_chain_resolution_reference": "manifests/checkpoint-chain-resolution-run-002.json",
    "mcmc_diagnostics_reference": "manifests/mcmc-diagnostics-run-002.json",
    "convergence_assessment_reference": "manifests/convergence-assessment-run-002.json",
    "uncertainty_comparison_reference": "manifests/uncertainty-comparison-001-002.json",
    "data_scope_comparison_reference": "manifests/data-scope-comparison-001-002.json",
    "material_change_assessment_reference": "manifests/model-change-assessment-001-002.json",
    "calibration_or_ood_assessment_reference": "manifests/ood-calibration-assessment-run-002.json",
    "review_bundle_reference": "manifests/checkpoint-supersession-review-bundle-001.json"
  },
  "dependent_output_references": [
    "outputs/research-output-example-001.json"
  ],
  "requested_by_role": "output_author",
  "external_action_authorized": false
}
```

Every reference is metadata only. A reference does not establish file existence, review completion, correctness, or authority unless a separate verification record is supplied.

## Required evidence set

A later MCMC run may be proposed as a superseding checkpoint only when the request contains all of the following non-empty evidence references:

| Evidence field | Required purpose |
|---|---|
| `predecessor_chain_resolution_reference` | Identifies the predecessor chain, immediate parent, and root |
| `successor_chain_resolution_reference` | Identifies the successor chain, immediate parent, and root |
| `mcmc_diagnostics_reference` | Records diagnostics relevant to the later run |
| `convergence_assessment_reference` | Records convergence assessment under the declared model contract |
| `uncertainty_comparison_reference` | Compares uncertainty characteristics without erasing predecessor uncertainty |
| `data_scope_comparison_reference` | Records changes in data digest, scope, consent, access, retention, or provenance conditions |
| `material_change_assessment_reference` | Determines whether model, data, inference, calibration, OOD, or uncertainty changes are material |
| `calibration_or_ood_assessment_reference` | States calibration eligibility and OOD limits for the successor context |
| `review_bundle_reference` | Links the required governance, research, privacy, and implementation review bundle |

The CLI must reject a request with a missing, empty, duplicate, malformed, or structurally inconsistent evidence reference.

### Binding-preservation evidence bundle

A checkpoint supersession request must preserve the binding pair of every older output that cites the predecessor chain.

For each older output affected by a proposed successor, the bundle must contain:

| Evidence field | Purpose |
|---|---|
| `older_output_reference` | Identifies the historical output whose provenance is preserved |
| `older_output_immediate_parent_reference` | Preserves the checkpoint that directly generated the older output |
| `older_output_chain_root_reference` | Preserves the root of the older output’s declared lineage |
| `older_output_binding_resolution_reference` | References the recorded chain resolution for the older output |
| `successor_checkpoint_reference` | Identifies the later proposed successor |
| `successor_chain_resolution_reference` | Records the successor’s own immediate-parent and root lineage |
| `binding_preservation_assessment_reference` | States that the older output binding is unchanged |
| `new_output_binding_requirement` | States that any output directly derived from the successor receives a new immediate-parent/root pair |
| `supersession_review_bundle_reference` | References required governance, provenance, uncertainty, privacy, and implementation review evidence |

The CLI must reject a supersession plan if an older output would lose, replace, obscure, or silently rewrite its recorded immediate-parent or chain-root binding.

A later successor may appear in an older output only as contextual successor metadata. It must not replace the older output’s binding checkpoint pair.

## Binding rule

Checkpoint supersession does not retroactively replace the binding pair of an already-produced output.

For a chain:

\[
C_0 \rightarrow C_1 \rightarrow C_2
\]

where output \(O_1\) was generated directly from \(C_1\):

\[
B(O_1) = (C_1, C_0)
\]

If \(C_2\) is later validated as a successor, it may be recorded as contextual successor metadata for \(O_1\). It does not become \(O_1\)'s immediate-parent binding.

A newly computed output \(O_2\) directly generated from \(C_2\) has its own binding:

\[
B(O_2) = (C_2, C_0)
\]

The CLI must reject an attempt to use successor metadata to rewrite an older output’s binding pair.

## Validation behavior

`checkpoint-supersession validate` must fail closed when any of the following occurs:

- The predecessor or successor checkpoint reference is missing.
- The predecessor and successor reference are identical.
- The successor chain is unresolved, cyclic, structurally blocked, or lacks an immediate-parent/root binding.
- The predecessor chain is unresolved, cyclic, structurally blocked, or lacks an immediate-parent/root binding.
- A required evidence reference is absent, empty, duplicated where uniqueness is required, or outside an allowed repository-relative path shape.
- The material-change assessment is missing.
- The data scope comparison is missing.
- The OOD or calibration assessment is missing.
- The review bundle is missing.
- A request claims external action authorization.
- A request attempts to rebind an existing output from its immediate parent to a later terminal checkpoint.
- A withdrawal, correction, consent, access, privacy, retention, or provenance-cycle block remains unresolved for a dependent output.
- A structural block is present in the predecessor or successor record.

A failed validation must produce a structured result with `status: "structural_block"` and specific block reason codes. It must not produce a generic success/failure result only.

## Plan command

`checkpoint-supersession plan` validates the request and, if structurally complete, emits a draft plan:

```json
{
  "record_type": "checkpoint_supersession_plan",
  "plan_status": "review_pending",
  "predecessor_checkpoint_reference": "checkpoints/mcmc-run-001-iter-05000.json",
  "successor_checkpoint_reference": "checkpoints/mcmc-run-002-iter-12000.json",
  "binding_preservation": {
    "existing_outputs_retain_immediate_parent": true,
    "successor_is_context_only_for_existing_outputs": true,
    "new_outputs_require_new_binding_pair": true
  },
  "required_evidence_set": {
    "predecessor_chain_resolution_reference": "manifests/checkpoint-chain-resolution-run-001.json",
    "successor_chain_resolution_reference": "manifests/checkpoint-chain-resolution-run-002.json",
    "mcmc_diagnostics_reference": "manifests/mcmc-diagnostics-run-002.json",
    "convergence_assessment_reference": "manifests/convergence-assessment-run-002.json",
    "uncertainty_comparison_reference": "manifests/uncertainty-comparison-001-002.json",
    "data_scope_comparison_reference": "manifests/data-scope-comparison-001-002.json",
    "material_change_assessment_reference": "manifests/model-change-assessment-001-002.json",
    "calibration_or_ood_assessment_reference": "manifests/ood-calibration-assessment-run-002.json",
    "review_bundle_reference": "manifests/checkpoint-supersession-review-bundle-001.json"
  },
  "dependent_output_references": [
    "outputs/research-output-example-001.json"
  ],
  "external_action_authorized": false,
  "non_authorization": {
    "statement": "This is an internal draft plan. It does not overwrite checkpoints, rebind existing outputs, publish results, or authorize external action.",
    "external_action_requires_separate_approval": true,
    "does_not_verify_identity_or_status": true,
    "does_not_verify_repository_state": true
  }
}
```

The plan command must emit `review_pending`, not `approved`, `issued`, `published`, or `externally_authorized`.

## Render command

`checkpoint-supersession render` converts a validated draft plan into a human-readable supersession record for internal review. It must:

- Preserve all evidence references.
- Identify predecessor and successor checkpoints distinctly.
- State that existing output bindings remain unchanged.
- State material model, data, calibration, OOD, uncertainty, and provenance differences.
- Include unresolved limitations and structural blocks, if any.
- Include required review roles and review status.
- Include a canonical non-authorization statement.
- Avoid embedding raw model state, parameter vectors, random-number-generator state, data payloads, personal data, credentials, hashes, secrets, or protected audit content.

## Output contract

A valid draft supersession record must contain:

```json
{
  "record_type": "checkpoint_supersession_record",
  "record_id": "checkpoint-supersession-record-example-001",
  "record_status": "review_pending",
  "predecessor_checkpoint_reference": "checkpoints/mcmc-run-001-iter-05000.json",
  "successor_checkpoint_reference": "checkpoints/mcmc-run-002-iter-12000.json",
  "supersession_scope": "internal_research_output_recomputation",
  "binding_preservation": {
    "existing_output_bindings_modified": false,
    "successor_terminal_checkpoint_is_context_only_for_existing_outputs": true
  },
  "evidence_set_reference": "manifests/checkpoint-supersession-evidence-set-001.json",
  "material_change_assessment_reference": "manifests/model-change-assessment-001-002.json",
  "review_status": "review_pending",
  "external_action_authorized": false,
  "non_authorization": {
    "statement": "This supersession record preserves checkpoint provenance and internal review context only. It does not alter prior output bindings, authorize external action, or establish model validity.",
    "external_action_requires_separate_approval": true,
    "does_not_verify_identity_or_status": true,
    "does_not_verify_repository_state": true
  }
}
```

## Error codes

| Code | Meaning |
|---|---|
| `missing_checkpoint_reference` | Predecessor or successor reference is absent |
| `identical_checkpoint_reference` | Predecessor and successor are the same |
| `missing_evidence_reference` | Required evidence reference is absent |
| `invalid_evidence_reference` | Evidence reference is malformed or outside accepted repository-relative scope |
| `duplicate_evidence_reference` | A reference is duplicated where a distinct evidence item is required |
| `predecessor_chain_structural_block` | Predecessor chain cannot be resolved safely |
| `successor_chain_structural_block` | Successor chain cannot be resolved safely |
| `provenance_cycle` | A checkpoint lineage cycle is detected |
| `material_change_unassessed` | Required material-change assessment is absent |
| `calibration_or_ood_unassessed` | Calibration or OOD assessment is absent |
| `dependent_output_blocked` | A dependent output has unresolved governance constraints |
| `attempted_rebinding_of_existing_output` | Request attempts to replace an older output’s immediate-parent binding |
| `external_action_not_authorized` | Request claims or requires external action |
| `unsupported_request_version` | Request format is unsupported |

## Required tests

A future CLI implementation should test:

1. A complete local metadata request produces `review_pending`.
2. Missing each required evidence reference produces its own explicit structural-block reason.
3. Identical predecessor and successor references are rejected.
4. A cyclic predecessor or successor chain is rejected.
5. A terminal checkpoint cannot replace an older output’s immediate-parent binding.
6. A new output computed from the successor receives a new immediate-parent/root pair.
7. A material data, model, calibration, OOD, uncertainty, or consent-scope change requires an assessment reference.
8. A withdrawal-affected or correction-blocked dependent output prevents plan completion.
9. `external_action_authorized: true` is rejected.
10. The CLI performs no network access, repository writes, deletion, publishing, or external communication.
