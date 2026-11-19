# Augmented Governance Core

`augmented-governance-core` provides two independently testable foundations:

- Physiological-envelope interfaces and bounded EvoMode scaling
- Rights-preserving policy evaluation for essential-service access, recognition, consent, accessibility, review, and contestability

## Design boundaries

The envelope module evaluates whether a host state is within a typed physiological envelope and applies validated mode scaling.

The rights module evaluates a civic or service request without treating wealth, financial rank, optional telemetry, connectivity, or recognition as a condition of essential-service access.

The modules share a crate because they are part of the same governance foundation. They do not share decision inputs, state identifiers, or authority channels.

## Rights decision order

The evaluator applies constraints in this order:

1. Reject wealth dependency for an essential service.
2. Reject recognition-to-financial-rank conversion.
3. Reject prohibited processing purposes.
4. Reject data collection beyond the necessary set.
5. Reject unauthorized sensitive processing.
6. Preserve Recognition at Rest through equivalent access.
7. Preserve essential-service access when human review is required.
8. Route inaccessible paths to urgent human handoff.
9. Allow only requests that satisfy all preceding constraints.

This ordering prevents a rest or review state from bypassing a prohibited financial-ranking, profiling, overcollection, or unauthorized-processing request.

## Local verification

Run these commands from this crate directory:

```sh
cargo fmt --check
cargo test
cargo clippy --all-targets --all-features -- -D warnings
```

## AI-chat integration

`Request` and `DecisionRecord` are serializable.

An AI-chat integration should:

- Construct a request only from explicitly supplied and purpose-relevant inputs.
- Present `reason_code`, accessible-notice requirements, review obligations, correction availability, and appeal availability to the person.
- Avoid collecting or emitting raw sensitive data unless the declared purpose and authority permit it.
- Treat `ProvideEquivalentAccess` and `UrgentHumanHandoff` as affirmative continuity obligations.
- Preserve an accessible human route whenever automation cannot safely conclude a decision.
