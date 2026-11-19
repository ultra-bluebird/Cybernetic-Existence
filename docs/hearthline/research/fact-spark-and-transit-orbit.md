# FactSparkGenerator and TransitOrbit Research Contract

## Primary promises

FactSparkGenerator:
Provide optional, client-side conversation prompts that help an adult write
their own details in their own words without Hearthline generating facts,
inventing personal information, inferring private meaning, publishing content,
or using drafts as discovery, matching, ranking, advertising, analytics, or
profile data.

TransitOrbit:
Provide user-selected public transit and public-place context to support
independent, low-cost, public, transit-aware meeting-place exploration without
collecting user location, workplace, home, route, travel history, device
movement, meeting intent, counterpart location, or account-linked transit
selection history.

## FactSparkGenerator constraints

- The user-facing object is a conversation prompt library, not an AI fact
  generator.
- Hearthline supplies optional prompts; the user authors all content.
- Hearthline does not invent, infer, rewrite as fact, summarize as fact,
  autofill, auto-send, auto-publish, or auto-save user details.
- Drafts are local-only, network-disabled, session-scoped by default, and
  user-deletable.
- Drafts do not become profile fields, story chapters, message content,
  search terms, matching inputs, ranking inputs, advertising data, analytics,
  model-training data, or behavioral profile data unless the user separately
  makes an explicit current publication choice.
- Prompt themes exclude identity verification, health, diagnosis, recovery,
  substance history, finances, housing, employment, criminal history,
  immigration, routine, availability, location, contact information, sexual
  history, body information, intimate images, trauma, personality assessment,
  compatibility, risk, and scoring.
- A user may skip a prompt, write nothing, change the subject, or delete a
  draft without any completion penalty.

## TransitOrbit constraints

- TransitOrbit uses only public transit and public-place context.
- A user manually selects a transit line and broad area; no GPS, IP-derived
  location, background location, device movement, Bluetooth proximity, route
  history, home, workplace, or counterpart location is requested or inferred.
- Transit selections are not retained as account-linked history.
- Results are public places with source-labeled transit, cost, public-access,
  accessibility, and sensory context, not personalized route plans.
- TransitOrbit does not predict travel time from a user origin, determine
  whether a user can afford transit, infer vehicle ownership, infer routine,
  infer meeting intent, show nearby people, or create a meeting plan.
- Venue context is reported, source-dated, and non-certifying; it never
  guarantees safety, accessibility, service availability, inclusion, privacy,
  or appropriateness for a particular person.
- TransitOrbit does not use discovery, ranking, matching, advertising,
  moderation, eligibility, payment, or behavioral profiling inputs or outputs.
- Public-source data changes are versioned and reviewed before publication.

## Always-stop conditions

- FactSpark drafts leave the device, enter logs, synchronize, are used for
  analytics, model training, discovery, ranking, matching, advertising,
  moderation, eligibility, or platform profiling.
- Hearthline invents, infers, represents, or publishes a personal fact without
  a separate explicit user action.
- A prompt pressures identity, health, recovery, finance, housing, employment,
  routine, availability, location, sexuality, body, trauma, medical, or
  intimate disclosure.
- TransitOrbit collects, infers, stores, or exposes user location, route,
  travel history, workplace, home, device movement, counterpart location,
  meeting intent, vehicle ownership, or account-linked line-selection history.
- TransitOrbit gives personalized routing, live transit monitoring, venue
  safety certification, real-time presence, dating-success, or availability
  signals without a separately reviewed design.
- Venue or transit context becomes a discovery, ranking, advertising,
  moderation, payment, eligibility, or behavioral-profiling signal.
- A user is pressured to travel, reveal a transit line, meet, accept a ride,
  host, disclose location, become intimate, continue contact, or accept money
  or other value.
- An accessibility-equivalent prompt, draft, delete, transit-search, filter,
  text-first, low-bandwidth, keyboard, and screen-reader path is unavailable.
- A claim about data freshness, access, privacy, or transit service exceeds
  verified implementation or source evidence.

## Permitted measures

- Synthetic local-only network-isolation tests for FactSpark drafts.
- Synthetic prompt-content validation.
- Synthetic transit-place schema validation.
- Public-source freshness checks.
- Accessibility task-completion tests using fictional prompts and places.
- Voluntary feedback about clarity, pressure, privacy, accessibility, and
  whether the tools are understood as user-authored/public-context tools.

## Prohibited measures

- Draft-content analysis.
- Personal fact inference.
- Profile completion tracking.
- User location collection.
- Route or travel-history tracking.
- Meeting-intent prediction.
- Identity, health, recovery, financial, housing, capacity, sexuality, or
  vulnerability inference.
- Discovery, ranking, advertising, moderation, eligibility, payment, or
  behavioral profiling effects.
- Unconsented message, image, voice, device, behavior, or location analysis.
