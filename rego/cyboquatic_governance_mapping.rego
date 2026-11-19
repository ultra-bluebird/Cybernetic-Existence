package augmented_hub.cyboquatic.governance

default decision := {
    "state": "hold",
    "reasons": ["governance evaluation has not completed"],
    "required_actions": ["supply required evidence and complete accountable review"],
}

required_aws_criteria := {
    "physical_availability",
    "continuous_availability",
    "legal_availability",
    "water_quality",
    "financial_capability",
    "delivery_storage_treatment_capacity",
    "management_plan_consistency",
    "management_goal_consistency",
}

decision := result if {
    scenario := input.scenario
    predicates := evaluate_predicates(scenario)
    result := aggregate_predicates(predicates)
}

evaluate_predicates(scenario) := predicates if {
    predicates := {
        "scope": evaluate_scope(scenario),
        "source_water": evaluate_source_water(scenario),
        "assured_water_supply": evaluate_assured_water_supply(scenario),
        "tribal_consultation": evaluate_tribal_consultation(scenario),
        "consent": evaluate_consent(scenario),
        "accessibility": evaluate_accessibility(scenario),
        "atmospheric_scope": evaluate_atmospheric_scope(scenario),
    }
}

evaluate_scope(scenario) := result if {
    scenario.jurisdiction_status == "verified"
    result := pass_result(
        "jurisdiction_scope_verified",
        "The scenario jurisdiction and applicable policy scope are documented."
    )
} else := result if {
    result := hold_result(
        "jurisdiction_scope_unverified",
        "Applicable jurisdiction and policy scope require review before evaluation."
    )
}

evaluate_source_water(scenario) := result if {
    scenario.source_water.identified
    scenario.source_water.legal_status == "documented"
    scenario.source_water.physical_availability_margin >= 0
    scenario.source_water.continuity_margin >= 0
    scenario.source_water.quality_margin >= 0
    result := pass_result(
        "source_water_floor_passed",
        "Source-water identity, legal status, physical availability, continuity, and quality margins are documented."
    )
} else := result if {
    not scenario.source_water.identified
    result := reject_result(
        "source_water_not_identified",
        "The scenario does not identify its source water."
    )
} else := result if {
    scenario.source_water.physical_availability_margin < 0
    result := reject_result(
        "physical_water_availability_failed",
        "The source-water physical availability margin is below the safety floor."
    )
} else := result if {
    scenario.source_water.continuity_margin < 0
    result := reject_result(
        "continuous_water_availability_failed",
        "The source-water continuity margin is below the safety floor."
    )
} else := result if {
    scenario.source_water.quality_margin < 0
    result := reject_result(
        "water_quality_floor_failed",
        "The source-water quality margin is below the safety floor."
    )
} else := result if {
    result := hold_result(
        "source_water_evidence_incomplete",
        "Source-water evidence is incomplete or requires accountable review."
    )
}

evaluate_assured_water_supply(scenario) := result if {
    scenario.assured_water_supply.applicable == false
    result := pass_result(
        "assured_water_supply_not_applicable",
        "The scenario records that assured-water-supply evaluation is not applicable within its declared scope."
    )
} else := result if {
    scenario.assured_water_supply.applicable
    scenario.assured_water_supply.review_status == "verified"
    required_aws_criteria_subset(scenario.assured_water_supply.criteria)
    result := pass_result(
        "assured_water_supply_criteria_verified",
        "All required assured-water-supply criteria are documented as verified for the declared use."
    )
} else := result if {
    scenario.assured_water_supply.applicable
    scenario.assured_water_supply.review_status == "failed"
    result := reject_result(
        "assured_water_supply_review_failed",
        "The applicable assured-water-supply review is marked failed."
    )
} else := result if {
    result := hold_result(
        "assured_water_supply_review_required",
        "Applicable assured-water-supply evidence requires jurisdiction-specific review."
    )
}

required_aws_criteria_subset(criteria) if {
    criterion := required_aws_criteria[_]
    criteria[criterion] == "verified"
}

