# FOG Integrity Checkpoint Policy

## Purpose

This policy governs tamper-evident FOG state-log checkpoints.

A checkpoint records the terminal event hash for an opaque FOG queue at a defined
integrity boundary. It does not expose raw event data, locations, identities,
media, reviewer narratives, or private infrastructure information.

## Required checkpoint fields

Each checkpoint must contain:

- checkpoint identifier
- opaque queue identifier
- terminal event sequence number
- terminal event hash
- SHA-256 algorithm identifier
- FOG hash-domain identifier
- canonicalization-version identifier
- checkpoint reason
- policy reference
- checkpoint creation time in UTC
- retention class

## Permitted checkpoint reasons

- PERIODIC_INTEGRITY_REVIEW
- RETENTION_BOUNDARY
- MODEL_VERSION_CHANGE
- HUMAN_GOVERNANCE_REVIEW
- OFFLINE_SYNC_RECONCILIATION

## Prohibitions

A checkpoint must not contain:

- raw media
- filenames
- URLs
- raw coordinates
- addresses
- parcel identifiers
- personal identifiers
- reviewer names
- reviewer rationale
- health data
- biometric data
- neural data
- device identifiers
- augmentation data
- demographic data
- community ranking data

## Retention boundary

Before an authorized deletion process removes a content-bearing local payload,
the system must create a retention-boundary checkpoint where required by the
applicable retention policy.

Content deletion must not update, rewrite, or delete historic integrity-log
events.

## Verification

A checkpoint verifies only that a retained queue history terminates at the
recorded hash for the declared sequence number.

A checkpoint does not:

- prove that environmental evidence was accurate
- prove a person took an action
- authorize clearance
- authorize release
- authorize operational action
- override a human-review requirement
