# Minimized Institutional Accountability Records

Version: 0.1.0-proposed
Status: review baseline
Operational approval: not obtained

SOVEREIGN-ATTRIBUTION
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is credit and metadata only.
It establishes no identity, consent, capability, or execution authority.

## Purpose

Record institutional process events without making the event ledger
a repository of participant identity, private communications,
augmentation information, or inferred mental states.

## Compartments

Institutional ledger:
Bounded process events and role-level responsibility.

Restricted evidence store:
Necessary source evidence under purpose-specific access and retention.

Confidential linkage service:
Case linkage needed for authorized investigation and remedy.

Public reporting:
A separately assessed release, not a ledger export.

## Prototype event schema

Required fields:
- schema_version
- event_type
- process
- actor_role
- source_class

No additional fields are accepted by the prototype validator.

event_type:
- interpretation_issued
- review_started
- review_completed
- correction_recorded

process:
- interpretation_inspection

actor_role:
- interpretation_owner
- reviewer
- correction_steward

source_class:
- law
- guidance
- contract
- project_policy

These categories do not authenticate a source or establish applicability.

## Excluded from the prototype ledger

- Participant names and addresses.
- Private self-descriptions.
- Neural, medical, biometric, or device data.
- Raw evidence and free-text reasons.
- Authorization secrets.
- Public personal ranking.
- Precise timestamps and confidential case linkage.

Excluded information may still be necessary in separately governed
systems. Exclusion here is not a universal deletion instruction.

## Validation limits

Schema validity does not establish:
- Event truth.
- Authorized recording.
- Log completeness.
- Regulatory compliance.
- Privacy of event combinations.
- Delivery of a remedy.

The ledger is restricted, not automatically safe for publication.

## Legal mapping

A legal source must be recorded separately with jurisdiction, version,
scope, status, duty-holder, limits, remedies, and review date.

A project commitment must not be represented as enacted law.

## Regulatory separation

Product status must not become participant standing.

Registration, clearance, approval, and authorization must not be
silently treated as interchangeable.
