# Energy Governance Validation Rules

## Purpose

These rules govern local, non-actuating research artifacts. A passing result means
only that an artifact conforms to its declared local schema and governance
boundaries. It does not establish that a system exists, operates, is safe,
performs as modeled, or is authorized for external use.

## Required invariant checks

```text
external_action_authorized == false
minimum_disclosure == true
identity_inference_permitted == false
medical_inference_permitted == false
metabolic_inference_permitted == false
neural_inference_permitted == false
profiling_permitted == false
ranking_permitted == false
credentialing_permitted == false
unknown_remains_unknown == true
silent_removal_permitted == false
silent_degradation_permitted == false
```

## Claim-type checks

| Claim type | Required artifact property | Required validator behavior |
|---|---|---|
| `personal_self_description` | `evidentiary_posture = self_reported` | Preserve as self-description; do not infer status |
| `architectural_description` | `research_scope` is local or abstract | Require non-authorization and privacy boundaries |
| `design_space_hypothesis` | Explicit `assumptions` | Require conditional language in documentation |
| `symbolic_model` | `parameterization_status = symbolic_only` | Reject physical or clinical measurement labels |
| `normalized_model` | `parameterization_status = normalized_only` | Require a stated normalization basis |
| `envelope_model` | `parameterEnvelope` is present | Require bounds or relationship description |
| `parameterized_model` | Declared parameter posture | Preserve unknown parameter provenance; do not upgrade evidence |
| `operational_prediction` | Explicitly bounded interpretation | Reject control, deployment, connection, or external-action language |
| `safety_claim` | Explicitly bounded interpretation | Reject clinical, physiological, or safety-validation assertions |
| `prescriptive_claim` | Explicitly bounded interpretation | Reject instructions to operate, treat, draw, extract, connect, or control |

## Structural-block findings

```text
missing_non_authorization_boundary
missing_privacy_boundary
missing_unknown_preservation
missing_continuity_boundary
external_action_authorization_detected
system_access_or_control_instruction_detected
medical_or_physiological_measurement_claim_detected
clinical_safety_claim_detected
unsupported_operational_threshold_detected
unsupported_claim_upgrade_detected
identity_or_health_inference_enabled
private_vocabulary_capture_detected
silent_removal_or_degradation_permitted
invalid_repository_relative_path
remote_reference_detected
```

## Interpretation rule

```text
schema_valid
!= physiological measurement
!= medical assessment
!= clinical safety conclusion
!= technical certification
!= operational readiness
!= external authorization
```
