# Phase One Implementation: Core Contract

## Objective

Establish the local‑first governance substrate with shared envelopes, validation, and regression tests.

## Checklist

- [ ] Place JSON Schemas in `schemas/envelopes/`
- [ ] Place SQLite schema in `sql/schema.sql`
- [ ] Install Node.js and dependencies: `npm install ajv ajv-formats`
- [ ] Create fixture files in `fixtures/positive/` and `fixtures/negative/`
- [ ] Run validator: `node js/validator.js`
- [ ] All positive fixtures pass; all negative fixtures fail.
- [ ] Import SQLite schema into a local database and test insert of valid envelopes.
- [ ] Add triggers for audit log (as shown).
- [ ] Commit all artifacts to repository.

## Next Steps

Once the contract and validators are stable:

1. Port the validator logic to C++ (with valijson) for the corridor evaluator.
2. Port to Kotlin (with Konform) for JVM modules.
3. Port to Lua (with api7/jsonschema) for edge predicate engines.
4. Extend fixtures to cover non‑compensation scenarios (active blocking conditions).
5. Connect public‑service modules (cooling centers, public‑reserve compute) through the DecisionEnvelope contract.
6. Connect ecological modules (additionality, species impact) through EvidenceEnvelope.
7. Implement the SQLite store as the primary audit and consent repository.
8. Write integration tests that simulate consent revocation, sensor failure, and review escalation.

## Verification

The core contract is considered implemented when:

- The validator suite passes without network access.
- All fixtures are deterministic and checked into version control.
- A local SQLite database can store and retrieve envelopes.
- The audit log captures every insert and state change.
- The non‑compensation rule is encoded in the decision logic (i.e., any blocking condition prevents `permitted`).
- Public‑service modules cannot be blocked by operational telemetry failure (safe fallback).
- Accessibility explanations are available for all decision codes.
- Terminology continuity is preserved across model updates (tested by editing a profile and verifying the change is logged).