evaluate_tribal_consultation(scenario) := result if {
    scenario.tribal_interest_screening.status == "no_potential_effect_documented"
    result := pass_result(
        "tribal_interest_screening_documented",
        "The scenario documents a completed potential-effect screen."
    )
} else := result if {
    scenario.tribal_interest_screening.status == "consultation_completed"
    scenario.tribal_interest_screening.outcome == "conditions_satisfied"
    result := pass_result(
        "tribal_consultation_conditions_satisfied",
        "Required consultation is documented with its stated conditions satisfied."
    )
} else := result if {
    scenario.tribal_interest_screening.status == "potential_effect"
    scenario.tribal_interest_screening.consultation_required
    result := hold_result(
        "tribal_consultation_required",
        "Potential Tribal interests require consultation through the appropriate sovereign and community-defined process."
    )
} else := result if {
    result := hold_result(
        "tribal_interest_screening_incomplete",
        "Potential effects on Tribal interests require a documented screening and accountable review."
    )
}

evaluate_consent(scenario) := result if {
    scenario.data_governance.personal_data_present == false
    result := pass_result(
        "no_personal_data_required",
        "The scenario declares no personal data collection."
    )
} else := result if {
    scenario.data_governance.personal_data_present
    scenario.data_governance.consent_status == "active_and_specific"
    scenario.data_governance.purpose_limitation_verified
    scenario.data_governance.revocation_path_available
    result := pass_result(
        "consent_and_purpose_limitation_verified",
        "Specific consent, purpose limitation, and revocation pathways are documented."
    )
} else := result if {
    result := reject_result(
        "consent_or_purpose_limitation_failed",
        "Personal-data processing lacks documented specific consent, purpose limitation, or a revocation pathway."
    )
}

evaluate_accessibility(scenario) := result if {
    scenario.accessibility.non_digital_participation_available
    scenario.accessibility.plain_language_summary_available
    scenario.accessibility.review_path_available
    result := pass_result(
        "accessibility_requirements_verified",
        "The scenario provides non-digital participation, plain-language explanation, and a review path."
    )
} else := result if {
    result := hold_result(
        "accessibility_evidence_incomplete",
        "The scenario requires documented accessible and non-digital participation pathways."
    )
}

evaluate_atmospheric_scope(scenario) := result if {
    scenario.atmospheric_scope == "not_requested"
    result := pass_result(
        "atmospheric_scope_not_requested",
        "The scenario requests no atmospheric research output."
    )
} else := result if {
    scenario.atmospheric_scope == "research_only_no_material_release"
    result := pass_result(
        "bounded_atmospheric_research_scope",
        "The scenario requests bounded atmospheric research without material release or weather-control activity."
    )
} else := result if {
    result := reject_result(
        "prohibited_atmospheric_scope",
        "The scenario requests prohibited atmospheric activity or an unsupported atmospheric scope."
    )
}

aggregate_predicates(predicates) := result if {
    some key
    predicates[key].state == "reject"
    result := {
        "state": "reject",
        "reasons": [predicates[item].reason | item := object.keys(predicates)[_]; predicates[item].state == "reject"],
        "required_actions": [predicates[item].required_action | item := object.keys(predicates)[_]; predicates[item].state == "reject"],
        "context_utility_available": false,
    }
} else := result if {
    some key
    predicates[key].state == "hold"
    result := {
        "state": "hold",
        "reasons": [predicates[item].reason | item := object.keys(predicates)[_]; predicates[item].state == "hold"],
        "required_actions": [predicates[item].required_action | item := object.keys(predicates)[_]; predicates[item].state == "hold"],
        "context_utility_available": false,
    }
} else := result if {
    result := {
        "state": "simulate",
        "reasons": [predicates[item].reason | item := object.keys(predicates)[_]],
        "required_actions": [],
        "context_utility_available": true,
    }
}

pass_result(code, reason) := {
    "state": "simulate",
    "code": code,
    "reason": reason,
    "required_action": "",
}

hold_result(code, reason) := {
    "state": "hold",
    "code": code,
    "reason": reason,
    "required_action": reason,
}

reject_result(code, reason) := {
    "state": "reject",
    "code": code,
    "reason": reason,
    "required_action": reason,
}
