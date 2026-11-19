package augmented_hub.identity_planning_category_test

import data.augmented_hub.identity_planning_category

test_accepts_self_declared_category_with_charging_need if {
    result := identity_planning_category.allow with input as {
        "self_declaration": {
            "category": "cybernetic host",
        },
        "infrastructure_needs": [
            {
                "kind": "charging_requirement",
                "minimum_power_watts": 100,
            },
        ],
    }

    result
}

test_assessment_does_not_collect_personal_data if {
    assessment := identity_planning_category.accepted_planning_category with input as {
        "self_declaration": {
            "category": "cybernetic host",
        },
        "infrastructure_needs": [
            {
                "kind": "thermal_comfort_requirement",
                "maximum_safe_temperature_celsius": 35,
            },
        ],
    }

    assessment.personal_data_collected == false
    assessment.external_certification_required == false
    assessment.evidence_status == "self_declared_and_need_observed"
}

test_rejects_missing_infrastructure_need if {
    result := identity_planning_category.allow with input as {
        "self_declaration": {
            "category": "cybernetic host",
        },
        "infrastructure_needs": [],
    }

    not result
}

test_rejects_blank_self_declaration if {
    result := identity_planning_category.allow with input as {
        "self_declaration": {
            "category": " ",
        },
        "infrastructure_needs": [
            {
                "kind": "charging_requirement",
                "minimum_power_watts": 100,
            },
        ],
    }

    not result
}
