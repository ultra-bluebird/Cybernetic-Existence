# PrivacyBoundaryEnforcer and AccessibilityAdapterLayer Research Contract

## Primary promises

PrivacyBoundaryEnforcer:
Enforce field-level disclosure boundaries through object-local, purpose-scoped,
fail-closed authorization at the query and data-projection layers without using
global viewer identifiers, user profiling, sensitive inference, content logging,
or broad client-accessible privacy-resolution APIs.

AccessibilityAdapterLayer:
Require direct or equivalent accessible paths for every essential Hearthline
outcome without inferring a person's modality, disability, device, bandwidth,
health, identity, capacity, or communication method and without requiring
voice, vision, hearing, fine motor control, camera, high bandwidth, or
real-time response.

## PrivacyBoundaryEnforcer constraints

- Scope resolution uses object reference, field reference, requester capability,
  requested purpose, access context, current time, and correlation boundary.
- Scope resolution does not use global viewer IDs, actor IDs, account IDs,
  profile IDs, counterpart IDs, device IDs, IP addresses, location, raw
  content, sensitive field values, or identity categories.
- Scope resolution is fail-closed.
- Base sensitive tables are inaccessible to ordinary application roles.
- Accessed field projections are limited to fields allowed by the current
  object-local capability and purpose.
- Unknown scope, expired scope, revoked scope, missing capability, purpose
  mismatch, or correlation-boundary mismatch excludes the field.
- Local-only objects do not enter scope-resolution services, server queries, or
  bus channels.
- Privacy violation records contain only a short-lived violation reference,
  rule ID, object family, requested purpose, outcome, timestamp, retention
  expiry, and explicit absence of user identity, raw content, field values, and
  global correlation.
- Violation records cannot be used for discovery, ranking, advertising,
  analytics, moderation scoring, eligibility, identity inference, or
  behavioral profiling.

## AccessibilityAdapterLayer constraints

- Accessibility parity is defined by equivalent essential outcomes, not visual
  similarity or one renderer per modality.
- Every interactive web primitive has a keyboard-operable path.
- Every essential outcome has screen-reader semantics, text-first output,
  non-color state communication, low-bandwidth equivalent, asynchronous
  equivalent where needed, and human fallback for critical failures.
- Voice input and audio output are optional enhancements only; they are never
  required, inferred, or silently activated.
- Captions, transcripts, and text alternatives are available wherever
  audio/video interaction is offered.
- The platform does not infer or record screen-reader use, keyboard use, voice
  use, reduced motion, text resize, bandwidth class, device type, or assistive
  technology.
- A user-selected local presentation preference cannot affect discovery,
  ranking, matching, advertising, moderation, eligibility, profile visibility,
  payment, or behavioral profiling.
- Registry completeness is supplemented by manual keyboard, screen-reader,
  low-bandwidth, reduced-motion, text-resize, and human-fallback testing.

## Always-stop conditions

- A field is returned without a current object-local scope decision.
- A scope failure falls back to broader visibility, cached access, prior access,
  inferred identity, or default allow.
- A privacy-resolution endpoint is publicly available for arbitrary object or
  field probing.
- Privacy violations include user identity, raw content, field values,
  counterpart references, device data, location, profile data, or global
  correlation identifiers.
- Privacy scope, access preference, or adapter choice affects discovery,
  ranking, advertising, moderation, eligibility, payment, profile visibility,
  or behavioral profiling.
- A critical outcome lacks direct or equivalent keyboard, screen-reader,
  text-first, low-bandwidth, asynchronous, pause, revoke, delete, report,
  appeal, or human-fallback control.
- Voice, vision, hearing, camera, fine motor control, high bandwidth, or
  synchronous response is required for a critical outcome.
- A feature is released because adapters are declared despite failed manual or
  participant accessibility evidence.
- A user is forced to disclose an access need or modality to obtain equivalent
  access.
- Any privacy or accessibility claim exceeds verified implementation evidence.

## Permitted measures

- Synthetic scope-resolution allow/deny tests.
- Synthetic privacy-projection and fail-closed query tests.
- Aggregate short-lived violation category counts with small-cell suppression.
- Static primitive registry validation.
- Synthetic keyboard, screen-reader semantics, low-bandwidth, text-resize,
  reduced-motion, and human-fallback task tests.
- Voluntary feedback about clarity, privacy, access burden, and control.

## Prohibited measures

- Global viewer tracking.
- Privacy probing history.
- Sensitive-field access profiling.
- Modality detection.
- Assistive-technology inference.
- Access-path ranking.
- User identity, health, recovery, sexuality, financial, housing, capacity, or
  vulnerability inference.
- Discovery, ranking, advertising, moderation, eligibility, payment, or
  behavioral profiling effects.
- Unconsented message, image, voice, device, behavior, location, or private
  field analysis.
