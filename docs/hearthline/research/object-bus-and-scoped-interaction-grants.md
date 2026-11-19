# HearthlineObjectBus and ScopedInteractionGrant Research Contract

## Primary promises

HearthlineObjectBus:
Allow Hearthline object families to exchange minimal, typed, versioned,
purpose-bound state notices without creating a global behavioral event log,
cross-object identity join key, public bus API, person-level profile, hidden
analytics surface, ranking input, advertising input, or external-action path.

ScopedInteractionGrant:
Represent a current, explicit, renewable-but-never-auto-renewed platform
interaction permission that can be revoked by its owner without creating a
claim of real-world consent, legal validity, health status, safety, identity,
intention, meeting obligation, intimacy permission, or future contact right.

## HearthlineObjectBus constraints

- Clients use feature-specific commands. They do not publish arbitrary internal
  bus events or subscribe to arbitrary internal streams.
- Notices are typed, versioned, minimal, purpose-bound, and scoped to an object
  family and correlation boundary.
- Notices contain no account/user/profile/counterparty identifiers, raw text,
  messages, private preferences, health, recovery, identity, intimacy, finance,
  location, device, IP, analytics, advertising, safety, risk, or ranking data.
- Local-only objects never enter the bus.
- Channels are `ephemeral`, `purpose_limited`, `aggregate_only`, or
  `local_only`; `local_only` has no subscribers.
- Subscribers use static, policy-validated capabilities and are limited by
  object family, transition kind, platform scope, purpose, retention class,
  correlation boundary, and explicit prohibitions on external action,
  analytics, ranking, advertising, and identity inference.
- No global event log, account-wide trace identifier, cross-subscriber profile,
  or unrestricted event replay is permitted.
- Observability, retries, dead-letter queues, caches, backups, traces, and
  incident tooling are subject to the same minimization and retention limits.
- A notice cannot trigger an external action.

## ScopedInteractionGrant constraints

- Grants are platform interaction grants, not consent tokens, signatures,
  attestations, contracts, legal records, health records, or proofs.
- Grants require current, explicit user selection and never auto-renew.
- Grants are scoped to direct message, voice/video request, media receive
  request, private preference discussion, meet-plan discussion, venue-context
  discussion, aftercare discussion, privacy-preference discussion, or
  health-conversation opener.
- Grants cannot represent consent to touch, sexual activity, meeting, private
  venue entry, travel, alcohol/substance use, aftercare, real-world act, or
  future contact.
- A participant revokes their own grant. Revocation ends access through that
  grant and sends only the minimum object-local invalidation notice.
- Grants are encrypted, recipient-scoped, purpose-limited, expiring, and
  separated from profiles, discovery, ranking, advertising, analytics, model
  training, moderation scoring, and identity inference.
- A grant does not unlock any capability outside its explicit platform scope.
- A grant cannot be used to create a value-for-intimacy path.

## Always-stop conditions

- A client can publish arbitrary internal notices or subscribe to an
  unrestricted internal stream.
- A bus notice, subscription, trace, retry, log, cache, backup, or dead-letter
  record contains a user/account/profile/counterparty identifier, raw content,
  sensitive category, location, device, analytics identifier, or person-level
  score.
- A local-only object emits a bus event or sends content to a server.
- A subscriber uses notices for analytics, ranking, advertising, discovery,
  moderation scoring, eligibility, identity inference, behavioral profiling,
  or external action.
- A grant is described or interpreted as consent to a real-world act, a legal
  record, a health record, a safety certification, or an obligation.
- A grant auto-renews, cannot be revoked immediately, persists after expiry,
  or is reused across unrelated objects.
- Revocation broadcasts more information than necessary or exposes the
  revoking person’s reason, identity, relationship, or private state.
- An accessibility-equivalent path is unavailable for grant, decline, revoke,
  expiry, inspection, correction, and appeal.
- A money, gift, housing, lodging, transport, work, debt, drugs, goods,
  services, or other value-for-intimacy workflow is introduced.

## Permitted measures

- Synthetic bus envelope validation tests.
- Synthetic subscriber-scope rejection tests.
- Synthetic local-only event rejection tests.
- Synthetic grant issuance, expiry, revocation, and no-auto-renew tests.
- Aggregate retention and expiry verification.
- Accessibility task-completion tests using fictional object references and
  platform scopes.
- Security review outcomes using synthetic events and grants only.

## Prohibited measures

- Global user event history.
- Cross-object user profiling.
- Consent scoring.
- Real-world consent inference.
- Identity inference.
- Sensitive-content transport.
- Discovery/ranking/advertising/moderation use.
- External action.
- Unconsented message, image, voice, device, behavior, location, or health
  analysis.
