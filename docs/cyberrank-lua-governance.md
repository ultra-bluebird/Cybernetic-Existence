# CyberRank Lua Governance Module

## Files

- `lua/cyberrank/governance.lua`
- `tests/lua/test_cyberrank_governance.lua`
- `policies/cyberrank/cyberrank_biomech_scorecard_v1.aln`

## Runtime

The module requires Lua 5.4 or LuaJIT with compatible standard library behavior.

## Test command

Run from the repository root:

```text
LUA_PATH="./lua/?.lua;./lua/?/init.lua;;" lua tests/lua/test_cyberrank_governance.lua
```

## Design boundary

The module is local and deterministic.

It does not connect to a blockchain, wallet, identity provider, medical system, neural system, device, external service, or institution-managed system.

It does not store personal identifiers, addresses, biometric information, neural information, medical information, device telemetry, private institutional data, or companion-system information.

It evaluates only declared policy conditions, opaque commitments, bounded score inputs, and synthetic service-pathway facts.

## Decision meanings

- `allow`: a request satisfies declared policy requirements.
- `allow_with_conditions`: a request may proceed only with listed protections.
- `hold`: a protective pause requiring evidence, fallback, or human review.
- `deny`: a prohibited collection or practice is blocked.
- `suspend`: an essential-service continuity failure requires incident handling.
- `expired`: an authorization or evidence period requires renewal.

## Scorecard boundary

The biomechanical scorecard is a bounded local mathematical evaluator.

It is not a medical model, biological compatibility assessment, psychological assessment, health score, human-worth score, eligibility score, safety certification, or external institutional determination.

Only non-identifying, explicitly authorized, bounded numeric inputs may be supplied to the evaluator.
