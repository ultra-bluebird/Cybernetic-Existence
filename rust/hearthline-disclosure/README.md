# hearthline-disclosure

`hearthline-disclosure` defines privacy-preserving contracts for user-controlled
recovery-context disclosure in Hearthline.

The crate does not determine whether a recovery statement is true. It does not
assign trust, safety, compatibility, recovery stage, relationship readiness, or
social value to a person. It defines the valid disclosure modes and validation
boundaries that a reviewed presentation provider must satisfy.

## Scope

Hearthline supports several equally valid disclosure choices:

- Keep recovery context private.
- Share a personal statement in the user's own words.
- Present proof that a personal commitment existed before a selected threshold.
- Present a narrow optional attestation issued by a user-selected third party.

No disclosure mode is more honest, more trustworthy, safer, more eligible, or more
valuable than another. Disclosure mode must not influence matching, candidate
presentation, ranking, profile visibility, action-integrity controls, account
capabilities, or public status.

## Disclosure modes

| Mode | Meaning | Supported claim |
| --- | --- | --- |
| `None` | The holder shares no recovery context. | No claim is made. |
| `ExplicitStatement` | The holder shares user-authored text. | The holder chose to state the text. |
| `SelfCommitmentProof` | The holder presents a time-based commitment proof. | A commitment existed before a threshold; not that the statement is true. |
| `AttestationProof` | The holder presents a narrow optional issuer-backed proof. | Only the predicate signed by the selected issuer. |

A self-created commitment cannot prove sobriety duration, treatment participation,
or the truth of any health-related statement. It can prove only that a commitment
existed before a defined time threshold.

An attestation proof may support a limited issuer-signed predicate, but it does not
certify current status, personal safety, dating readiness, compatibility, honesty,
or social worth.

## Privacy guarantees

The crate enforces the following contract properties:

- Disclosure must be user initiated.
- Disclosure must be recipient scoped.
- Disclosure must be purpose scoped.
- Recovery-status inference is prohibited.
- Matching use is prohibited.
- Ranking use is prohibited.
- Public visibility is prohibited.
- Person-level analytics use is prohibited.
- Central registry creation is prohibited.
- External action authority is prohibited.

The crate does not create a public badge, issuer ranking, holder directory, recovery
claim registry, or relationship eligibility signal.

## Non-goals

This crate does not:

- Implement cryptographic proof algorithms.
- Implement zero-knowledge proving systems.
- Manage issuer keys.
- Store credentials.
- Store recovery claims.
- Store recovery status.
- Verify clinical, sponsor, peer, or organizational authority.
- Send disclosures.
- Decide whether a recipient should receive a disclosure.
- Revoke CommonGround consent scopes.
- Perform matching or profile ranking.
- Contact issuers, recipients, clinicians, sponsors, peers, or external services.

A production proof provider must be separately selected, reviewed, and integrated
through the `ProofPresentationProvider` trait. That provider must use an
interoperable, independently reviewed proof format and must preserve the contract
invariants defined by this crate.

## Integration model

```text
User
  → Hearthline disclosure interface
  → CommonGround consent decision
  → hearthline-disclosure validation
  → reviewed proof presentation provider
  → recipient-scoped presentation

Afterlight Ledger
  ← content-free operational event only

TrueCompass, Lantern, matching, profiles, and BridgeAdapters
  × no disclosure-mode or proof-result access
```

The presentation flow requires current CommonGround consent before a proof or
statement can be rendered on a Hearthline-controlled surface.

## Example

```rust
use hearthline_disclosure::{
    validate_request,
    DisclosureMode,
    DisclosureRequest,
};

let request = DisclosureRequest {
    subject_ref: "acct_7Wq3sR4tX9".to_owned(),
    recipient_ref: "match_4Vn8Lp2cQ6".to_owned(),
    mode: DisclosureMode::None,
    purpose: "PRIVATE_CONVERSATION".to_owned(),
    requested_at: std::time::SystemTime::now(),
    user_initiated: true,
};

validate_request(&request)?;
```

A disclosure request is valid only when it has an opaque subject reference, an opaque
recipient reference, a non-empty purpose, and explicit user initiation.

## Proof provider contract

A proof presentation provider must implement:

```rust
pub trait ProofPresentationProvider {
    fn create_self_commitment_presentation(
        &self,
        request: &DisclosureRequest,
        threshold: SystemTime,
    ) -> Result<DisclosurePresentation, DisclosureError>;

    fn create_attestation_presentation(
        &self,
        request: &DisclosureRequest,
        predicate: ProofPredicate,
    ) -> Result<DisclosurePresentation, DisclosureError>;
}
```

The provider must never return a presentation that permits:

```text
- Recovery-status inference
- Matching use
- Ranking use
- Public visibility
- Central registry entry creation
- External action authority
```

## Validation rules

`validate_request` rejects requests that:

- Omit a subject reference.
- Omit a recipient reference.
- Omit a disclosure purpose.
- Were not explicitly user initiated.

`validate_presentation` rejects presentations that:

- Permit recovery-status inference.
- Permit matching, ranking, or public use.
- Permit central registry entry creation.
- Permit external actions.
- Omit a required predicate for proof modes.
- Include a predicate for `None` or `ExplicitStatement`.

## Security model

This crate is a contract and validation boundary, not a complete cryptographic system.

The security properties of any proof presentation depend on:

- The selected proof format.
- The issuer or time-witness trust model.
- Credential and key lifecycle management.
- Recipient-scoped presentation construction.
- Current CommonGround consent.
- Correct client and service implementation.
- Storage, retention, and audit controls.
- User understanding of the difference between a personal statement, a commitment
  timing proof, and an issuer-backed predicate.

The crate does not claim that a proof makes a person safe, honest, sober, suitable,
compatible, or ready for a relationship.

## Development

Minimum supported Rust version:

```text
Rust 1.85
```

Build the crate:

```sh
cargo build
```

Run tests after test modules are added:

```sh
cargo test
```

Run formatting checks:

```sh
cargo fmt --check
```

Run lint checks:

```sh
cargo clippy --all-targets --all-features -- -D warnings
```

## Repository layout

```text
rust/hearthline-disclosure/
├── Cargo.toml
├── README.md
└── src/
    └── lib.rs
```

Planned supporting paths in the Hearthline repository:

```text
schemas/hearthline-recovery-context-disclosure.schema.json
kotlin/hearthline-disclosure/src/main/kotlin/org/augmentedhub/hearthline/disclosure/
  RecoveryContextDisclosureService.kt
policies/hearthline-minimal-recovery-disclosure.aln
docs/hearthline/hearthline-production-blueprint.md
```

## License

Licensed under either of:

- MIT License
- Apache License, Version 2.0

at the option of the user.
