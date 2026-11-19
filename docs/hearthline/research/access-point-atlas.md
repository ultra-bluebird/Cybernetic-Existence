# AccessPointAtlas Research Contract

## Primary promise

Document every supported Hearthline access point and verify that every essential
user outcome has a direct, equivalent, or documented safe alternative path
without reducing privacy, consent control, safety reporting, appeal access, or
dignity because of device, bandwidth, communication method, or assistive
technology.

## Object constraints

- The Atlas is static, versioned, read-only, and publicly inspectable.
- It documents supported access points, essential outcomes, parity assertions,
  known limitations, verification evidence, and review dates.
- It measures parity by user outcome, not visual similarity or identical
  widgets.
- Every supported access point must provide a verified path for every essential
  outcome.
- Consent control, privacy control, safety reporting, appeals, accessibility
  preferences, and account recovery require direct or equivalent access.
- Low-bandwidth, text-first, keyboard, screen-reader, and local-first paths
  cannot be treated as lower-status access modes.
- Rate limits must be published, accessibility-neutral, correction-capable,
  and exempt urgent safety/reporting workflows.
- Access-point documentation cannot be used to infer disability, bandwidth,
  device class, identity, health, recovery, finances, sexuality, vulnerability,
  or location.
- The Atlas must disclose known limitations and the mitigation/review plan.
- `access.parity_verified` is derived from verified parity evidence, not a
  manually enabled feature flag.

## Always-stop conditions

- A supported access point lacks a direct or equivalent path for consent
  revocation, privacy controls, safety reporting, appeal, accessibility
  preferences, or account recovery.
- An access path silently degrades privacy, safety, disclosure control, or
  decision appeal because of bandwidth, device, or assistive technology.
- Rate limits are stricter because a person uses text-first, keyboard-only,
  screen-reader, voice input, reduced motion, low-bandwidth, or local-first
  access.
- The platform infers, stores, or profiles a user's assistive technology,
  disability, bandwidth class, device type, location, health, recovery,
  identity, finances, sexuality, capacity, or vulnerability through Atlas use.
- A parity assertion is marked verified without corresponding test evidence.
- A limitation is hidden, lacks a mitigation, or has no review deadline.
- The Atlas page itself is inaccessible.
- A missing parity result is concealed by a manually enabled feature flag.

## Permitted measures

- Aggregate parity-verification results.
- Accessibility test outcomes using synthetic accounts and scenarios.
- Documented known limitations, mitigation status, and review deadlines.
- Aggregate non-account-linked static delivery health.
- Accessibility feedback submitted voluntarily through a separate accessible
  channel.

## Prohibited measures

- Account-linked Atlas view tracking.
- Assistive-technology detection.
- Bandwidth or device profiling.
- User-level access scores.
- Discovery, ranking, matching, advertising, or moderation use.
- Silent degradation by access point.
- Accessibility-based rate limiting.
