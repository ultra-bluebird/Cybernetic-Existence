# POST /compliance/check

## Purpose

Evaluate whether Hearthline may enable a requested in-product capability under the
currently deployed, counsel-reviewed platform policy.

This endpoint does not provide legal advice. It does not determine whether an
offline interaction is lawful, consensual, safe, medically appropriate, or free
from risk.

## Request

```json
{
  "requestId": "compliance_7bY3vK2mQ9pR5xL8",
  "jurisdiction": "US-AZ",
  "operation": "enable_sexual_topic_discussion",
  "participants": [
    {
      "memberRef": "member_A1b2C3d4E5f6G7h8",
      "adultPlatformEligibilityState": "eligible"
    },
    {
      "memberRef": "member_Q8r7S6t5U4v3W2x1",
      "adultPlatformEligibilityState": "eligible"
    }
  ],
  "interactionContext": {
    "consentState": "granted",
    "commercialExchangeState": "none_declared",
    "transportConditionedOnIntimacyState": "none_declared",
    "preciseLocationRequested": false,
    "recordingRequested": false,
    "blockOrRestrictionPresent": false,
    "venueClass": "not_applicable"
  },
  "requestedAt": "2026-09-26T20:45:00Z",
  "policyVersion": "az-adult-consensual-policy-v1"
}
```

## Success response

```json
{
  "status": "allow_platform_operation",
  "reasonCodes": [
    "adult_platform_eligibility_current",
    "active_scoped_consent_present",
    "no_block_or_restriction",
    "noncommercial_boundary_satisfied",
    "no_precise_location_request"
  ],
  "legalReviewRequired": false,
  "userMessage": "This Hearthline feature is available for this interaction. Either person can pause or withdraw permission at any time."
}
```

## Denied response

```json
{
  "status": "deny",
  "reasonCodes": [
    "commercial_or_value_exchange_not_supported"
  ],
  "legalReviewRequired": false,
  "userMessage": "Hearthline does not support exchanges of money, goods, housing, transportation, employment, debt relief, or other material value for social or sexual access."
}
```

## Review-required response

```json
{
  "status": "review_required",
  "reasonCodes": [
    "policy_or_context_requires_human_legal_review"
  ],
  "legalReviewRequired": true,
  "userMessage": "This feature is not available until the platform policy context is reviewed. This message is not legal advice."
}
```

## Required response headers

```text
X-Hearthline-Policy-Version
X-Hearthline-Rule-Set-Id
X-Hearthline-Decision-Id
Cache-Control: no-store
```

## Logging restrictions

The endpoint may write a content-minimized accountability record containing:

- opaque request identifier;
- opaque participant references;
- jurisdiction code;
- requested product operation;
- rule-set and policy versions;
- decision status and reason codes;
- timestamp;
- deletion/retention class.

It must not log:

- message contents;
- photographs or media;
- date of birth;
- identity-document information;
- exact or historical location;
- venue history;
- contact books or social graph;
- private preference details;
- health, sexuality, finances, housing, employment, or inferred vulnerability;
- a member-level legal or risk label.
