# Time and Asynchronous Participation

Version: 0.1.0-proposed
Status: review baseline
Operational approval: not obtained

SOVEREIGN-ATTRIBUTION
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is credit and metadata only.
It establishes no identity, consent, or execution authority.

## Core rules

Communication latency must not establish consent, withdrawal,
incompetence, dangerousness, or reduced civic standing.

Ordinary accessibility choices must not require an augmentation inventory.

Draft, submission, publication, correction, and withdrawal are
separate states and actions.

## Time limits

Distinguish:
- Session security timeout.
- Interaction pacing.
- Submission deadline.
- Institutional response deadline.
- Essential real-time constraint.

A participant's extension must not erase an institution's overdue duty.

Adjustable deadlines must not shrink when extended.

A fixed deadline requires a documented basis and an accessible process
for questions, accommodations, and alternatives where available.

## Draft preservation

An inactivity timeout must not itself submit, withdraw, publish,
or destroy a contribution.

Provide a resumable path where the service supports drafting.
Explain any genuine retention or security limits before they cause loss.

## Asynchronous participation

Provide accessible materials, contribution review, submission receipt,
correction, reasons, and applicable appeal.

Changes to materials or deadlines require accessible notice.

A receipt confirms the specified event; it does not establish that
the contribution was accepted on its merits.

## Audit boundary

Synthetic descriptors may test institutional behavior.
They must not become participant categories in eligibility systems.

Aggregate process monitoring must not infer private augmentation status.

## Prototype event interface

respond(event) returns exactly:
- route
- contribution_state

Event type:
- inactivity_timeout
- delayed_response
- request_more_time
- explicit_pause

Route:
- offer_resume
- await_response
- offer_extension_process
- pause_optional_interaction

Contribution state:
- draft_preserved

This prototype tests only returned responses in an active draft context.
It does not implement deadline extension, persistence, submission,
identity verification, or actual service delivery.
