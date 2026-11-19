package augmented_hub.existence_centered_urban_planning_test

import data.augmented_hub.existence_centered_urban_planning

test_allows_verified_ninety_five_percent_coverage if {
    result := existence_centered_urban_planning.allow_scenario with input as {
        "scenario_name": "connected-corridor-public-space-plan",
        "public_space_count": 100,
        "qualifying_public_space_count": 95,
        "continuity_evidence_basis_points": 9700,
        "requires_external_identity_certification": false,
        "requires_personal_telemetry": false,
        "accessible_review_path_available": true,
    }

    result
}

test_denies_coverage_below_hard_constraint_pending_remediation if {
    result := existence_centered_urban_planning.allow_scenario with input as {
        "scenario_name": "partial-coverage-plan",
        "public_space_count": 100,
        "qualifying_public_space_count": 94,
        "continuity_evidence_basis_points": 9800,
        "requires_external_identity_certification": false,
        "requires_personal_telemetry": false,
        "accessible_review_path_available": true,
    }

    not result
}

test_denies_identity_certification_requirement if {
    result := existence_centered_urban_planning.allow_scenario with input as {
        "scenario_name": "certification-dependent-plan",
        "public_space_count": 100,
        "qualifying_public_space_count": 100,
        "continuity_evidence_basis_points": 10000,
        "requires_external_identity_certification": true,
        "requires_personal_telemetry": false,
        "accessible_review_path_available": true,
    }

    not result
}

test_denies_personal_telemetry_requirement if {
    result := existence_centered_urban_planning.allow_scenario with input as {
        "scenario_name": "telemetry-dependent-plan",
        "public_space_count": 100,
        "qualifying_public_space_count": 100,
        "continuity_evidence_basis_points": 10000,
        "requires_external_identity_certification": false,
        "requires_personal_telemetry": true,
        "accessible_review_path_available": true,
    }

    not result
}
