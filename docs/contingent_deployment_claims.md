# Contingent Deployment Claims

## Purpose

This document defines the claims that Augmented-Hub research workflows may
make about privacy, advisories, aggregation, attestation, and deployment.

The system does not treat aggregation, encryption, attestation, differential
privacy, decentralization, or advisory classification as self-proving
guarantees.

## Permitted claims

A workflow may state that it is:

- aggregate-oriented when it releases summaries rather than direct records;
- privacy-risk-reducing when documented controls reduce identified disclosure
  risks for a defined threat model;
- differentially private only when the mechanism, contribution bounds,
  sensitivity, privacy parameters, composition method, and privacy-accounting
  decision are recorded;
- advisory-only when the module has no direct physical-control, enforcement,
  service-denial, or command-dispatch capability;
- cryptographically verifiable when a verifier can validate a signature,
  proof, receipt inclusion record, or other defined cryptographic predicate;
- operationally ready only for a defined environment after completion of
  safety, security, privacy, accessibility, governance, and community review.

## Prohibited claims

A workflow must not claim that:

- aggregate data is inherently private or anonymous;
- a privacy mechanism eliminates disclosure or group-harm risk;
- an advisory is neutral, objective, or socially legitimate without governance;
- a cryptographic key-control proof establishes every assertion about a person;
- a credential creates a universal legal identity or legal status;
- a voluntary self-description requires proof to receive dignity, accessibility,
  privacy, correction, appeal, or human assistance;
- a heat, ecological, or rights score is a final decision about a person,
  community, legal entitlement, or ecological condition;
- a software artifact independently verifies medical, neural, physiological,
  cybernetic, or body-integrated status.

## Required review gates

A public or shared release requires all of the following:

1. A written purpose and intended decision scope.
2. Data minimization and retention review.
3. An adversary and linkage-risk model.
4. Reconstruction, membership, attribute, and mosaic-risk assessment.
5. Sensitive-location and group-harm assessment.
6. Accessibility review and a correction path.
7. Human approval recorded in a reviewable audit trail.
8. A material-change review when data granularity, weights, privacy parameters,
   release cadence, model revision, or geography changes.

## Attestation scope

Cryptographic attestations may prove bounded technical facts such as key
control, signature validity, receipt inclusion, credential status, or a
specific policy predicate.

They do not automatically prove legal identity, personhood, medical facts,
augmentation status, consent in all contexts, ownership, institutional
affiliation, or universal non-repudiation.

## Equal access

Voluntary self-description and privacy preferences must be respected without
proof requirements. Any credential or proof option must have an accessible,
equivalent non-cryptographic path for communication support, correction,
appeal, privacy requests, and human assistance.
