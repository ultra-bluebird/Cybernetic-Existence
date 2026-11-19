# Augmented-Hub Local Advisory Runbook

## Purpose

This runbook creates a local, synthetic, advisory-only demonstration of the Augmented-Hub evidence ledger, reference calculations, Rego policy, accessible explanation layer, and API contract.

No step in this runbook requires live sensor data, community data, cybernetic integration data, biometric data, health records, device telemetry, or production deployment.

## Prerequisites

- SQLite with support for STRICT tables
- Java 21 or later
- Kotlin/JVM 2.x or later
- Open Policy Agent CLI
- A local HTTP server or application implementation for the OpenAPI endpoint
- A browser for the static test client

## Create the Local Ledger

Create an empty local database:

```sh
sqlite3 augmented_hub_demo.db < sql/complete_augmented_hub_schema.sql
```

Load clearly labeled synthetic fixtures:

```sh
sqlite3 augmented_hub_demo.db < sql/load_test_data.sql
```

Inspect the advisory governance results:

```sh
sqlite3 augmented_hub_demo.db \
  "SELECT evaluation_id, decision_state, knowledge_factor, eco_impact_value, harm_risk, accessibility_impact, rights_alignment
   FROM v_advisory_governance_status
   ORDER BY evaluation_id;"
```

Inspect the evidence lineage for a synthetic metric:

```sh
sqlite3 augmented_hub_demo.db \
  "SELECT metric_id, metric_name, metric_value, evidence_id, source_type, variable_name, data_quality, uncertainty_score
   FROM v_advisory_evidence_lineage
   WHERE metric_id = 'synthetic-shade-ratio-001';"
```

## Evaluate the Rego Policy

Create a local JSON input file containing only synthetic values:

```json
{
  "ker": {
    "knowledge_factor": 0.78,
    "eco_impact_value": 0.82,
    "harm_risk": 0.18,
    "accessibility_impact": 0.86,
    "rights_alignment": 0.92
  },
  "evidence": {
    "quality_scores": [0.84, 0.88, 0.90, 0.76],
    "quality_weights": [0.25, 0.25, 0.25, 0.25]
  },
  "uncertainty": {
    "record_present": true,
    "score": 0.24
  },
  "policy": {
    "maximum_uncertainty_for_advisory_use": 0.35
  },
  "governance": {
    "advisory_only": true,
    "automatically_actuates_machinery": false,
    "automated_service_denial": false,
    "requires_optional_telemetry": false,
    "requires_continuous_connectivity": false,
    "biometric_identification_permitted": false,
    "cybernetic_integration_data_required": false,
    "cybernetic_status_penalty": 0,
    "assistive_technology_penalty": 0,
    "human_review_available": true,
    "accessible_notice_available": true,
    "accessible_explanation_available": true,
    "appeal_path_available": true,
    "non_digital_escalation_available": true,
    "data_minimization_confirmed": true,
    "purpose_limitation_confirmed": true,
    "retention_and_deletion_path_available": true
  },
  "runtime": {
    "local_policy_evaluation_available": true,
    "network_available": false
  },
  "policy_bundle": {
    "signature_valid": true,
    "version_known": true,
    "not_expired": true
  }
}
```

Evaluate it locally:

```sh
opa eval \
  --data rego/comprehensive_augmented_hub_policy.rego \
  --input synthetic_policy_input.json \
  "data.augmented_hub.comprehensive_policy.decision"
```

## Compile Kotlin

Compile reference calculators and explanation components:

```sh
kotlinc \
  kotlin/calculators/EnvironmentalReferenceCalculators.kt \
  kotlin/explanations/AccessibleExplanation.kt \
  -d build/augmented-hub-calculators.jar
```

Compile the associated tests with the Kotlin test library available on the classpath:

```sh
kotlinc \
  kotlin/calculators/EnvironmentalReferenceCalculators.kt \
  kotlin/explanations/AccessibleExplanation.kt \
  kotlin/explanations/AccessibleExplanationTest.kt \
  -d build/augmented-hub-tests.jar
```

## Compile Java

Compile the local policy interface:

```sh
javac \
  -d build/classes \
  java/policy/PolicyEnforcer.java
```

## Serve the Test Client

Serve the static test client from the repository root:

```sh
python3 -m http.server 8080
```

Open the local test client in a browser:

```text
http://localhost:8080/web/test_client.html
```

The page expects a local implementation of:

```text
POST /v1/advisories/evaluate
```

The API contract is defined in `web/API-Spec.yaml`.

## Expected Safety Behavior

- A zero evidence-quality factor produces insufficient evidence.
- A harm-risk score above 0.45 blocks advisory approval.
- Accessibility below 0.70 blocks advisory approval.
- Rights alignment below 0.80 blocks advisory approval.
- Missing human review, accessible explanation, appeal path, or non-digital escalation produces a review state.
- Required optional telemetry, required continuous connectivity, biometric identification, automated service denial, and physical actuation are prohibited.
- A valid retained local policy bundle permits local evaluation while offline.
- No valid local policy while offline produces `restrict_to_safe_offline_mode`.
- Safe offline mode preserves locally stored essential information, correction intake, appeal intake, and accessible explanation.
