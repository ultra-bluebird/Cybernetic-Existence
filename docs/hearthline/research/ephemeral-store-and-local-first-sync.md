# EphemeralStoreExtension and LocalFirstSyncBridge Research Contract

## Primary promises

EphemeralStoreExtension:
Define policy constraints for sensitive objects that may require time-limited,
purpose-bound storage without claiming that platform deletion prevents
recipient copying, device compromise, off-platform retention, legal
preservation, or recovery from unverified backup and key paths.

LocalFirstSyncBridge:
Support local-first private objects through explicit user-owned export and
import without automatic synchronization, account-linked cloud backup,
plaintext server handling, automatic merge, behavior profiling, discovery use,
ranking use, advertising use, or external action.

## EphemeralStoreExtension constraints

- Ephemerality is a verified platform storage and access property, not a claim
  that all copies everywhere are unrecoverable.
- No object may claim global unrecoverability, screenshot prevention,
  copy prevention, forensic impossibility, legal erasure, or backup-proof
  deletion without separately verified evidence.
- Local-only reflection objects do not enter server-side ephemeral storage by
  default.
- Server-held ephemeral ciphertext is deferred until a dedicated security
  review defines key hierarchy, key lifecycle, metadata boundaries, retention,
  deletion, replay resistance, replica behavior, log behavior, cache behavior,
  backup behavior, legal preservation handling, endpoint threats, and truthful
  user-facing language.
- Plaintext server storage, ordinary backups, ordinary caches, ordinary
  analytics, automatic sync, and external action are prohibited.
- TTL and key invalidation are separate controls; neither is described as
  sufficient without verified implementation evidence.
- Any object with server-held pairwise context requires purpose-limited
  retention, recipient-scoped access, explicit revocation, expiry, access
  parity, and separate security review.

## LocalFirstSyncBridge constraints

- Local-first objects remain on the device by default.
- The initial migration path is explicit local file export and explicit local
  file import; no server API is required.
- Export includes only user-owned ciphertext and minimal encryption metadata,
  schema version, content type, creation time, and a local-file privacy
  warning.
- Import is user initiated, schema validated, size bounded, locally decrypted,
  previewed, and explicitly imported, replaced, or discarded.
- Automatic cloud backup, background synchronization, cross-device merge,
  account-linked sync history, profile linkage, analytics, behavior tracking,
  discovery use, ranking use, advertising use, moderation use, and external
  action are prohibited.
- No encryption algorithm, key derivation method, KMS/HSM design, passphrase
  model, device-bound model, recovery mechanism, or server transport is
  claimed before separate security review.
- If later ciphertext transport is proposed, metadata, traffic timing, blob
  size, identifiers, retention, replay, device authorization, and access logs
  are treated as sensitive design concerns.

## Always-stop conditions

- An ephemeral feature claims global or universal unrecoverability beyond its
  verified platform-held storage boundary.
- Plaintext, content keys, wrapped keys, raw metadata, or sensitive payloads
  appear in server storage, backups, replicas, caches, retry queues, logs,
  traces, error reports, analytics, session replay, incident exports, or
  ordinary observability systems.
- Local-only reflection data enters a bus, server, synchronization pathway,
  cache, analytics system, profile, discovery system, ranking system,
  advertising system, moderation system, or external action path.
- A local-first export or import occurs without explicit user action.
- An import automatically merges, overwrites, publishes, syncs, or transmits
  private data without user selection.
- A user is pressured to export, import, synchronize, share, disclose, meet,
  travel, host, become intimate, continue contact, or accept money or other
  value.
- An accessibility-equivalent local create, read, export, import, preview,
  replace, discard, clear, disable, delete, expiry, and error-recovery path is
  unavailable.
- Any privacy, encryption, deletion, revocation, retention, sync, or
  unrecoverability claim exceeds verified implementation evidence.

## Permitted measures

- Synthetic storage-policy validation.
- Synthetic export-envelope and import-decision validation.
- Synthetic local-only network-isolation tests.
- Synthetic expiry, deletion, cache-exclusion, and backup-exclusion tests in
  controlled environments.
- Accessibility task-completion tests using fictional local objects and export
  files.
- Security review outcomes using synthetic content only.

## Prohibited measures

- Private-content analysis.
- Content-key collection.
- Passphrase collection.
- Account-linked sync profiling.
- Export/import history profiling.
- User location, identity, health, recovery, sexuality, financial, housing,
  capacity, or vulnerability inference.
- Discovery, ranking, advertising, moderation, eligibility, payment, or
  behavioral profiling effects.
- Unconsented message, image, voice, device, behavior, or private-object
  analysis.
