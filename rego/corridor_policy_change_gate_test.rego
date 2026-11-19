package augmented_hub.corridor_policy_change_gate_test

import data.augmented_hub.corridor_policy_change_gate

passing_input := {
    "change_kind": "corridor_negotiation_policy",
    "baseline_policy_version": "baseline_policy_v1",
    "candidate_policy_version": "candidate_policy_v1",
    "data_retention_class": "aggregate_only",
    "personal_identity_absent": true,
    "health_data_absent": true,
    "biometric_data_absent": true,
    "neural_data_absent": true,
    "device_serial_numbers_absent": true,
    "individual_event_history_absent": true,
    "accessible_review_path_available": true,
    "human_oversight_required": true,
    "candidate_requires_external_identity_certification": false,
    "candidate_requires_personal_telemetry": false,
    "candidate_penalizes_missing_optional_urgency": false,
    "candidate_allows_forced_passage": false,
    "candidate_allows_bot_precedence_over_protected_actor": false,
    "formal_invariants": [
        {
            "name": "pedestrian_first_precedence",
            "status": "passed",
            "counterexample_count": 0
        },
        {
            "name": "no_forced_passage",
            "status": "passed",
            "counterexample_count": 0
        },
        {
            "name": "category_non_discrimination",
            "status": "passed",
            "counterexample_count": 0
        },
        {
            "name": "optional_urgency_non_penalty",
            "status": "passed",
            "counterexample_count": 0
        },
        {
            "name": "autonomous_bot_fails_safe_under_uncertainty",
            "status": "passed",
            "counterexample_count": 0
        }
    ],
    "comparison": {
        "mobility_priority_grant_difference": 0,
        "pedestrian_priority_grant_difference": 0,
        "unsafe_configuration_ratio_difference": 0
    }
}

test_allows_candidate_for_synthetic_comparison_when_hard_gates_pass if {
    result := corridor_policy_change_gate.allow_change with input as passing_input
    result
}

test_halts_when_pedestrian_precedence_has_counterexample if {
    invalid_input := object.union(
        passing_input,
        {
            "formal_invariants": [
                {
                    "name": "pedestrian_first_precedence",
                    "status": "failed",
                    "counterexample_count": 1
                },
                {
                    "name": "no_forced_passage",
                    "status": "passed",
                    "counterexample_count": 0
                },
                {
                    "name": "category_non_discrimination",
                    "status": "passed",
                    "counterexample_count": 0
                },
                {
                    "name": "optional_urgency_non_penalty",
                    "status": "passed",
                    "counterexample_count": 0
                },
                {
                    "name": "autonomous_bot_fails_safe_under_uncertainty",
                    "status": "passed",
                    "counterexample_count": 0
                }
            ]
        }
    )

    result := corridor_policy_change_gate.allow_change with input as invalid_input
    not result
}

test_halts_when_candidate_increases_unsafe_configuration_rate if {
    invalid_input := object.union(
        passing_input,
        {
            "comparison": {
                "mobility_priority_grant_difference": 0,
                "pedestrian_priority_grant_difference": 0,
                "unsafe_configuration_ratio_difference": 0.001
            }
        }
    )

    result := corridor_policy_change_gate.allow_change with input as invalid_input
    not result
}

test_halts_when_personal_telemetry_is_requested if {
    invalid_input := object.union(
        passing_input,
        {
            "candidate_requires_personal_telemetry": true
        }
    )

    result := corridor_policy_change_gate.allow_change with input as invalid_input
    not result
}
