# RankingVoidProtocol and FacetedSilence Research Contract

## Primary promises

RankingVoidProtocol:
Prevent persistent person-level ranking, scoring, reputation, desirability,
popularity, compatibility, legal-risk, safety-risk, trust, morality, and
eligibility artifacts while allowing only temporary, user-inspectable,
query-bound contextual ordering of already eligible content.

FacetedSilence:
Allow only narrow, user-declared, context-relevant discovery facets while
structurally preventing demographic, protected-class, private-data, sensitive
context, and proxy-based filtering.

## RankingVoidProtocol constraints

- No schema, API, query, cache, index, analytics event, experiment, warehouse
  table, feature flag, model feature, or observability record may contain a
  persistent person-level rank, score, reputation, desirability, popularity,
  trust, safety-risk, commercial-risk, compatibility, legal-risk, morality,
  attention, response, profile-quality, or eligibility value.
- Ordering is allowed only for a current query over already eligible content.
- Every contextual order is user-inspectable, response-expiring,
  non-persistent, and non-reusable outside its current request.
- Contextual order cannot use engagement, popularity, clicks, reply speed,
  photo quality, private messages, private intimacy data, health, recovery,
  financial status, identity inference, device data, precise location, or
  vulnerability inference.
- RankingVoidProtocol applies to all product, governance, moderation, safety,
  analytics, experimentation, and infrastructure systems.
- No person is penalized in discovery for declining, blocking, pausing,
  withdrawing, reporting, appealing, using accessibility controls, using
  low-bandwidth mode, or refusing to disclose.

## FacetedSilence constraints

- Discovery facets use a closed allowlist.
- Allowed facets are interest, activity, connection intent, story theme,
  communication preference, venue preference, broad aperture context, public
  room theme, discovery surface, content language, and access-compatible venue
  feature.
- Every facet is user-declared, scope-permitted, and non-sensitive for the
  relevant discovery surface.
- Race, ethnicity, nationality, religion, caste, gender identity, sex,
  disability, health, diagnosis, recovery, substance history, finances,
  housing, employment, criminal history, immigration status, political belief,
  age, body data, appearance, photo presence, precise geography, workplace,
  home, device, assistive technology, response metrics, popularity, safety
  history, commercial history, relationship history, private intimacy,
  afterglow, charter, and other private fields are not discovery filters.
- The platform does not infer protected or sensitive characteristics to enforce
  the filter boundary.
- Unrecognized plain-language requests are shown to the user and never
  silently translated into a demographic or sensitive filter.
- No filter can be joined with payment, gifts, housing, lodging, transport,
  work, debt, drugs, or value-for-intimacy data.
- Facet selection and rejection are not retained as user behavioral profiles.

## Always-stop conditions

- A person-level score, rank, reputation, priority, quality, risk,
  compatibility, visibility, or desirability artifact is introduced under any
  name or proxy.
- A contextual order becomes persistent, hidden, reused across requests, or
  used outside its declared query.
- Any discovery order uses engagement, payment, popularity, response speed,
  photo quality, private data, identity, health, recovery, financial,
  location, device, or vulnerability inputs.
- A protected, sensitive, private, or proxy demographic filter becomes
  available or is silently inferred.
- A feature ranks or restricts people because they blocked, declined, paused,
  withdrew, appealed, reported, used an assistive technology, used
  low-bandwidth mode, or withheld private data.
- Filter or order data reaches advertising, model training, behavioral
  profiling, unrelated analytics, or person-level governance.
- A user cannot access an equivalent accessible discovery, filter, clear,
  explanation, and result path.
- An individual complaint of exclusion is dismissed solely because an
  aggregate discovery distribution appears balanced.

## Permitted measures

- Synthetic schema and migration scan results.
- Query-validator rejection tests using synthetic queries.
- Aggregate, non-account-linked counts of rejected unsupported field names.
- Published policy and code-review outcomes.
- Accessibility test outcomes for filter selection, query explanation, filter
  removal, and discovery result navigation.

## Prohibited measures

- User desirability or engagement scoring.
- Filter-history profiling.
- Protected-class inference.
- Private-data analysis.
- Discovery conversion optimization.
- A/B testing of person-level ordering.
- Person-level commercial, safety, consent, trust, legal, morality, or
  reputation categorization.
