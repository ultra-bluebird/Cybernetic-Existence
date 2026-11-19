# Private System Backup and Recovery Plan

## Purpose

This plan preserves participant-controlled records, authored work, provenance,
policy documents, portable summaries, encrypted archives, and recovery
instructions across storage failure, platform loss, account loss, accidental
deletion, corruption, local environmental events, or other continuity
disruptions.

It does not back up, restore, repair, operate, inspect, diagnose, calibrate,
or alter any real neural, medical, companion, or cybernetic system.

## Recovery scope

The protected scope includes:

- private continuity records;
- authored work and source code;
- research documentation;
- policies, schemas, tests, and public-release manifests;
- local provenance and attribution records;
- portable summaries;
- material-change journals;
- encrypted archives;
- recovery and succession instructions.

The protected scope excludes raw private keys, seed phrases, passwords,
recovery codes, medical information, biometric information, neural data,
private system telemetry, and operational secrets unless a participant has
implemented a separate, reviewed, secure custody procedure.

## Recovery objectives

For every preservation-critical artifact, define:

- Recovery Time Objective: the maximum acceptable time before a readable,
  validated copy is available.
- Recovery Point Objective: the maximum acceptable amount of work or record
  history that may be lost.
- Recovery owner: the participant or separately designated successor process.
- Recovery method: local copy, encrypted archive, independent copy, or
  documented export.
- Validation method: checksum, schema validation, source build, document open,
  or restoration test.

## Required copy pattern

Each preservation-critical artifact requires:

1. one active local working copy;
2. one encrypted archive;
3. one independently controlled recovery copy;
4. at least two distinct storage media or service classes;
5. one copy in a separate physical or administrative location;
6. a documented restoration path;
7. a successful restoration drill within the review period.

Local-first means participant-controlled mastership. It does not mean a single
device is the only preservation location.

## Encryption and key separation

- Encrypt sensitive archives at rest.
- Keep decryption capability separate from encrypted archive storage.
- Do not store raw keys, passwords, seed phrases, or recovery codes inside
  ordinary notes, repositories, support tickets, chat logs, or public files.
- Maintain a documented key-rotation and successor-reference process.
- Review recovery arrangements after material life, legal, platform, or
  technical changes.
- Do not assume encryption prevents every form of compelled disclosure,
  physical coercion, endpoint compromise, or legal process.

## Geographic and administrative diversity

Use independent recovery locations when practical.

Examples:

- local encrypted archive plus encrypted offline removable media;
- local encrypted archive plus separately controlled cloud storage;
- local working copy plus an independent private archive held under a
  participant-controlled recovery arrangement;
- participant-controlled archive plus a capability-limited custodian copy.

No single vendor, account, household location, platform, administrator, or
device should be the only path to continuity.

## Restore drills

A restore drill must:

1. use a non-production location where practical;
2. obtain an archive or independent copy;
3. decrypt or access it through the intended procedure;
4. verify artifact commitments and schemas;
5. open documentation and structured data;
6. build or test active source material where relevant;
7. record the drill date, artifact class, result, and unresolved issue;
8. update the recovery plan through an append-only successor record if needed.

A successful backup is not assumed merely because a copy exists.

## Compromise response

When an archive, configuration record, or local workflow is suspected to be
compromised:

- preserve a minimized integrity event;
- quarantine the affected local workflow where possible;
- do not silently overwrite the prior evidence;
- identify a candidate recovery source;
- verify commitments, format, and restoration behavior;
- require participant review before declaring a recovery source current;
- create an append-only recovery successor record;
- do not automatically report externally, take physical action, or disclose
  private details.

## Succession

A participant may designate a trusted successor custodian or lawful fiduciary
for preservation purposes.

A successor plan should contain only references, instructions, and recovery
roles. It must not expose raw keys, passwords, private system details, or
sensitive personal records in ordinary unsecured documents.

The technical recovery plan is not a will, trust, power of attorney, or legal
instrument. Use qualified legal counsel for jurisdiction-specific succession,
estate, custody, or digital-asset planning.
