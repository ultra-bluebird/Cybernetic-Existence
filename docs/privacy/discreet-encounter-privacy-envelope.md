# Discreet Encounter Privacy Envelope

## Purpose

The Discreet Encounter Privacy Envelope lets an adult decide what limited,
recipient-specific information is visible while exploring an optional connection
or planning a public-first meeting.

It is not a location-sharing system, a live-presence system, a proximity matcher,
a route planner, an attendance record, a safety score, or an evidence of consent
to any later activity.

## State transitions

```text
DRAFT
  └─ owner explicitly activates a selected scope
       ↓
ACTIVE
  ├─ owner pauses → PAUSED_BY_OWNER
  ├─ owner revokes → REVOKED
  ├─ either participant cancels plan → CANCELLED
  ├─ expiry time passes → EXPIRED
  └─ both participants complete the required consent checkpoint
       ↓
NEXT_DISCLOSURE_LEVEL_PROPOSED
  ├─ either participant declines or does nothing → ACTIVE at prior level
  ├─ either participant blocks → REVOKED for counterpart
  └─ both independently accept the specific new scope
       ↓
ACTIVE at next disclosure level
```

## Required constraints

1. No level may reveal live or historical location.
2. No level may reveal a home, work, routine, route, or travel origin.
3. No named venue may be exposed before a separate mutual venue checkpoint.
4. Named venue sharing must be recipient-scoped, time-limited, and revocable.
5. A venue detail must not enter candidate generation, analytics profiles, or
   future matching.
6. Independent arrival and departure are optional planning preferences, not
   conditions of meeting.
7. A person may reduce disclosure level or revoke individual scope at any time.
8. A revocation invalidates UI projections, caches, queues, links, and tokens
   before any further delivery.
9. The platform must offer a non-location alternative for every feature.
10. No disclosure level creates an obligation to reply, meet, travel, share
    a private venue, touch, record, or engage in intimacy.

## Member-facing explanation

> You control what is shared in this plan. Hearthline does not use live
> location, location history, routes, venue visits, nearby status, or device
> proximity. A shared activity or venue detail is not permission for anything
> beyond the detail you chose to share.
