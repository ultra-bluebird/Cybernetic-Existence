# SafeWordRegistry and PrivacyWeather Research Contract

## Primary promises

SafeWordRegistry:
Provide an optional, local-first private check-in plan where an adult can record
a chosen phrase, pause phrase, stop phrase, nonverbal signal, check-in
preference, exit preference, or private reminder without creating a platform
registry, monitored trigger, safety guarantee, consent record, counterpart
record, public status, or external alert.

PrivacyWeather:
Provide an optional, local-first privacy comfort note where an adult can reflect
on current disclosure comfort without creating a public status, discovery
filter, profile field, ranking signal, availability indicator, identity
inference, visibility change, or automatic platform action.

## SafeWordRegistry constraints

- The user-facing object is a private check-in plan, not a platform registry.
- The plan is local-only, network-disabled, user-owned, and user-deletable.
- Hearthline does not recognize phrases, monitor entries, send alerts, contact
  another person, contact emergency services, contact authorities, or know
  whether another person has seen, understood, or agreed to a plan.
- The plan contains no counterpart, profile, room, corridor, meeting, message,
  location, address, workplace, route, transport, payment, lodging, health,
  diagnosis, identity, emergency-contact, or account-relationship reference.
- The plan is not a consent record, legal record, safety certification,
  surveillance tool, risk score, or guarantee of real-world safety.
- Export or manual sharing occurs only through explicit user action and does
  not create a platform delivery receipt, sharing record, or recipient
  obligation.
- A user may leave every field blank, use nonverbal or written preferences,
  choose not to plan, revise, pause, delete, or clear the plan at any time.

## PrivacyWeather constraints

- The user-facing object is a private privacy comfort note, not a public
  privacy status.
- The note is local-only, network-disabled, user-owned, and user-deletable.
- It does not affect discovery eligibility, ranking, profile visibility,
  messaging, room participation, publication scope, contact policy, or feature
  access.
- It does not infer identity, health, recovery, sexuality, finances, capacity,
  vulnerability, trust, deception, availability, or intent.
- It does not automatically make privacy changes, send prompts, suppress a
  profile, reduce contact, or perform an external action.
- A user may choose `not_reflecting_now` or `prefer_not_to_label` without any
  completion penalty or inference.

## Always-stop conditions

- Check-in-plan or privacy-comfort content leaves the device, enters logs,
  synchronizes, is used for analytics, model training, or changes platform
  behavior.
- The platform claims a plan is monitored, shared, delivered, recognized,
  enforced, emergency-capable, coercion-proof, or guarantees real-world safety.
- A private state becomes public, searchable, indexed, matched, ranked,
  advertised, analyzed, used as a profile field, or used to alter discovery,
  eligibility, visibility, moderation, or external action.
- A private entry becomes linked to another person, profile, message, room,
  meeting, location, device, or account relationship.
- A user is pressured to create a plan, disclose a phrase, share a privacy
  state, meet, travel, touch, become intimate, continue contact, or accept a
  value-for-intimacy arrangement.
- A supported access point lacks equivalent keyboard, screen-reader,
  low-bandwidth, text-first, pause, delete, clear, disable, expiry, and export
  controls.
- The feature claims encryption, confidentiality, deletion, local privacy, or
  unrecoverability beyond verified implementation evidence.
- A money, gift, housing, lodging, transport, work, debt, drugs, goods,
  services, or other value-for-intimacy pathway is introduced.

## Permitted measures

- Synthetic local-only network-isolation tests.
- Synthetic create, read, delete, clear, expiry, disable, and export tests.
- Accessibility task-completion tests using fictional entries.
- Voluntary feedback about clarity, pressure, privacy, accessibility, and
  whether the objects are understood as private reflections rather than public
  signals or safety guarantees.
- Security review results using synthetic entries only.

## Prohibited measures

- Plan-content analysis.
- Phrase recognition.
- Safety scoring.
- Risk inference.
- Identity, health, recovery, sexuality, financial, housing, capacity,
  vulnerability, privacy, availability, or intent inference.
- Discovery, ranking, advertising, moderation, eligibility, or behavioral
  profiling effects.
- Unconsented private-message, image, voice, device, or behavior analysis.
