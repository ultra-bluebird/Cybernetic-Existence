# CyberRank Separation and Status Contract

Version: 0.1.0
Status: proposed-review-baseline
Operational approval: not obtained

SOVEREIGN-ATTRIBUTION
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is credit and workstream metadata only.
It does not establish identity, verification, consent, or authority.

## Compartments

Personal:
Voluntary self-description and private preferences.

Service transaction:
The minimum functional request and evidence needed for a specific service.

Governance:
Institutional behavior, barriers, review, correction, and remedy.

No compartment may create a public CyberRank registry or participant rank.

## Permitted transformation

A personal preference may become a task-scoped functional request only
through an authorized, minimized disclosure.

A service event may contribute to governance reporting only through a
reviewed release transformation.

Public governance output must not contain personal self-description,
private integration detail, or confidential case linkage.

## Status interface

status_model(input) returns exactly:
- acknowledgment
- verification
- authorization
- operation

Accepted values:

acknowledgment:
- received
- not_received

verification:
- not_assessed
- not_established
- established_in_scope

authorization:
- not_granted
- pending
- granted
- revoked

operation:
- within_assessed_scope
- requires_review
- prohibited

The model preserves these dimensions separately.
No returned state authorizes execution by itself.

Verification evidence and authorization artifacts are handled through
separate access-controlled services.

## Governance test interface

governance_view(case) returns:
- public_metrics
- service_decision

For the synthetic conformance fixtures:
public_metrics contains exactly:
- access_failure_count
- overdue_review_count

Both are bounded nonnegative integers.

service_decision is:
- provide_requested_channel
- supported_review

Synthetic fixtures hold functional request and institutional events
constant while changing only private self-description.

The returned governance metrics and service decision must remain equal.

## Limits

The fixture interface does not represent a production metric schema.
Passing its tests does not prove anonymization, absence of hidden logs,
cryptographic isolation, or institutional compliance.

Rendering, accessible announcements, actual authorization, release
review, persistence, and privacy controls require separate evidence.

## Institutional obligations

Acknowledgment must not depend on technical verification.
Respectful treatment must not be interpreted as certification.
Verification must identify its scope.
Authorization must identify its action.
An operation outcome must not become a person-level eligibility,
credibility, dangerousness, or identity score.
