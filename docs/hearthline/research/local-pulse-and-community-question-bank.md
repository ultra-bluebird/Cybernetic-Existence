# LocalPulse and CommunityQuestionBank Research Contract

## Primary promises

LocalPulse:
Provide broad, delayed, privacy-thresholded summaries of Hearthline community
activity contexts without showing who is present, nearby, online, active, in a
room, attending an invitation, located in an area, or connected to a particular
person.

CommunityQuestionBank:
Provide optional, non-scored, user-selectable conversation prompts without
turning questions or answers into quizzes, assessments, disclosure demands,
profile-completion requirements, matching inputs, ranking inputs, identity
inference, or behavioral data.

## LocalPulse constraints

- The user-facing object is a community activity summary, not a live local
  presence indicator.
- The Pulse uses only broad manually selected scopes; it does not use GPS,
  IP-derived location, Bluetooth, background location, route, device movement,
  user check-in, or account-linked location history.
- The Pulse uses bands, not raw counts.
- The Pulse applies a minimum population threshold and delayed aggregation.
- The Pulse is suppressed when privacy cannot be protected.
- The Pulse never shows room rosters, individual activity, presence, last-seen
  time, live crowd, nearby people, counterpart activity, sexual-intent
  activity, user availability, identity-group counts, or access-needs counts.
- Pulse queries are not retained as account-linked search or location history.
- Pulse data cannot affect discovery ranking, matching, profile visibility,
  advertising, moderation, eligibility, or behavioral profiling.
- Differential privacy may be considered only after a documented privacy budget,
  composition analysis, utility test, attack model, and independent review.

## CommunityQuestionBank constraints

- Questions are optional, skippable, non-scored, non-required, and
  user-selectable.
- Questions are conversation prompts, not tests, assessments, quizzes,
  surveys, profile-completion tasks, matching inputs, or identity probes.
- Questions and answers do not affect discovery, ranking, recommendation,
  advertising, moderation, eligibility, or behavioral profiling.
- Initial categories are interests, everyday rhythm, public activity, books and
  media, food and drink, small joys, conversation style, learning and making,
  place and atmosphere, boundaries and pace, imagination, and no-answer-needed.
- Questions cannot request identity, health, diagnosis, recovery, substance
  history, finances, housing, employment, criminal history, immigration,
  religion, politics, trauma, body information, location, routine,
  availability, contact details, intimate images, sexual history, sexual role,
  compatibility, risk, morality, or assessment data.
- Community contributions are reviewed before publication.
- Contributor identity is not publicly attributed and does not become a
  contributor reputation, influence, trust, or ranking system.
- Questions are versioned, correctable, removable, accessible, and reviewable.
- A user may answer in their own words, decline, change the subject, or leave
  the conversation without penalty.

## Always-stop conditions

- Pulse reveals or permits inference of presence, identity, activity, location,
  routine, room membership, invitation participation, counterpart connection,
  live availability, or small-group membership.
- Pulse queries become account-linked location or behavioral history.
- Pulse is used for discovery, ranking, matching, advertising, moderation,
  eligibility, payment, or behavioral profiling.
- Raw counts, live counts, repeated-query differencing, or insufficient
  aggregation makes re-identification plausible.
- A Question Bank prompt requires disclosure, pressures a user to answer,
  implies that an answer improves a profile, creates a score, or becomes a
  matching/ranking/identity/health/recovery/financial/sexuality inference input.
- Question answers are automatically saved, indexed, profiled, or reused
  outside the conversation without separate current user choice.
- Contributor identity becomes public or is used as a reputation, influence,
  trust, or quality metric.
- An accessibility-equivalent browse, select, skip, contribute, report,
  correction, and removal path is unavailable.
- The Pulse or Question Bank creates pressure to meet, reveal location, travel,
  become intimate, continue contact, or accept money or other value.

## Permitted measures

- Synthetic suppression, banding, delay, and repeated-query attack tests.
- Synthetic conversation-prompt validation tests.
- Accessibility task-completion tests using fictional scopes and questions.
- Aggregate non-account-linked system health checks.
- Voluntary feedback about privacy, clarity, pressure, accessibility, and
  whether the tools are understood as non-scoring and optional.
- Aggregate content-review, correction, and withdrawal outcomes.

## Prohibited measures

- User location collection.
- Presence tracking.
- Room membership tracking.
- Question-answer analysis.
- Contributor reputation.
- Identity, health, recovery, financial, housing, sexuality, capacity, or
  vulnerability inference.
- Discovery, ranking, advertising, moderation, eligibility, payment, or
  behavioral profiling effects.
- Unconsented message, image, voice, device, behavior, or location analysis.
