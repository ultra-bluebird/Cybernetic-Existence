# Hearthline Adult Connection Governance

## Purpose

Hearthline supports consenting adults seeking friendship, dating, romance,
intimacy, casual encounters, companionship, and low-pressure social connection.
It is not a system for assigning worth, verifying private identity, brokering
dependency, or making eligibility decisions about adults.

## Core invariants

1. Adult autonomy
   - A user may define, change, narrow, pause, or withdraw their connection
     intent and boundaries at any time.
   - No profile field, match, message, or prior consent creates an obligation
     to meet, disclose, provide sex, continue conversation, exchange money,
     provide housing, provide transport, or explain a refusal.

2. Minimal disclosure
   - Exact home address, workplace address, daily schedule, financial status,
     private health information, and private technical information are never
     required for discovery, matching, or messaging.
   - Sensitive fields use explicit audience scopes:
     public, reciprocal-match, selected-contact, and private-only.

3. No dependency brokerage
   - Hearthline must not rank, match, or promote users based on financial need,
     housing need, employment vulnerability, willingness to obey, perceived
     submission, private identity, or presumed capacity.
   - The platform must not facilitate exchanges of shelter, money, work,
     debt relief, or essential goods for intimacy, sex, obedience, or
     continued contact.

4. Consent is contextual and renewable
   - Consent to message is not consent to explicit content.
   - Consent to explicit content is not consent to meet.
   - Consent to meet is not consent to touch, a private venue, photography,
     overnight stay, or sexual activity.
   - A withdrawal, pause, silence, block, or decline ends the relevant
     escalation path without penalty.

5. Accessibility equivalence
   - Every core workflow must support keyboard navigation, screen readers,
     text resize, contrast modes, reduced motion, predictable focus order,
     visible labels, plain-language alternatives, and compatible assistive
     technology.
   - Voice, video, images, reaction controls, and timed interactions must
     have accessible alternatives.

6. Human review and appeal
   - Users can report unwanted conduct, preserve relevant evidence, block,
     and request human review.
   - Material moderation decisions provide a plain-language reason, a path to
     correct errors, and an accessible appeal channel.

7. Privacy-preserving safety support
   - Optional safety features may warn about urgent money requests, coercive
     isolation, threats, repeated boundary pressure, workplace targeting, and
     requests for precise location.
   - Warnings must be explainable, locally processed where feasible,
     dismissible, and never used as hidden desirability, risk, or identity
     scores.

## Connection intents

- friendship
- conversation
- activity-companion
- dating
- romance
- affection
- intimacy
- casual-encounter
- relationship
- undecided

A user can select multiple intents and set a pace preference for each.

## Required consent scopes

- `profile.public.read`
- `profile.match.read`
- `context.sensitive.share`
- `message.direct.send`
- `media.explicit.receive`
- `call.voice.start`
- `call.video.start`
- `meet.plan.share`
- `meet.checkin.contact`
- `safety.report.submit`

Each scope must have:
- a stated purpose;
- a chosen audience;
- an expiration option;
- a revocation mechanism;
- a deletion or retention rule;
- an accessible explanation.

## Prohibited system behaviors

- Inferring private identity, health, augmentation, sexuality, recovery,
  finances, or vulnerability from profile content, metadata, message style,
  device data, or response timing.
- Requiring identity disclosure beyond lawful age-gating and security needs.
- Publishing public trust, desirability, activity, attractiveness, or
  vulnerability rankings.
- Selling, sharing, or targeting advertising using intimate preferences,
  relationship intent, sexual orientation, precise location, or sensitive
  disclosures.
- Automatically contacting workplaces, families, emergency contacts, or
  authorities based solely on dating-platform activity.
- Treating profile language indicating distress as consent, reduced autonomy,
  or permission for another user to control the person.

## Review metrics

Measure platform quality using aggregate, privacy-preserving indicators:

- percentage of core screens passing accessibility checks;
- median time to block, report, and quiet-exit;
- percentage of safety reports receiving human review on request;
- percent of users who can use discovery without revealing precise location;
- percentage of explicit-media requests preceded by active opt-in;
- opt-in rate and comprehension rate for consent scopes;
- appeal correction rate for moderation decisions;
- user-reported clarity of boundaries and pacing controls.

Do not measure success through time spent, compulsive engagement, number of
sexual exchanges, inferred vulnerability, or pressure-based conversion.
