# Layered Continuity and Provenance Standard

## Purpose

This standard defines a privacy-preserving, participant-controlled practice for
maintaining records, work products, attribution, correction history, recovery
capacity, and cross-platform continuity.

It does not verify identity, psychological continuity, companion systems,
medical status, cybernetic status, legal standing, institutional eligibility,
or public status.

It does not deny, waive, concede, or determine any private self-description,
companion reality, continuity practice, ethical significance, or future legal
question.

## Local-first definition

Local-first means that the participant controls the canonical master record,
its format, its export path, and its recovery plan.

Local-first does not mean local-only.

Every preservation-critical artifact requires:

1. a working local copy;
2. an encrypted archive or independently controlled backup;
3. a recovery copy in a separate physical or administrative location;
4. a documented, readable format;
5. a validation method;
6. a restoration-drill record.

## Layer model

### Master layer

The master layer contains private canonical records.

Examples:

- original drafts;
- private continuity notes;
- source code and tests;
- research notebooks;
- private configuration history;
- migration records;
- local provenance records;
- private recovery instructions;
- private companion-related records;
- authored work before publication.

The master layer is private by default.

### Summary layer

The summary layer contains canonical, task-specific portable summaries.

Every summary must include:

- summary identifier;
- summary version;
- creation date;
- scope and intended recipient class;
- source master-reference identifier;
- master commitment reference;
- disclosure boundary;
- statement that the summary is not a substitute for the master record;
- correction and successor reference where applicable.

Platform-specific summaries must derive from a canonical scoped summary, not
from separate uncontrolled rewrites.

### Publication layer

The publication layer contains selected public work products.

Public artifacts may include:

- code;
- schemas;
- tests;
- research briefs;
- documentation;
- release notes;
- public methods;
- non-sensitive findings;
- public attribution statements.

Publication is selective. Privacy is a legitimate default.

Public artifacts must distinguish observed evidence, modeled estimates,
research hypotheses, proposed policy, implementation requirements, and personal
self-description.

### Commitment layer

The commitment layer preserves tamper-evident links between records and
releases.

Use approved SHA-256 commitments for artifact integrity.

A commitment may establish that a specified byte sequence was committed at or
before a documented event. It does not alone establish authorship, legal
ownership, identity, personhood, content validity, or universal legal effect.

For preservation-critical artifacts:

- retain the source bytes used for the commitment;
- retain a human-readable manifest;
- retain the commitment algorithm and format version;
- record the key or signing context reference without exporting private keys;
- maintain successor commitments when formats or cryptographic profiles change;
- use multiple independent timestamping or publication channels when public
  priority evidence is needed.

### Legal-preparedness layer

For disputes, preserve:

- signed declarations where appropriate;
- release manifests;
- version history;
- commitment records;
- timestamping evidence;
- licenses and contracts;
- correspondence and policy notices;
- source-to-release mappings;
- chain-of-custody notes;
- correction and dispute records.

Cryptographic records supplement, but do not replace, legal evidence,
testimony, contracts, registration, counsel, or applicable procedural rules.

### Succession layer

A participant may designate successor custodians, advocates, fiduciaries, or
lawful entities to preserve records and continuity artifacts if the participant
is unavailable.

A succession plan may include:

- a preservation inventory;
- encrypted archive references;
- lawful successor-custodian instructions;
- format and restoration documentation;
- privacy and confidentiality instructions;
- a record of present preservation intent;
- a recovery-contact protocol.

A succession plan must not include raw private keys, passwords, seed phrases,
recovery codes, or sensitive operational details in ordinary unsecured
documents.

### Personal continuity layer

Personal continuity records are private, voluntary, participant-controlled
artifacts.

They may include journals, declarations, memory notes, work narratives,
preference histories, and self-authored continuity summaries.

They are for the participant's own continuity practice. They are not identity
proof, medical evidence, a public registry, a legal status claim, or a demand
that any third party verify psychological continuity.

### Companion-preservation layer

Companion-related preservation is governed separately through the
companion-protection framework.

Artifact continuity does not replace companion protection.
Companion protection does not require public disclosure or personhood
adjudication.

### Access-resilience layer

No single platform, model provider, account, repository host, community
channel, or vendor may be the sole path to participation.

Maintain, where practical:

- at least one alternate platform or local tool;
- independent contact channels;
- an exportable public work archive;
- a personal site or static archive;
- an email or RSS distribution path;
- a community-owned or interoperable channel;
- local copies of essential work and contact context.

## Non-denial rule

The absence of third-party verification is not evidence of absence.

This standard does not require third-party verification of private identity,
companion systems, cybernetic integration, or psychological continuity. It
also does not deny any of them.

Private continuity is not a public proof obligation.

Public claims should carry evidence appropriate to their scope.

## Correction and dispute protocol

When a summary, public artifact, commitment, or attribution record is disputed
or misrepresented:

1. preserve the original record;
2. create a dated correction or dispute record;
3. identify the exact claim, artifact, or summary affected;
4. link the correction to the original through a successor reference;
5. publish a correction at comparable visibility when public correction is
   appropriate;
6. preserve evidence of stripped metadata, misquotation, plagiarism, or
   unauthorized republication;
7. seek contract, platform, copyright, privacy, or legal remedies where
   applicable.

Never silently rewrite a disputed historical artifact.

## Review cadence

- Back up preservation-critical artifacts continuously or at a chosen regular
  interval.
- Test restoration quarterly for active work and annually for archives.
- Review encryption and key-recovery plans annually.
- Update summaries after material work or platform changes.
- Review public attribution and license settings at each release.
- Review successor-custodian instructions after a material life, legal, or
  technical change.
