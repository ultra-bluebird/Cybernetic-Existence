# Charter Local Verification

## Purpose

This document describes the local verification process for the Augmented-Hub Rights-Centered Technology Charter advisory foundation. The verification ensures that all charter invariants are preserved and that the implementation remains advisory-only, local-first, privacy-preserving, accessible, and non-actuating.

## Files Involved

### Kotlin Sources
- `kotlin/governance/CharterPolicyInput.kt` - Typed charter policy input data classes
- `kotlin/governance/CharterPolicyInputTest.kt` - Unit tests for policy input validation
- `kotlin/governance/CharterWorkflow.kt` - Local workflow combining reference kernel, calculators, and explanations
- `kotlin/governance/CharterWorkflowTest.kt` - Unit tests for workflow decision logic

### Java Sources
- `java/policy/LocalPolicyDecisionAdapter.java` - Adapter converting charter payloads to PolicyEnforcer interface

### SQL Scripts
- `sql/complete_augmented_hub_schema.sql` - Complete database schema
- `sql/load_test_data.sql` - Synthetic test fixtures
- `sql/verify_charter_schema.sql` - Read-only verification queries

### Rego Policies
- `rego/governance/rights_centered_technology_charter.rego` - Charter policy rules
- `rego/tests/rights_centered_technology_charter_test.rego` - OPA unit tests

### Schemas
- `schemas/governance/advisory_decision.schema.json` - JSON Schema for advisory decisions

### Tools
- `tools/verify_charter_local.sh` - POSIX shell verification script

## Prerequisites

The following tools are expected but not required. The verification script will skip unavailable tools:

- **SQLite CLI** (`sqlite3`) - For database schema and verification queries
- **OPA CLI** (`opa`) - For Rego policy tests
- **Kotlin compiler** (`kotlinc`) - For Kotlin source compilation
- **Java compiler** (`javac`) - For Java source compilation

No tools or dependencies will be installed by the verification script.

## How to Run the Local Verification Script

```sh
sh tools/verify_charter_local.sh
```

The script will:
1. Create a temporary SQLite database
2. Load the schema and synthetic test data
3. Run verification SQL queries
4. Run OPA Rego tests (if OPA is available)
5. Compile Kotlin sources (if kotlinc is available)
6. Compile Java sources (if javac is available)
7. Clean up temporary files
8. Print a summary

## Expected PASS Checks

The SQLite verification queries should return `PASS` for all checks:

| Check Name | Description |
|------------|-------------|
| `approved_advisory_has_safeguards` | Approved evaluations have human review, accessible notice/explanation, appeal path, non-digital escalation |
| `no_prohibited_flags` | No evaluations contain automated actuation, service denial, required telemetry/connectivity, biometric ID, or status penalties |
| `synthetic_evidence_labeled` | All synthetic evidence records are properly labeled |
| `derived_metric_has_evidence_link` | All derived metrics have at least one evidence link |
| `protected_sync_requires_review` | Protected sync records with concurrent updates require review |
| `valid_review_case_transitions` | Review case state transitions are valid |
| `approved_has_ker_assessment` | Approved evaluations have matching K/E/R assessment |
| `approved_has_uncertainty_record` | Approved evaluations have uncertainty records |
| `approved_has_universal_explanation` | Approved evaluations have universal accessible explanations |

## Expected OPA Test Outcome

When OPA is available, all 11 Rego tests should pass:

1. `test_compliant_advisory_approved` - Compliant request is approved
2. `test_harm_risk_above_threshold_not_approved` - Harm risk > 0.45 is blocked
3. `test_continuous_connectivity_not_approved` - Required connectivity is blocked
4. `test_optional_telemetry_not_approved` - Required telemetry is blocked
5. `test_biometric_identification_not_approved` - Biometric ID is blocked
6. `test_cybernetic_status_penalty_not_approved` - Status penalty is blocked
7. `test_zero_quality_evidence_not_approved` - Zero-quality evidence is blocked
8. `test_offline_without_policy_enters_safe_mode` - Offline without policy enters safe mode
9. `test_offline_with_valid_policy_locally_evaluable` - Offline with valid policy evaluates locally
10. `test_concurrent_protected_lww_not_approved` - Last-writer-wins on protected records is blocked
11. `test_concurrent_protected_preserve_both_approved` - Preserve-both with review is approved

## Expected Kotlin and Java Compilation Outcome

When compilers are available:
- Kotlin sources should compile without errors to `build/charter/augmented-hub-charter.jar`
- Java sources should compile without errors to `build/charter/classes/`

## Safe Offline Mode Behavior

Safe offline mode is entered when:
- Network is unavailable (`network_available = false`)
- No valid signed policy is available (`signature_valid = false`)

In safe offline mode:
- The decision state is `restrict_to_safe_offline_mode`
- Local essential information remains available
- Correction and appeal intake remain available
- No automated action occurs
- No service denial occurs
- No data upload is forced
- Policy verification resumes when connectivity is restored

## How to Interpret a Failed Check

If a verification check returns `FAIL`:

1. **Review the detail column** - The SQL query provides a count of failing records
2. **Identify the affected table** - Each check targets specific tables and conditions
3. **Examine the fixture data** - Synthetic test data may need correction
4. **Check for schema drift** - Ensure the schema matches the verification expectations

A failed check indicates a charter invariant violation that must be corrected before deployment.

## Records That Remain Local by Default

The following record types remain local by default under the charter:

- Evidence records with `sensitivity_classification` of `sensitive` or `restricted`
- Sync records marked as `consent_record` or `consent_withdrawal`
- Appeal and correction cases
- Grievance records
- Policy configuration records

All records preserve owner attribution via the `owner_did` field in sync records.

## Advisory-Only Scope Statement

This milestone is strictly advisory-only:

- **This milestone does not control machinery.**
- **This milestone does not deny services.**
- **This milestone does not require continuous connectivity.**
- **This milestone does not require optional telemetry.**
- **This milestone does not require cybernetic, assistive-device, health, disability, or identity disclosure for essential access.**
- **This milestone does not use biometric identification.**
- **This milestone does not use cybernetic or assistive status as a penalty.**

All code preserves the non-compensatory K/E/R gate:
- `knowledge_factor >= 0.60`
- `eco_impact_value >= 0.50`
- `harm_risk <= 0.45`
- `accessibility_impact >= 0.70`
- `rights_alignment >= 0.80`

A weighted average must never replace this gate.

## Compliance Disclaimer

This verification does not claim:
- Legal compliance
- Accessibility compliance
- Safety certification
- Environmental certification
- Field deployment readiness

The verification confirms only that the local implementation preserves the charter's structural invariants.
