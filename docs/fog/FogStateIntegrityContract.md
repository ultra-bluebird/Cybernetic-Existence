# FOG State Integrity Contract

## Purpose

This contract defines a tamper-evident, append-only integrity chain for FOG
state transitions.

The chain protects the order and contents of retained derived governance events.
It does not establish identity, legal status, environmental compliance,
institutional authorization, or a person's credibility.

## Hash construction

For event i:

H_i = SHA-256(
    domain
    || canonicalization_version
    || previous_hash
    || canonical_event_data
    || nonce
)

Required values:

- domain: AugmentedHub.FOG.StateLog.v1
- canonicalization_version: canonical-fields-v1
- previous_hash: the prior event digest, or the fixed genesis digest
- canonical_event_data: ordered, length-prefixed, approved derived event fields
- nonce: unique opaque event nonce
- event_hash: lowercase hexadecimal SHA-256 digest

## Allowed event fields

Canonical event data may include:

- opaque event identifier
- opaque queue identifier
- monotonic sequence number
- prior state
- resulting state
- UTC event timestamp
- policy reference
- model-version reference
- aggregation-window reference
- source hex resolution
- applied hex resolution
- opaque spatial-scope reference
- reason code
- retention class
- timeout state
- hash-chain metadata

## Prohibited event fields

Canonical event data must not include:

- raw media
- media filenames
- media paths
- URLs
- raw coordinates
- addresses
- parcel references
- facility map references
- personal identifiers
- reviewer names
- reviewer narrative
- health information
- biometric information
- neural information
- device identifiers
- augmentation information
- demographic data
- community membership data
- individual behavior or activity data

## Canonicalization requirements

Each hash input field must have:

- a fixed field order
- UTF-8 text encoding for text fields
- explicit integer encoding for numeric fields
- length-prefix framing
- a declared representation of timestamps
- lowercase hexadecimal representation for digests
- rejection of NaN, infinity, invalid state values, invalid identifiers, and
  invalid resolution values

## Append-only requirements

The state log must reject update and delete operations.

Each queue-specific event sequence must be contiguous and monotonic.

Each new event must reference the previous event hash from the same queue.

An integrity verifier must reject:

- altered event data
- altered nonce
- altered previous hash
- altered event hash
- altered sequence number
- altered event order
- malformed digest
- cross-queue hash linkage
- unsupported canonicalization version
- unsupported hash domain
- unapproved event fields

## Checkpoints

A hash chain is tamper-evident but not independently tamper-proof.

The system must create periodic checkpoints containing:

- opaque queue identifier
- terminal sequence number
- terminal event hash
- checkpoint time
- checkpoint reason
- policy version

Checkpoints must be retained in a separately controlled integrity context.

Checkpoint storage must not expose raw event data, sensitive location data, or
personal data.

## Retention

Before authorized deletion of content-bearing records, the system must create an
integrity checkpoint where required by retention policy.

The retention audit must state that content deletion occurred without rewriting
historic state-log entries.

## Decision boundary

A valid hash chain proves only that retained event records are internally
consistent with the verified chain and checkpoint context.

A valid hash chain must not automatically clear a FOG state or authorize a
real-world action.
