package augmentedhub.data_governance_test

import data.augmentedhub.data_governance

base_input := {
  "actor_id": "local-research-service",
  "purpose": "aggregate_research",
  "dataset_id": "eco-observations-v1",
  "audit_id": "audit-decision-001",
  "now_utc": "2026-09-03T21:48:00Z",
  "actor": {
    "authorized": true,
    "role": "research_service"
  },
  "dataset": {
    "data_class": "derived_feature",
    "maximum_permitted_field_count": 8,
    "maximum_permitted_time_window_seconds": 86400,
    "maximum_permitted_rows": 1000
  },
  "scope": {
    "field_count": 4,
    "time_window_seconds": 3600,
    "rows_requested": 100,
    "local_only": true
  },
  "authorization": {
    "basis": "authorized_research_scope",
    "status": "active",
    "expiry_utc": "2026-09-04T21:48:00Z",
    "permitted_purposes": [
      "aggregate_research"
    ],
    "output_mode": "aggregate_only",
    "direct_identifier_exception": false,
    "sensitive_interface_exception": false,
    "inference_prohibited": true
  },
  "output": {
    "mode": "aggregate_only"
  },
  "audit": {
    "sink_available": true,
    "event_kind": "data_access_decision"
  }
}

test_permits_minimized_aggregate_research if {
  data.augmentedhub.data_governance.permit with input as base_input
}

test_denies_expired_authorization if {
  expired := object.union(
    base_input,
    {
      "authorization": object.union(
        base_input.authorization,
        {
          "expiry_utc": "2026-09-03T20:00:00Z"
        }
      )
    }
  )

  not data.augmentedhub.data_governance.permit with input as expired
  data.augmentedhub.data_governance.deny_reason == "authorization_expired_or_invalid" with input as expired
}

test_denies_sensitive_interface_export if {
  sensitive := object.union(
    base_input,
    {
      "dataset": object.union(
        base_input.dataset,
        {
          "data_class": "sensitive_interface_data"
        }
      ),
      "output": {
        "mode": "aggregate_only"
      },
      "authorization": object.union(
        base_input.authorization,
        {
          "sensitive_interface_exception": false
        }
      )
    }
  )

  not data.augmentedhub.data_governance.permit with input as sensitive
  data.augmentedhub.data_governance.deny_reason == "sensitive_data_protection_required" with input as sensitive
}

test_denies_when_audit_sink_is_unavailable if {
  unavailable_audit := object.union(
    base_input,
    {
      "audit": {
        "sink_available": false,
        "event_kind": "data_access_decision"
      }
    }
  )

  not data.augmentedhub.data_governance.permit with input as unavailable_audit
  data.augmentedhub.data_governance.deny_reason == "audit_sink_unavailable" with input as unavailable_audit
}
