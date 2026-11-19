# Corridor Negotiation Section 1 Research Notes

## Formal gate

Formal bounded verification is the admission requirement for any policy configuration.

A configuration is Monte Carlo eligible only when:

\[
\operatorname{MonteCarloEligible}(p)
=
\operatorname{BoundedInvariantsPass}(p)
\land
\operatorname{PrivacyContractPass}(p)
\]

A performance improvement cannot compensate for failure of any hard invariant.

## Hard invariants

- Pedestrian-first precedence.
- Mobility-device continuity.
- No forced passage through insufficient clear width.
- Category non-discrimination.
- No penalty for omitted optional service-urgency data.
- Autonomous bot fail-safe behavior under missing, stale, contradictory, malformed, or unavailable evidence.
- Deterministic totality for every valid bounded state.
- Aggregate-only simulation output.

## Evidence boundary

Bounded verification establishes correctness for the registered finite input domain.

Synthetic Monte Carlo results characterize behavior under registered assumptions. They do not establish field reliability, legal enforceability, or universal correctness outside the model.

## Comparative method

Every candidate configuration is compared against the frozen baseline using common random numbers.

Each baseline-candidate pair uses the same:

- Scenario manifest.
- Registered seed list.
- Synthetic actor-arrival stream.
- Synthetic fault stream.
- Corridor geometry.
- Trial count.

A candidate is eligible only when all hard invariants pass, protected-access outcomes do not decline, unsafe-configuration outcomes do not increase, and aggregate-only privacy requirements remain satisfied.
