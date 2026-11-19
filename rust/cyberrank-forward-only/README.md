# cyberrank-forward-only

`cyberrank-forward-only` is a small Rust crate for private, voluntary,
forward-only progression records.

It provides:

- A private tier vocabulary from `T0` through `T4`.
- One-step-only forward progression.
- Rejection of skipped tiers.
- Rejection of rollback or downgrade requests.
- Completeness-signal validation.
- Explicit owner authorization.
- Explicit non-interference confirmation.
- Explicit private-scope confirmation.
- A receipt that explicitly prohibits public export and eligibility use.

## Private-use boundary

The terms in this crate are private-use project vocabulary.

They do not represent:

- A public identity.
- A public ranking.
- A verification result.
- A diagnosis.
- A medical, neural, biometric, or technical assessment.
- A certification.
- A legal or institutional status.
- An eligibility criterion.
- A service-access criterion.
- A credibility score.
- A requirement to disclose private information.
- A claim about a person's body, mind, technology, companion system, or
  institutional relationship.

A progression receipt records only that the supplied private request satisfied
the crate's local deterministic checks.

It does not authenticate a person, validate a self-description, assess a
real-world system, or authorize any external action.

## Design principles

The crate is designed around the following invariants:

1. **Private scope**: every accepted receipt has
   `public_export_permitted = false`.

2. **No eligibility use**: every accepted receipt has
   `eligibility_use_permitted = false`.

3. **Forward-only progression**: a request can move only to the immediately
   next private tier.

4. **No rollback**: a request for a lower tier is rejected.

5. **No skipped tiers**: a request for a tier beyond the immediate next tier
   is rejected.

6. **Owner authorization**: a progression requires explicit local owner
   authorization.

7. **Non-interference**: a progression requires an affirmative
   non-interference check.

8. **Continuity confirmation**: completeness requires an explicit continuity
   confirmation.

9. **Evidence completeness**: all declared completeness signals must meet the
   local threshold.

10. **No external actuation**: this crate validates a local request and returns
    a local receipt only. It does not send, publish, update, revoke, rank,
    export, or control anything.

## Tier vocabulary

```text
T0 -> T1 -> T2 -> T3 -> T4
```

`PrivateTier::next()` returns the immediate successor:

| Current tier | Next private tier |
|---|---|
| `T0` | `T1` |
| `T1` | `T2` |
| `T2` | `T3` |
| `T3` | `T4` |
| `T4` | No further tier |

The crate does not support:

```text
T2 -> T1
T0 -> T2
T1 -> T3
T4 -> any later tier
```

## Completeness signals

A progression request requires these signals:

```rust
pub struct CompletenessSignals {
    pub boundary_completeness: f64,
    pub metadata_completeness: f64,
    pub evidence_completeness: f64,
    pub quality_review_completeness: f64,
    pub continuity_confirmation: bool,
}
```

Each numeric signal must be finite and lie in:

```text
0.0 <= signal <= 1.0
```

The current local completion predicate is:

\[
\operatorname{ProgressionComplete}
=
(b \ge 0.57)
\land
(m \ge 0.57)
\land
(e \ge 0.57)
\land
(q \ge 0.57)
\land
c
\]

Where:

- \(b\) is `boundary_completeness`.
- \(m\) is `metadata_completeness`.
- \(e\) is `evidence_completeness`.
- \(q\) is `quality_review_completeness`.
- \(c\) is `continuity_confirmation`.

The threshold is a local crate policy value. It should be versioned and reviewed
if changed. It must not be interpreted as a universal measure of a person,
identity, capability, credibility, health, augmentation, or institutional
standing.

## Progression requirements

A request is accepted only when all of the following hold:

\[
\operatorname{RequestedTier}
=
\operatorname{CurrentTier.next()}
\]

\[
\operatorname{ProgressionComplete}
=
\texttt{true}
\]

\[
\operatorname{OwnerAuthorized}
=
\texttt{true}
\]

\[
\operatorname{NonInterferenceCheckPassed}
=
\texttt{true}
\]

\[
\operatorname{PrivateScopeConfirmed}
=
\texttt{true}
\]

\[
\operatorname{RequestId}
\ne
\varnothing
\]

An accepted receipt always satisfies:

\[
\operatorname{PublicExportPermitted}
=
\texttt{false}
\]

\[
\operatorname{EligibilityUsePermitted}
=
\texttt{false}
\]

## Usage

```rust
use cyberrank_forward_only::{
    advance_private_tier,
    CompletenessSignals,
    PrivateTier,
    ProgressionRequest,
};

let signals = CompletenessSignals {
    boundary_completeness: 0.57,
    metadata_completeness: 0.82,
    evidence_completeness: 0.91,
    quality_review_completeness: 0.70,
    continuity_confirmation: true,
};

let request = ProgressionRequest {
    current_tier: PrivateTier::T1,
    requested_tier: PrivateTier::T2,
    owner_authorized: true,
    noninterference_check_passed: true,
    private_scope_confirmed: true,
    request_id: "private-forward-progression-example".to_owned(),
};

let receipt = advance_private_tier(&request, signals)?;

assert_eq!(receipt.previous_tier, PrivateTier::T1);
assert_eq!(receipt.resulting_tier, PrivateTier::T2);
assert!(!receipt.public_export_permitted);
assert!(!receipt.eligibility_use_permitted);

# Ok::<(), cyberrank_forward_only::ProgressionError>(())
```

