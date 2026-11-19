# Optional Check-In Plan Research Protocol

## Purpose

This protocol evaluates whether Hearthline should build an optional, user-
configured, trusted-contact missed-check-in reminder. The research does not
implement emergency monitoring, danger detection, emergency response, location
tracking, automatic reporting, or automatic external escalation.

## Research question

Can adults understand the difference between:
- a user-configured, neutral missed-check-in notification; and
- emergency monitoring, safety certification, danger detection, or guaranteed
  assistance?

## Prototype scope

Use only fictional contacts, fictional check-in times, synthetic missed-check-in
events, and static notification previews.

Do not collect:
- real contact details;
- real phone numbers;
- addresses;
- locations;
- routes;
- meeting details;
- counterpart information;
- profile information;
- intimate context;
- health information;
- identity information;
- emergency-contact information;
- message content.

## Required user-facing statement

"This is an optional reminder you control. Hearthline does not monitor your
encounter, detect danger, track your location, guarantee notification delivery,
or contact emergency services."

## Candidate minimum notification

"A planned check-in was missed. This is an optional reminder created by someone
you know. Please use your own judgment before taking any action."

## Required choices

The user must separately choose:
- whether to configure a plan;
- whether to select a trusted contact;
- what minimal name or pseudonym appears;
- whether the planned time appears;
- whether a self-authored short note appears;
- when the plan expires;
- how to cancel or revoke it.

## Prohibited automatic behavior

- No location sharing.
- No counterpart identity sharing.
- No emergency classification.
- No automatic contact of police, emergency services, family, employer, venue,
  or counterpart.
- No automatic report.
- No automatic message review.
- No safety score.
- No account restriction.
- No discovery, ranking, analytics, advertising, or behavioral-profile use.
- No contact notification without a prior explicit user configuration.

## Stop conditions

- Participants interpret the reminder as emergency monitoring or guaranteed
  safety support.
- The prototype pressures people to configure a contact or reveal meeting
  details.
- Participants cannot clearly cancel or revoke a plan.
- A notification preview implies danger, wrongdoing, or an emergency.
- The object cannot be made accessible through keyboard, screen reader,
  low-bandwidth, text-first, and asynchronous paths.
- The design requires location, counterpart, intimate, health, identity, or
  other unnecessary information.
- The feature creates a pathway to surveillance, coercion, or a value-for-
  intimacy arrangement.

## Next review

Advance only after:
- privacy/security review;
- accessibility review;
- trusted-contact consent model;
- notification-delivery reliability analysis;
- false-alarm and non-delivery analysis;
- retention/deletion model;
- jurisdiction-specific legal review where notification or emergency duties
  may arise;
- explicit human-review and appeal model for any material platform decision.
