# Provenance-Continuity Spine Contract

## Status

Private-use and public-interest governance infrastructure specification.

This contract defines how records, signed claims, policy constraints, evidence,
corrections, forks, and migrations can remain portable and reviewable across
storage providers, platforms, model generations, and organizational changes.

It is not a personhood system, identity-certification system, consciousness test,
medical system, cybernetic-status registry, host-migration verifier, public ranking,
eligibility system, or automated authority.

## Mission

The provenance-continuity spine preserves the semantic continuity of governed
records across substrate change.

Semantic continuity means that an authorized successor record preserves, or
explicitly declares changes to:

- Content integrity.
- Attribution and derivation lineage.
- Governance and policy constraints.
- Publication and consent boundaries.
- Witness and attestation references.
- Correction and appeal pathways.
- Uncertainty, disagreement, and evidence limitations.
- Review and material-change history.

Semantic continuity does not mean that the spine proves a person, identity,
conscious experience, biological body, cybernetic status, or physical host is the
same across time or substrates.

## First-class objects

### Record

A structured representation of an observation, decision, review, correction,
commitment, policy, report, or other governed information object.

A record includes:

- Content reference.
- Schema and version reference.
- Provenance reference.
- Policy bundle reference.
- Review status.
- Correction pathway.
- Uncertainty and limitation statement.

### Signed claim

A signed statement by a sovereign, witness, reviewer, collective, institution,
or other declared role.

A signed claim is evidence that a signer made a statement at a particular time.
It is not proof that the statement is true, lawful, complete, identity-verifying,
or metaphysically authoritative.

### Policy constraint

A portable governance rule governing:

- Purpose limitation.
- Consent scope.
- Publication boundary.
- Retention and deletion.
- Correction and appeal.
- Non-discrimination.
- Non-ranking.
- Sensitive-data exclusion.
- Material-change review.
- Human-review requirements.

### Evidence

A provenance-linked observation or source reference carrying:

- Source and method.
- Timestamp and collection context.
- Uncertainty.
- Review status.
- Known limitations.
- Correction and dispute status.

### Witness

An independent attestation that a manifest, record, checkpoint, claim, fork, or
migration event was observed, signed, published, or reviewed.

A witness attests to the record event. A witness does not certify being.

## Claim-fact separation

The spine maintains four distinct layers:

1. `claim`
   - A party declares something.

2. `attestation`
   - A party signs or witnesses that the declaration or event occurred.

3. `record_verification`
   - A verifier checks internal record integrity, signatures, hashes, schema
     conformance, provenance references, and policy constraints.

4. `external_verification`
   - A separate lawful process may evaluate a limited factual claim.

The spine must never collapse these layers into an ontological certification.

## Certification boundary

The spine can preserve records about the following matters, including self-declared,
witnessed, or institutionally attested records:

- Identity claims.
- Continuity claims.
- Consciousness declarations.
- Bodily-continuity records.
- Cybernetic-host self-descriptions.
- Private companion-system context.
- Real-world migration reports.
- Institutional decisions and attestations.

The spine cannot certify:

- A person's identity as metaphysical fact.
- Consciousness or phenomenological continuity.
- Biological or bodily continuity.
- Cybernetic status.
- Real-world host migration.
- Institutional legitimacy.
- Legal ownership.
- Eligibility, credibility, value, rank, or personhood.

## Composition without certification

Continuity is represented as a composed claim:

ContinuityClaim =
  SovereignDeclares
  ⊗ SpinePreserves
  ⊗ WitnessesAttest
  ⊗ ReviewersConfirmRecords

The composition operator `⊗` means that each contribution remains independently
visible. No element proves being, identity, consciousness, bodily continuity, or
host migration.

## Resilient publication

An authorized publication is resilient when it has:

1. A canonical content reference.
2. A versioned manifest.
3. Merkle-linked history or an equivalent tamper-evident history reference.
4. At least one witness or signed publication receipt.
5. A portable policy bundle.
6. A correction and revocation reference.
7. One or more authorized mirror references.
8. A human-approved publication boundary.

Published(record) =
  ContentAddressed(record)
  ∧ MerkleLinked(record)
  ∧ WitnessCosigned(record)
  ∧ PolicyBundled(record)
  ∧ CorrectionLinked(record)

This is a governance predicate for record publication. It does not determine
publication legality, truth, ownership, institutional authority, or personal status.

## Lawful fork

