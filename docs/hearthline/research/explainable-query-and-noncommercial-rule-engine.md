# ExplainableQueryPlanner and NonCommercialRuleEngine Research Contract

## Primary promises

ExplainableQueryPlanner:
Provide a current, response-local, human-readable explanation for a visible
discovery result using only the current user's authorized discovery inputs and
the minimum non-sensitive overlap category needed to explain the result, without
revealing another person's private data, building a recommendation profile,
persisting explanation history, or converting explanations into ranking,
identity, health, intimacy, location, or behavioral inference.

NonCommercialRuleEngine:
Evaluate only reporter-selected excerpts for narrow, versioned,
value-plus-intimacy-plus-condition patterns that require human review, without
continuous private-message scanning, profile scanning, identity inference,
legal conclusion, trafficking determination, safety scoring, commercial-user
labeling, automated penalty, or external action.

## ExplainableQueryPlanner constraints

- Plans are generated only for discovery results currently visible through a
  current permitted discovery response.
- Plans are response-local, short-lived, non-persistent, non-exported, and
  excluded from analytics, profiles, search history, model training, ranking,
  advertising, moderation, eligibility, and behavioral profiling.
- Plans use only eligible-by-current-scope, interest match, public story theme,
  public activity type, room theme, broad planning context, rotation context,
  and manually selected broad area.
- Plans reveal only category-level overlap and current user-authorized inputs.
- Plans never reveal another person's hidden interests, private story content,
  participation history, message content, timing, schedule, availability,
  exact region, distance, route, location, privacy state, health, recovery,
  identity, sexuality, private intimacy, body, device, assistive technology,
  response speed, popularity, risk, trust, safety, desirability, or
  compatibility score.
- A user may correct only their own discovery inputs.
- Explanation cannot change visibility, eligibility, ordering, ranking,
  matching, profile state, or another person's data.

## NonCommercialRuleEngine constraints

- Rules run only after a reporter explicitly submits a bounded,
  reporter-selected excerpt through a report workflow.
- Rules never receive continuous message streams, profiles, images, voice,
  video, location, private preferences, local reflections, health data,
  identity data, financial profile data, or unrelated conversation content.
- Rules require a value term, intimacy term, and conditional-link term.
- A rule output is a human-review flag, not a legal conclusion, safety score,
  trafficking determination, consent determination, identity label,
  commercial-user label, or automatic action.
- Any material platform action requires trained human review, explanation,
  accessible correction, and appeal.
- Rule flags are purpose-limited, retention-bounded, excluded from discovery,
  ranking, advertising, model training, moderation scoring, eligibility, and
  behavioral profiling.
- Clarification reminders or non-commercial preference statements are never
  used as evidence about actual conduct or rule-engine outcomes.
- Rule versions are documented, reviewed, diffable, and subject to policy,
  privacy, accessibility, and legal review.
- Exact rule syntax may be restricted where publication would materially enable
  evasion, but rule categories, scope, limitations, human-review requirement,
  and appeal policy remain publicly explainable.

## Always-stop conditions

- A plan reveals a private field, exact time, exact location, counterpart
  schedule, counterpart activity, identity, health, recovery, sexuality,
  private intimacy, device, accessibility use, response timing, popularity, or
  person-level score.
- Plans are retained, profiled, used for ranking, used for advertising, or
  used to modify discovery.
- A rule engine evaluates content not explicitly submitted by a reporter.
- A rule engine scans streams, profiles, local notes, media, voice, images, or
  private sensitive objects.
- A rule output automatically removes content, restricts an account, suppresses
  discovery, creates a user label, generates a legal conclusion, determines
  trafficking, determines consent, or contacts an outside party.
- Reported excerpts or flags enter discovery, ranking, advertising, model
  training, moderation scoring, eligibility, or behavioral profiling.
- A user cannot access an equivalent accessible explanation, report,
  correction, appeal, and human-review path.
- A feature creates pressure to disclose, meet, travel, become intimate,
  continue contact, accept a ride, host, or accept money or other value.
- Any privacy, explanation, legal, safety, or enforcement claim exceeds
  verified implementation evidence.

## Permitted measures

- Synthetic plan-generation and prohibited-predicate tests.
- Synthetic response-expiry and non-persistence tests.
- Synthetic reporter-submission and bounded-excerpt tests.
- Synthetic rule-match, no-match, rule-version, retention, and human-review
  routing tests.
- Accessibility tests using fictional discovery results and reported excerpts.
- Aggregate, privacy-thresholded rule-category and correction outcomes.
- Voluntary feedback about explanation clarity, privacy, pressure, and appeal.

## Prohibited measures

- Explanation-history tracking.
- Discovery or ranking optimization from explanation data.
- Continuous conversation surveillance.
- Identity, health, recovery, financial, housing, sexuality, capacity, or
  vulnerability inference.
- Commercial-user, safety, consent, trust, risk, morality, or desirability
  scoring.
- Automated penalties or external action.
- Unconsented message, image, voice, device, behavior, location, or private
  field analysis.
