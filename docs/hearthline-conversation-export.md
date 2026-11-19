# Hearthline Conversation Export

## Purpose

The Hearthline conversation export format gives a participant control over a
portable copy of material they are entitled to export. It is not a public feed,
social graph, identity record, reputation artifact, credential, or entitlement
record.

The format does not establish authorship, identity, authenticity, institutional
status, CyberRank status, eligibility, relationship status, medical status, or
any social ranking.

## Participant-control rules

1. A participant may export their own authored content.
2. Third-party-authored content is excluded by default.
3. Third-party-authored content may be included only when the export carries
   explicit, revocable, single-export authorization.
4. Each export declares a specific purpose and an expiry time.
5. Redistribution and third-party replication are prohibited by default.
6. Machine-learning training use is prohibited.
7. Automated decision use is prohibited.
8. The export includes a revocation contact route.
9. Recipients must not silently copy an export into a data broker, analytics
   store, model-training corpus, public archive, social graph, or identity
   system.
10. A cryptographic content hash can detect accidental or unauthorized changes
    after export. It does not prove authorship, consent, identity, or legal
    enforceability by itself.

## Example export

```json
{
  "format": "hearthline-conversation-export",
  "formatVersion": "1.0",
  "exportId": "export-20260926-0001",
  "createdAt": "2026-09-26T11:20:00Z",
  "exporter": {
    "selfAssertedLabel": "Participant",
    "controlStatement": "The exporter controls this copy. It does not create public status, verification, ranking, or eligibility."
  },
  "purpose": {
    "declared": "Personal continuity copy for the exporter’s private records.",
    "recipientClass": "self",
    "expiresAt": "2027-09-26T11:20:00Z"
  },
  "replication": {
    "thirdPartyReplicationDefault": "prohibited",
    "redistributionDefault": "prohibited",
    "machineLearningTrainingAllowed": false,
    "automatedDecisionUseAllowed": false,
    "revocationContact": "[https://example.invalid/export-revocation](https://example.invalid/export-revocation)"
  },
  "contents": [
    {
      "entryId": "message-20260926-0001",
      "createdAt": "2026-09-26T11:15:00Z",
      "authorRelation": "exporter-authored",
      "body": "I would like to preserve this note for my own continuity.",
      "inclusionAuthorization": {
        "basis": "self-authored",
        "grantedAt": "2026-09-26T11:20:00Z",
        "scope": "single-export",
        "revocable": true
      }
    }
  ],
  "integrity": {
    "canonicalization": "RFC8785-JCS",
    "contentHashAlgorithm": "SHA-256",
    "contentHash": "7c5703e3e48f4be72db3b0a8bf2491a89f1e791d0281e797e284eeb39f26e4b5"
  }
}
```

## Recipient obligations

A recipient that accepts this format must:

- Preserve the purpose and replication restrictions.
- Avoid copying content into another system without additional authorization.
- Provide a usable revocation route.
- Avoid creating identity, relationship, behavioral, or eligibility profiles.
- Avoid using the export for ranking, moderation scoring, employment,
  insurance, credit, housing, education, law-enforcement, or other automated
  or high-impact decisions.
- Delete or isolate content when a valid revocation request applies, subject to
  any independently applicable legal obligation.
- Clearly state if it cannot honor a requested deletion or restriction before
  accepting the export.

## Limits

The export format expresses governance constraints and supports interoperable
validation. It cannot technically stop a recipient from copying content after
they receive it. Protection therefore depends on recipient accountability,
contractual or community governance where appropriate, secure transport,
minimized disclosure, recipient transparency, and a practical revocation path.
