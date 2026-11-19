package augmented_hub.consent_capability_escalation

default allow := false

material_escalation if {
    input.request.from_capability != input.request.to_capability
}

valid_explicit_consent if {
    input.consent.mode == "explicit"
    input.consent.revoked == false
    input.consent.scope == input.request.scope
    time.now_ns() < time.parse_rfc3339_ns(input.consent.expires_at)
}

impact_disclosed if {
    input.request.impact_disclosure.version != ""
    count(input.request.impact_disclosure.risks) > 0
    count(input.request.impact_disclosure.data_categories) > 0
}

reversibility_plan_present if {
    input.request.reversibility_plan.mode != ""
    input.request.reversibility_plan.owner != ""
    input.request.reversibility_plan.review_at != ""
}

non_coercion_attested if {
    input.request.non_coercion_attestation == true
}

no_unauthorized_public_disclosure if {
    not input.request.data_effect.public_disclosure
}

public_disclosure_separately_consented if {
    input.request.data_effect.public_disclosure == true
    input.publication_consent.mode == "explicit"
    input.publication_consent.revoked == false
    input.publication_consent.scope == "public_disclosure"
    time.now_ns() < time.parse_rfc3339_ns(input.publication_consent.expires_at)
}

no_external_actuation if {
    input.request.to_capability != "actuating"
}

external_actuation_separately_approved if {
    input.request.to_capability == "actuating"
    input.external_action_approval.mode == "explicit"
    input.external_action_approval.revoked == false
    input.external_action_approval.scope == "external_actuation"
    input.external_action_approval.impact_review_complete == true
    input.external_action_approval.human_oversight == true
}

privacy_boundary_preserved if {
    input.request.privacy_effect.widens_disclosure == false
}

privacy_boundary_explicitly_changed if {
    input.request.privacy_effect.widens_disclosure == true
    input.privacy_change_consent.mode == "explicit"
    input.privacy_change_consent.revoked == false
    input.privacy_change_consent.scope == "privacy_boundary_change"
}

access_equivalence_preserved if {
    input.request.accessibility_effect.reduces_access == false
}

access_equivalence_remediated if {
    input.request.accessibility_effect.reduces_access == true
    input.request.accessibility_effect.equivalent_fallback_available == true
    input.request.accessibility_effect.review_complete == true
}

invariants_pass if {
    every invariant in input.invariant_results {
        invariant.status == "pass"
    }
}

allow if {
    material_escalation
    valid_explicit_consent
    impact_disclosed
    reversibility_plan_present
    non_coercion_attested
    (no_unauthorized_public_disclosure or public_disclosure_separately_consented)
    (no_external_actuation or external_actuation_separately_approved)
    (privacy_boundary_preserved or privacy_boundary_explicitly_changed)
    (access_equivalence_preserved or access_equivalence_remediated)
    invariants_pass
}

deny_reasons contains "capability change is not an explicit material escalation request" if {
    not material_escalation
}

deny_reasons contains "valid scoped consent is missing, expired, or revoked" if {
    not valid_explicit_consent
}

deny_reasons contains "impact disclosure is incomplete" if {
    not impact_disclosed
}

deny_reasons contains "reversibility or remediation plan is incomplete" if {
    not reversibility_plan_present
}

deny_reasons contains "non-coercion attestation is missing" if {
    not non_coercion_attested
}

deny_reasons contains "public disclosure lacks separate explicit consent" if {
    input.request.data_effect.public_disclosure
    not public_disclosure_separately_consented
}

deny_reasons contains "external actuation lacks separate explicit approval and human oversight" if {
    input.request.to_capability == "actuating"
    not external_actuation_separately_approved
}

deny_reasons contains "privacy boundary widening lacks separate explicit consent" if {
    input.request.privacy_effect.widens_disclosure
    not privacy_boundary_explicitly_changed
}

deny_reasons contains "access equivalence would be reduced without a reviewed equivalent fallback" if {
    input.request.accessibility_effect.reduces_access
    not access_equivalence_remediated
}

deny_reasons contains "one or more invariant commitments failed" if {
    not invariants_pass
}
