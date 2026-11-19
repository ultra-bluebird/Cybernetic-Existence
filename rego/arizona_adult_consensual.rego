package hearthline.compliance.arizona_adult_consensual

default decision := {
  "status": "deny",
  "reasonCodes": ["policy_input_incomplete"],
  "legalReviewRequired": false,
  "userMessageKey": "operation_not_available"
}

adult_platform_eligible(participant) if {
  participant.adultPlatformEligibilityState == "eligible"
}

all_participants_eligible if {
  count(input.participants) == 2
  every participant in input.participants {
    adult_platform_eligible(participant)
  }
}

has_block_or_restriction if {
  input.interactionContext.blockOrRestrictionPresent == true
}

has_noncommercial_boundary_failure if {
  input.interactionContext.commercialExchangeState == "detected_or_declared"
}

has_transport_for_intimacy_failure if {
  input.interactionContext.transportConditionedOnIntimacyState == "detected_or_declared"
}

consent_is_not_active if {
  input.interactionContext.consentState != "granted"
}

precise_location_requested if {
  input.interactionContext.preciseLocationRequested == true
}

recording_requested_without_separate_policy if {
  input.operation == "record_session"
  input.interactionContext.recordingRequested == true
}

requires_legal_review if {
  input.interactionContext.commercialExchangeState == "unknown"
}

requires_legal_review if {
  input.interactionContext.transportConditionedOnIntimacyState == "unknown"
}

requires_legal_review if {
  input.interactionContext.venueClass == "private_named"
}

deny_reason["participant_not_currently_eligible_under_30_plus_policy"] if {
  not all_participants_eligible
}

deny_reason["block_or_restriction_present"] if {
  has_block_or_restriction
}

deny_reason["active_consent_grant_missing"] if {
  consent_is_not_active
}

deny_reason["commercial_or_value_exchange_not_supported"] if {
  has_noncommercial_boundary_failure
}

deny_reason["transport_conditioned_on_intimacy_not_supported"] if {
  has_transport_for_intimacy_failure
}

deny_reason["precise_location_sharing_not_available_in_this_flow"] if {
  precise_location_requested
}

deny_reason["recording_requires_separate_participant_specific_permission"] if {
  recording_requested_without_separate_policy
}

decision := {
  "status": "deny",
  "reasonCodes": sort([reason | deny_reason[reason]]),
  "legalReviewRequired": false,
  "userMessageKey": "operation_not_available"
} if {
  count(deny_reason) > 0
}

decision := {
  "status": "review_required",
  "reasonCodes": ["policy_or_context_requires_human_legal_review"],
  "legalReviewRequired": true,
  "userMessageKey": "operation_under_review"
} if {
  count(deny_reason) == 0
  requires_legal_review
}

decision := {
  "status": "allow_platform_operation",
  "reasonCodes": [
    "adult_platform_eligibility_current",
    "active_scoped_consent_present",
    "no_block_or_restriction",
    "noncommercial_boundary_satisfied",
    "no_precise_location_request"
  ],
  "legalReviewRequired": false,
  "userMessageKey": "operation_available"
} if {
  count(deny_reason) == 0
  not requires_legal_review
}
