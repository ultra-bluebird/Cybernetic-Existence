# SortFunctionWeave and FlagFeatureGarden Research Contract

## Primary promises

SortFunctionWeave:
Give users meaningful, visible control over the ordering of eligible discovery
results without using a hidden universal ranking, machine-learned preference
model, popularity score, response-speed score, private intimacy data, or
inferred personal attributes.

FlagFeatureGarden:
Make user-affecting Hearthline feature flags visible, plainly explained,
time-bounded, reviewable, accessible, and consent-governed rather than silently
altering user experience or enrolling people in undisclosed experiments.

## SortFunctionWeave constraints

- Eligibility is determined before sorting.
- Sorting cannot change eligibility.
- The default sort is transparent rotation, not popularity or engagement.
- Every available sort has a plain-language explanation of inputs and excluded
  inputs.
- Sort history is not persisted server-side.
- Interest sorting uses only explicitly selected and visible interest data.
- Aperture context uses only mutually allowed broad availability context.
- Room sorting uses themes only, never message content, activity volume,
  popularity, or social influence.
- Rhythm, intimate palette, afterglow, private charter, consent stair,
  logistics, private messages, health, recovery, financial status, identity,
  device, precise location, and inferred attributes are excluded.
- No A/B testing, silent sort changes, engagement optimization, or hidden
  weights are allowed.

## FlagFeatureGarden constraints

- All user-affecting flags are user-visible and plainly explained.
- Research flags require explicit research consent.
- Intimacy flags require explicit opt-in.
- Flags have purpose, scope, expiry, data impact, accessibility impact,
  consent requirement, review state, and external-action prohibition.
- Flags cannot expand data collection, infer protected or sensitive attributes,
  create person-level scores, or alter discovery eligibility without explicit
  visible governance and fresh consent.
- Emergency flags can only reduce or isolate capability during an incident;
  they cannot expand surveillance, change consent, or alter discovery/ranking.
- Emergency use requires a short expiry and post-incident disclosure.
- No hidden flag may affect matching, visibility, ranking, consent, privacy,
  safety interpretation, feature eligibility, retention, or external action.

## Always-stop conditions

- A sort uses a hidden input, private data, an inferred attribute, a popularity
  measure, response speed, engagement metric, photo-quality measure, or
  person-level score.
- A sort causes a user to be permanently or systematically deprived of
  discovery exposure without a published, user-auditable explanation.
- A flag changes user-visible behavior without disclosure and required consent.
- A research or intimacy flag activates without explicit applicable consent.
- A flag expands data collection, message scanning, identity inference,
  commercial-risk profiling, or person-level scoring.
- A flag causes an accessibility-equivalence failure.
- An emergency flag is used as an experiment, has no expiry, lacks a
  post-incident disclosure, or changes discovery, consent, privacy, eligibility,
  or user classification.
- A feature-flag or sort event reaches advertising, model training, user
  profiling, or unrelated analytics.

## Permitted measures

- Explicit user feedback about explanation clarity and control.
- Aggregate accessibility task-completion outcomes.
- Aggregate sort-selection counts only when collected through separate,
  voluntary, non-account-linked research consent.
- Aggregate flag expiry, withdrawal, and review-completion outcomes.
- Publicly documented post-incident emergency-flag disclosures.

## Prohibited measures

- Individual sort history.
- Discovery engagement optimization.
- Click-through, swipe-through, reply-speed, or conversion ranking.
- Profile attractiveness or desirability scores.
- Hidden experimentation.
- Intimacy-data sorting.
- Identity, health, recovery, financial, location, vulnerability, or sexual
  preference inference.
- User-level behavioral profiling.
