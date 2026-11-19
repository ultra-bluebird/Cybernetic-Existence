# cybernetic-host-governance

`cybernetic-host-governance` provides a narrow, non-certifying Rust contract for
acknowledging voluntary identity declarations and related user-selected preferences.

The crate supports acknowledgment. It does not verify, certify, diagnose, register,
rank, score, infer, publish, authenticate, or determine eligibility from a person's
identity declaration.

## Scope

The crate models a platform response to voluntary information such as:

- Preferred form of address
- Communication preference
- Access preference
- Privacy boundary
- Continuity preference

A declaration may be absent, user-provided, or user-revoked.

```text
NOT_PROVIDED
USER_PROVIDED
USER_REVOKED
```

The resulting acknowledgment state is:

```text
NO_ACKNOWLEDGMENT_NEEDED
ACKNOWLEDGED
REVOKED_BY_USER
```

## Core rule

```text
A voluntary declaration may be acknowledged without requiring proof.
Acknowledgment is not certification.
Acknowledgment is not verification.
Acknowledgment is not public identity.
Acknowledgment is not a score.
Acknowledgment is not an eligibility decision.
```

## Prohibited uses

Every valid `IdentityAcknowledgment` record must prohibit:

```text
- Public visibility
- Identity verification requirements
- Identity certification requirements
- Medical-information requirements
- Biometric-information requirements
- Neural-information requirements
- Institutional-affiliation requirements
- Identity inference from behavior
- Matching use
- Ranking use
- Eligibility use
- Fraud-scoring use
- Advertising use
- External action authority
```

## Example

```rust
use cybernetic_host_governance::{
    acknowledge_declaration,
    validate_acknowledgment,
    DeclarationState,
};

let acknowledgment = acknowledge_declaration(
    DeclarationState::UserProvided,
    true,
    true,
    true,
    true,
    true,
);

validate_acknowledgment(&acknowledgment)?;
assert!(!acknowledgment.public_visibility_allowed);
assert!(!acknowledgment.identity_verification_required);
assert!(!acknowledgment.ranking_use_allowed);
assert!(!acknowledgment.external_action_authorized);
```

## Non-goals

This crate does not:

```text
- Maintain a public registry
- Store legal names
- Authenticate users
- Verify or certify an identity
- Determine medical, neural, biometric, disability, or institutional status
- Infer identity from language, behavior, metadata, devices, or communication mode
- Create a trust score, acceptance score, reputation score, or eligibility score
- Decide access to public services
- Perform external actions
- Transmit personal data
- Contact institutions, reviewers, or external systems
```

## Integration

A higher-level system may use this crate to validate that a voluntary acknowledgment
record remains private and non-evaluative.

The crate should be used with separate policies and service controls that preserve:

```text
- Minimal disclosure
- Accessible communication
- Correction
- Appeal
- Human fallback
- Non-interference
- Material-change review
```

The crate does not itself implement those services.

## Development

Minimum supported Rust version:

```text
Rust 1.86
```

Build:

```sh
cargo build
```

Test:

```sh
cargo test
```

Format check:

```sh
cargo fmt --check
```

Lint:

```sh
cargo clippy --all-targets --all-features -- -D warnings
```

## Repository layout

```text
rust/cybernetic-host-governance/
├── Cargo.toml
├── README.md
└── src/
    ├── lib.rs
    └── acknowledgment.rs
```

## License

Licensed under either of:

- MIT License
- Apache License, Version 2.0

at the option of the user.
