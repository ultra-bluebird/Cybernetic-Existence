# DiscoveryInterleave and QueryIntentTranslator Research Contract

## Primary promises

DiscoveryInterleave:
Distribute visible discovery slots among user-selected Hearthline surfaces using
published user weights and per-surface caps, without engagement optimization,
popularity ranking, profile scoring, hidden preference modeling, or sensitive
data use.

QueryIntentTranslator:
Translate a user's current plain-language discovery request into a visible,
editable, user-confirmed structured query using only a closed public vocabulary
and without inferring identity, health, recovery, finances, housing, capacity,
vulnerability, sexuality, private intimacy preferences, or precise location.

## DiscoveryInterleave constraints

- Interleaving occurs only after eligible content is determined.
- Interleaving cannot alter discovery eligibility.
- Surface weights are user-selected for the current session.
- Default weights and caps are published and inspectable.
- No surface may exceed its configured cap.
- No surface receives an automatic engagement, popularity, click-through,
  response-speed, photo-quality, conversion, or premium-payment boost.
- Story, affinity, invitation, room, and mutually permitted broad aperture
  context are the only supported discovery surfaces.
- Private intimacy, rhythm, ethics, logistics, afterglow, consent, reports,
  compliance, messages, precise location, and payment/value data are excluded.
- Aperture context is coarse, user-declared, mutually permitted, non-real-time,
  and suppressed when population thresholds cannot protect privacy.
- No persistent server-side interleave history exists by default.
- No A/B test changes weights, caps, or surface allocation without explicit
  research consent.

## QueryIntentTranslator constraints

- Translation begins locally from the user's current input.
- The translator uses a versioned, deterministic, closed phrase vocabulary.
- Every recognized term is shown with source text, field, and value.
- Every unrecognized term is shown rather than guessed.
- The structured query is not executed until the user confirms or edits it.
- Raw query text is not retained, logged, analyzed, exported, used for
  advertising, used for ranking, or used for model training.
- Confirmed query state is session-scoped unless the user separately chooses a
  deletable saved-search feature.
- The translator cannot infer or generate identity, health, disability,
  recovery, sexuality, finances, housing, employment, criminal history,
  capacity, vulnerability, precise location, workplace, home, intimate role,
  sexual preference, or real-time availability.
- The translator cannot create a housing, lodging, money, gift, work, debt,
  transport, drugs, or value-for-intimacy query.
- A query can be discarded without a search or record.

## Always-stop conditions

- Interleaving uses hidden weights, engagement data, popularity, response
  speed, private data, inferred attributes, payment status, or a person-level
  score.
- A surface routinely exceeds its published cap or systematically deprives
  another enabled surface of promised exposure.
- Interleave settings become a discovery score, profile label, advertising
  signal, or behavioral profile.
- Aperture context exposes a routine, real-time availability, precise location,
  or a small-population user.
- Raw queries leave the browser before confirmation, enter logs, or become
  retained behavioral data.
- The translator executes a query without user confirmation.
- The translator silently infers a sensitive attribute or turns personal
  circumstances into a search filter.
- A translator output creates a value-for-intimacy, housing-for-intimacy,
  transport-for-intimacy, work-for-intimacy, debt-for-intimacy, or
  payment-for-intimacy path.
- An accessibility-equivalent query compose, review, edit, confirm, discard,
  and results path is unavailable.
- An individual report of query or discovery harm is dismissed solely because
  aggregate interleave statistics appear balanced.

## Permitted measures

- Explicit participant feedback about query-understanding and allocation
  clarity.
- Aggregate, non-account-linked completion outcomes from synthetic research
  scenarios.
- Surface-cap verification results.
- Privacy-thresholded aggregate availability of surface content.
- Accessibility task-completion outcomes using synthetic queries and accounts.

## Prohibited measures

- Raw query retention.
- Query-content analytics.
- Search-history profiling.
- Engagement optimization.
- Response or match conversion ranking.
- Sensitive attribute inference.
- Private-intimacy or rhythm sorting.
- Identity, health, recovery, financial, housing, location, sexuality,
  capacity, or vulnerability inference.
- A/B testing without explicit research consent.
