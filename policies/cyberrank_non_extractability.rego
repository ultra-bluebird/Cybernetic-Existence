package augmentedhub.cyberrank

default allow := false

prohibited_support_kind := {
    "cash",
    "property",
    "collateral",
    "equity",
    "transferable_token",
    "sale",
    "rental",
    "inheritance",
    "coercive_authority",
    "essential_service_priority",
}

deny contains reason if {
    input.support.kind in prohibited_support_kind
    reason := "Recognition cannot be converted into wealth, property, collateral, transferable value, coercive authority, or essential-service priority."
}

deny contains reason if {
    input.support.transferable == true
    reason := "Recognition support must be non-transferable."
}

deny contains reason if {
    input.support.cash_redeemable == true
    reason := "Recognition support must not be cash redeemable."
}

deny contains reason if {
    input.support.essential_service_dependency == true
    reason := "Essential services must not depend on recognition status."
}

deny contains reason if {
    input.publication.mode == "pseudonymous"
    input.publication.includes_personal_name == true
    reason := "Pseudonymous publication cannot include a personal name."
}

deny contains reason if {
    input.publication.mode == "pseudonymous"
    input.publication.includes_image == true
    reason := "Pseudonymous publication cannot include an image."
}

deny contains reason if {
    input.publication.mode == "pseudonymous"
    input.publication.includes_geographic_detail == true
    reason := "Pseudonymous publication cannot include geographic detail."
}

deny contains reason if {
    input.publication.safety_suppression_active == true
    reason := "Publication is blocked while a safety or unwanted-publicity concern is active."
}

deny contains reason if {
    input.publication.holder_approved != true
    reason := "Publication requires active holder approval."
}

deny contains reason if {
    input.publication.exact_text_previewed != true
    reason := "Publication requires exact-text preview."
}

deny contains reason if {
    input.adverse_action.final == true
    input.adverse_action.policy_version_present != true
    reason := "Final adverse action requires a policy version."
}

deny contains reason if {
    input.adverse_action.final == true
    input.adverse_action.evidence_indexed != true
    reason := "Final adverse action requires indexed evidence."
}

deny contains reason if {
    input.adverse_action.final == true
    input.adverse_action.notice_provided != true
    reason := "Final adverse action requires notice."
}

deny contains reason if {
    input.adverse_action.final == true
    input.adverse_action.accessible_response_available != true
    reason := "Final adverse action requires an accessible response route."
}

deny contains reason if {
    input.adverse_action.final == true
    input.adverse_action.conflict_screening_passed != true
    reason := "Final adverse action requires conflict screening."
}

deny contains reason if {
    input.adverse_action.final == true
    input.adverse_action.independent_review_available != true
    reason := "Final adverse action requires independent review availability."
}

deny contains reason if {
    input.adverse_action.final == true
    input.adverse_action.reasoned_decision_provided != true
    reason := "Final adverse action requires a reasoned decision."
}

deny contains reason if {
    input.adverse_action.final == true
    input.adverse_action.appeal_route_available != true
    reason := "Final adverse action requires an appeal route."
}

allow if count(deny) == 0