## Errors

| Error | Meaning |
|---|---|
| `InvalidSignalRange` | A completeness signal is non-finite or outside `[0.0, 1.0]` |
| `IncompleteEvidence` | One or more completeness conditions are not met |
| `MissingOwnerAuthorization` | Explicit owner authorization is absent |
| `NonInterferenceCheckFailed` | The local non-interference check did not pass |
| `PublicScopeNotAllowed` | The request did not confirm private scope |
| `NoFurtherTierAvailable` | The current tier is `T4` |
| `TierSkipNotAllowed` | The request is not for the immediate successor |
| `DowngradeNotAllowed` | The request asks for a lower tier |
| `EmptyRequestId` | The request identifier is empty or whitespace only |

## Serialization

The types derive `Serialize` and `Deserialize` using `serde`.

`PrivateTier` serializes in snake case:

```json
{
  "current_tier": "t1",
  "requested_tier": "t2"
}
```

A serialized receipt includes explicit non-public and non-eligibility flags:

```json
{
  "previous_tier": "t1",
  "resulting_tier": "t2",
  "request_id": "private-forward-progression-example",
  "event_kind": "private_forward_progression",
  "public_export_permitted": false,
  "eligibility_use_permitted": false
}
```

Serialization does not itself provide encryption, consent enforcement, key
management, identity verification, public dissemination permission, or
provenance integrity. Those are separate responsibilities for the calling
application and its policy layer.

## Build and test

Build the crate:

```bash
cargo build
```

Run tests:

```bash
cargo test
```

Check formatting:

```bash
cargo fmt --check
```

Run lints:

```bash
cargo clippy --all-targets --all-features -- -D warnings
```

## Recommended integration

Use this crate behind a narrow local interface.

A caller should:

1. Validate and minimize the inputs it supplies.
2. Keep any voluntary self-description, continuity context, technical context,
   evidence material, and private metadata outside public exports.
3. Obtain the relevant local authorization before requesting progression.
4. Call `advance_private_tier`.
5. Store a receipt only in a purpose-limited, retention-bounded evidence
   ledger if storage is necessary.
6. Preserve the explicit `false` values for public export and eligibility use.
7. Provide a human-readable explanation and correction path for any rejected
   request.
8. Require explicit approval before any external action.

A caller must not use a receipt to:

- Assign public status.
- Determine access to services, resources, employment, housing, health care,
  benefits, or civic participation.
- Evaluate credibility or competence.
- Infer private information.
- Authenticate a real-world system.
- Create a transferable reputation, financial asset, token, or market.
- Override consent, privacy, correction, or appeal processes.

## Kani verification targets

The library is suitable for bounded Kani harnesses over enum values and
boolean authorization inputs.

Recommended properties:

\[
\operatorname{RequestedTier}
<
\operatorname{CurrentTier}
\Longrightarrow
\operatorname{advance\_private\_tier}
=
\operatorname{Err}(
\texttt{DowngradeNotAllowed}
)
\]

\[
\operatorname{RequestedTier}
\ne
\operatorname{CurrentTier.next()}
\Longrightarrow
\operatorname{advance\_private\_tier}
=
\operatorname{Err}(
\texttt{TierSkipNotAllowed}
)
\]

\[
\neg
\operatorname{OwnerAuthorized}
\Longrightarrow
\operatorname{advance\_private\_tier}
=
\operatorname{Err}(
\texttt{MissingOwnerAuthorization}
)
\]

\[
\neg
\operatorname{NonInterferenceCheckPassed}
\Longrightarrow
\operatorname{advance\_private\_tier}
=
\operatorname{Err}(
\texttt{NonInterferenceCheckFailed}
)
\]

\[
\operatorname{Receipt}
\Longrightarrow
\neg
\operatorname{Receipt.public\_export\_permitted}
\land
\neg
\operatorname{Receipt.eligibility\_use\_permitted}
\]

## Security and privacy

- Treat all caller-provided values as untrusted input.
- Do not log private request content unless a separate, explicit,
  purpose-limited retention policy authorizes it.
- Prefer local storage and minimal disclosure.
- Do not use self-description as evidence of eligibility, identity,
  capability, credibility, health, augmentation, or institutional standing.
- Keep authorization, consent, cryptographic signatures, and external-action
  approval in separate policy-governed layers.
- Revalidate all data when crossing a language, process, storage, or network
  boundary.
- Treat a receipt as an application data object, not as a credential or proof
  about a person.

## License

Licensed under either of:

- MIT License
- Apache License, Version 2.0

at the user's option.