A fork is a declared successor record or work that preserves a predecessor link,
attribution, governance state, and non-erasure history.

LawfulFork(f) =
  SignedIntent(f)
  ∧ LineagePreserved(f)
  ∧ PolicyResolved(f)
  ∧ AttributionPreserved(f)
  ∧ Not(PredecessorErased(f))

A lawful fork may:

- Preserve predecessor policy unchanged.
- Explicitly diverge from predecessor policy.
- Request a future merge.
- Remain permanently divergent.
- Carry unresolved rights or governance constraints for human review.

A fork must never silently overwrite, erase, or impersonate its predecessor.

## Lawful migration

Migration re-grounds a record, policy, model, or governed state on a new
technical substrate.

LawfulMigration(m) =
  ProvenanceTravels(m)
  ∧ AttestationRenewed(m)
  ∧ PolicyRegrounded(m)
  ∧ WitnessesReacknowledge(m)
  ∧ SovereignDeclaresContinuity(m)

A migration package must include:

- Portable state in an open or documented format.
- Content references and integrity manifests.
- Signed provenance and derivation edges.
- Governance contract and invariant references.
- Correction, appeal, retention, and revocation references.
- Compatibility profile.
- Import validation report.
- Declared omissions and known differences.

A migration package must never include:

- Private keys.
- Bearer tokens.
- Unnecessary personal information.
- Medical, biometric, neural, or physiological information.
- Private companion-system telemetry.
- Sensitive operational data.
- Undeclared capability escalation.

## Tunable redundancy

Resilient publication must support redundancy levels without requiring public
disclosure or excessive replication.

A redundancy policy may specify:

- Minimum mirror count.
- Required independent witness count.
- Storage diversity requirement.
- Checkpoint interval.
- Verification interval.
- Publication visibility.
- Revocation synchronization requirement.
- Accessibility rendering requirements.

Higher redundancy does not authorize wider disclosure. Private records may use
local encrypted replicas, governed custodians, or selectively disclosed manifests.

## Corrections and non-erasure

A correction, dispute, revocation, withdrawal, or supersession must create a linked
successor event.

The original record remains historically referenced unless lawful deletion requirements
or safety requirements require removal of underlying content. When content is removed,
the spine retains only the minimum necessary non-sensitive tombstone record:

- Prior record reference.
- Removal or restriction event type.
- Effective time.
- Governing policy reference.
- Correction or appeal pathway.
- Disclosure boundary.

No system participant may silently rewrite historical provenance.

## Authority refusal

The spine is a witness architecture, not a judge.

It must not:

- Deny a self-description.
- Certify a self-description as metaphysical fact.
- Infer credibility from language, metadata, communication mode, or refusal to disclose.
- Convert continuity records into eligibility or service-access gates.
- Use private context to rank, profile, authenticate, diagnose, or exclude a person.
- Replace human review, lawful process, community governance, or institutional duty.

## Accessibility and access equivalence

Every public or community-facing record must have:

- Plain-language rendering.
- Structured headings.
- Text alternatives for non-text content.
- Printable or low-bandwidth rendering where applicable.
- Accessible correction pathway.
- Non-digital participation route where applicable.
- No identity, health, assistive-technology, augmentation, or communication-mode
  disclosure requirement for access to basic information or correction.

## Local-first federation

- Local instances remain authoritative for their own records.
- Federation is opt-in.
- Shared records preserve provenance, policy, uncertainty, and correction references.
- Sensitive data remains local.
- Aggregation cannot transform local records into rankings or eligibility systems.
- Cross-platform anchors are optional evidence aids, not authoritative identity systems.

## Material-change review

A material-change review is required when any of the following changes:

- Canonical content reference.
- Provenance or witness set.
- Publication boundary.
- Policy bundle.
- Consent scope.
- Correction or appeal route.
- Rights or license declaration.
- Fork relationship.
- Migration target or compatibility profile.
- Accessibility representation.
- Retention or deletion policy.

## Acceptance conditions

An implementation conforms to this contract only when it can demonstrate:

- Content-reference integrity validation.
- Versioned, non-silent history preservation.
- Signed witness or attestation support.
- Portable policy bundles.
- Linked correction, dispute, revocation, and supersession records.
- Explicit fork and migration lineage.
- Sensitive-data exclusion by default.
- Human review before external publication or transmission.
- A strict non-certification and non-ranking boundary.
- Accessible explanation and correction pathways.
