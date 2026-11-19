# Hearthline Milestone Tracker

## Current Position

**Current milestone:** M1 — Functional Local-First Prototype  
**Current status:** Complete pending independent test execution  
**Recommended next milestone:** M2 — Repository Hardening

## Completed

| ID | Milestone | Status | Evidence |
|---|---|---|---|
| M0 | Product and safety foundation | Complete | Consent-first architecture, non-scoring rules, pacing model, pseudonymity direction, explicit non-goals |
| M1-A | React/Vite demo shell | Complete | Local-first React/Vite project, CSS design system, README, license, local storage |
| M1-B | Candidate exploration | Complete | Demo profiles, declared-preference presentation, mutual-interest behavior |
| M1-C | Privacy controls | Complete | Field-level local consent state, recipient display controls, draft invalidation model |
| M1-D | Pacing controls | Complete | Low-energy mode, manual exploration, pause behavior, visibility windows |
| M1-E | Local drafting support | Complete | Rule-based message assistant, suggestion-only behavior, protected-field awareness |
| M1-F | Security readiness UI | Complete | Browser passkey capability inspection without credential enrollment |
| M1-G | Local action pacing | Complete | Action-specific temporary pacing demonstration without person scoring |
| M1-H | Build verification | Complete | Production Vite builds recorded successfully |
| M1-I | Automated test execution | Pending verification | Test files and script exist; captured test command result required |

## Immediate Verification Checklist

```text
[ ] Run npm ci from a clean dependency directory
[ ] Run npm run test and retain the output
[ ] Run npm run build and retain the output
[ ] Inspect browser network panel for application-originated external requests
[ ] Inspect localStorage keys for prohibited data categories
[ ] Verify reset clears every Hearthline localStorage key
[ ] Verify export preview excludes protected draft and recipient data
[ ] Verify low-energy mode remains keyboard navigable
[ ] Verify pause, block, and privacy controls remain available in each connection state
```

## M2 — Repository Hardening

```text
[ ] Replace generic package metadata with Hearthline Starter metadata
[ ] Remove unused inherited dependencies
[ ] Add linting and formatting checks
[ ] Add continuous integration for install, test, build, lint, and dependency review
[ ] Add security policy
[ ] Add code of conduct
[ ] Add contributor guide
[ ] Add threat model
[ ] Add privacy model
[ ] Add accessibility statement
[ ] Add browser support statement
[ ] Add forbidden-data regression tests
[ ] Add forbidden-network-request regression tests
[ ] Add component-boundary regression tests
[ ] Create first honest public-demo release tag
```

## M3 — Account Security

```text
[ ] Design server WebAuthn registration ceremony
[ ] Design server WebAuthn assertion ceremony
[ ] Require user verification for sensitive operations
[ ] Add secure session design
[ ] Add credential enrollment lifecycle
[ ] Add secondary credential enrollment
[ ] Add credential revocation
[ ] Add account continuity threat model
[ ] Add user-held recovery-code design
[ ] Add optional account-support contact design
[ ] Add independent security review
```

## M4 — Consent Enforcement

```text
[ ] Build CommonGround policy service
[ ] Build per-recipient consent registry
[ ] Enforce field scope at render time
[ ] Enforce field scope at draft-render time
[ ] Enforce field scope at send-preview time
[ ] Enforce field scope at final-send time
[ ] Invalidate queued notifications
[ ] Invalidate exports
[ ] Invalidate stale client cache
[ ] Add cross-device propagation
[ ] Add content-free invalidation receipts
[ ] Add retention and deletion process
```

## M5 — Safe Connection Workflow

```text
[ ] Build durable Waypoint state machine
[ ] Enforce mutual-interest server-side
[ ] Enforce dual confirmation server-side
[ ] Build recipient-scoped persona resolver
[ ] Build block and report workflow
[ ] Build pause and scope-narrowing workflow
[ ] Test concurrent transitions
[ ] Test stale-client transitions
[ ] Test revocation during transition
[ ] Test pause during transition
[ ] Complete user-comprehension study
```

## M6 — Action Integrity

```text
[ ] Build Lantern as a separate service
[ ] Use dedicated data store and service identity
[ ] Deny matching access structurally
[ ] Deny persona access structurally
[ ] Deny AI-chat access structurally
[ ] Implement bounded action windows
[ ] Implement expiry
[ ] Implement review path
[ ] Implement report-abuse protection
[ ] Implement false-positive review
[ ] Conduct accessibility and equity review
[ ] Conduct abuse-case review
[ ] Conduct red-team exercise
```

## M7 — AI-Chat Mediation

```text
[ ] Keep all actions user initiated
[ ] Keep all messages user sent
[ ] Add current-consent scope guard
[ ] Add protected-field invalidation
[ ] Add provider data-processing review
[ ] Add request-retention policy
[ ] Add no-diagnosis policy
[ ] Add no-recovery-inference policy
[ ] Add human-support signposting boundaries
[ ] Add safety evaluation
```

## M8 — Optional Advanced Privacy Features

```text
[ ] Review optional recovery-expression architecture
[ ] Review optional supporter-vouch architecture
[ ] Review optional issuer-attestation architecture
[ ] Review optional identity-guardian architecture
[ ] Review recipient-scoped persona backend
[ ] Verify no public badges
[ ] Verify no matching or filtering use
[ ] Complete cryptographic review before proof support
[ ] Complete coercion-risk review
```

## M9 — Private Pilot

```text
[ ] Publish privacy notice
[ ] Publish known limitations
[ ] Publish incident response path
[ ] Complete threat-model review
[ ] Complete accessibility review
[ ] Complete usability research
[ ] Complete security review
[ ] Complete retention review
[ ] Complete telemetry sink inventory
[ ] Verify no unreviewed third-party SDK access
[ ] Define moderation process
[ ] Define human escalation process
[ ] Recruit bounded design-partner cohort
```

## M10 — Production Readiness

```text
[ ] Independent security assessment
[ ] WebAuthn implementation assessment
[ ] Privacy impact assessment
[ ] Red-team assessment
[ ] Penetration test
[ ] Incident response exercise
[ ] Backup and deletion exercise
[ ] Supply-chain controls
[ ] Production monitoring review
[ ] Legal and jurisdictional review
[ ] Accessibility conformance review
[ ] Governance review for future policy changes
[ ] Public launch checklist complete
```
