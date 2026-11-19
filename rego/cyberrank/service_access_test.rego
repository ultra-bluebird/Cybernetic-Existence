package augmentedhub.cyberrank.service_access_test

import data.augmentedhub.cyberrank.service_access

base_input := {
  "service_class": "general_service",
  "digital_path_available": true,
  "non_digital_path_available": true,
  "human_fallback_available": true,
  "outcome_equivalence_verified": true,
  "correction_path_available": true,
  "appeal_path_available": true,
  "accessible_status_available": true,
  "account_required": false,
  "account_necessary": false,
  "uncertainty_level": "high_confidence",
  "critical_automated_decision_requested": false,
  "requested_data_classes": [],
  "requested_practices": []
}

test_private_data_request_is_denied if {
  input := object.union(base_input, {
    "requested_data_classes": ["neural_information"]
  })

  result := service_access.decision with input as input

  result.result == "deny"
  "stop_prohibited_collection" in result.obligations
}

test_status_scoring_is_denied if {
  input := object.union(base_input, {
    "requested_practices": ["perform_status_scoring"]
  })

  result := service_access.decision with input as input

  result.result == "deny"
  "stop_prohibited_practice" in result.obligations
}

test_unreliable_critical_automation_is_held if {
  input := object.union(base_input, {
    "critical_automated_decision_requested": true,
    "uncertainty_level": "unreliable"
  })

  result := service_access.decision with input as input

  result.result == "hold"
  "activate_human_fallback" in result.obligations
  "block_automated_critical_decision" in result.obligations
}

test_essential_service_outage_is_suspended if {
  input := object.union(base_input, {
    "service_class": "emergency_communications",
    "digital_path_available": false,
    "non_digital_path_available": false,
    "human_fallback_available": false
  })

  result := service_access.decision with input as input

  result.result == "suspend"
  "open_continuity_incident" in result.obligations
}
