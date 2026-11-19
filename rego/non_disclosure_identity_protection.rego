package hearthline.identity.non_disclosure

default allow_claim_read := false
default allow_claim_disclosure := false
default allow_claim_for_matching := false
default allow_claim_for_ranking := false
default allow_claim_for_advertising := false
default allow_claim_for_model_training := false

protected_or_sensitive_claim if {
  input.claim.sensitivity == "sensitive"
}

protected_or_sensitive_claim if {
  input.claim.sensitivity == "protected"
}

claim_is_active if {
  input.claim.state == "active"
}

claim_is_private if {
  input.claim.visibility == "private"
}

owner_reads_own_claim if {
  input.requester.ref == input.claim.ownerRef
}

authorized_internal_claim_service if {
  input.requester.service == "identity_claim_store"
  input.requester.purpose == "member_requested_claim_management"
}

allow_claim_read if {
  claim_is_active
  owner_reads_own_claim
}

allow_claim_read if {
  claim_is_active
  authorized_internal_claim_service
}

recipient_has_active_disclosure if {
  input.disclosure.state == "active"
  input.disclosure.ownerRef == input.claim.ownerRef
  input.disclosure.audienceScope.kind == "specific_member"
  input.disclosure.audienceScope.recipientRef == input.requester.ref
  input.claim.claimId in input.disclosure.fieldRefs
  time.now_ns() < time.parse_rfc3339_ns(input.disclosure.expiresAt)
}

recipient_has_active_consent if {
  input.disclosure.consentGrantState == "granted"
  time.now_ns() < time.parse_rfc3339_ns(input.disclosure.consentExpiresAt)
}

allow_claim_disclosure if {
  claim_is_active
  recipient_has_active_disclosure
  recipient_has_active_consent
  not input.blockOrRestrictionPresent
}

allow_claim_read if {
  allow_claim_disclosure
}

allow_claim_for_matching if {
  not protected_or_sensitive_claim
  input.claim.category == "connection_intent"
  input.claim.visibility == "eligible_discovery_only"
  input.claim.state == "active"
  input.claim.assertionStatus == "self_stated"
}

allow_claim_for_matching if {
  not protected_or_sensitive_claim
  input.claim.category == "activity_interest"
  input.claim.visibility == "eligible_discovery_only"
  input.claim.state == "active"
  input.claim.assertionStatus == "self_stated"
}

allow_claim_for_matching if {
  not protected_or_sensitive_claim
  input.claim.category == "communication_preference"
  input.claim.visibility == "eligible_discovery_only"
  input.claim.state == "active"
  input.claim.assertionStatus == "self_stated"
}

allow_claim_for_ranking if {
  false
}

allow_claim_for_advertising if {
  false
}

allow_claim_for_model_training if {
  false
}
