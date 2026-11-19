# M-LCC Research Assurance Matrix

## Purpose

This matrix records what M-LCC currently demonstrates, what evidence supports
that demonstration, what the system does not claim, and the next verification
step required before stronger deployment claims are made.

## Evidence Classes

| Class | Meaning |
|---|---|
| SIMULATED | Deterministic local model, mock, or fixture |
| SYNTHETIC | Generated test vector or corpus |
| LOCAL POLICY | Derived from local configuration and pure policy logic |
| VERIFIED LOCALLY | Confirmed by deterministic code, local validation, or reproducible test |
| MANUAL LAB ENTRY | Entered from a documented manual measurement |
| REQUIRES REVIEW | Requires independent security, accessibility, safety, privacy, or engineering review |
| UNAVAILABLE | No evidence exists in the current build |

## Feature Matrix

| Feature | Current behavior | Evidence class | Prohibited claim | Verification next step |
|---|---|---|---|---|
| Capability intersection | Computes requested ∩ policy ∩ consent ∩ purpose | LOCAL POLICY | Does not prove external authorization safety | Unit and property tests for all scope dimensions |
| Lease countdown | Local UI countdown and terminal flow | SIMULATED | Does not prove hardware watchdog timing | Separate monotonic watchdog process model |
| Replay injection | Demonstrates duplicate-frame rejection | SYNTHETIC | Does not prove network protocol replay resistance | Canonical frame codec and cross-process replay tests |
| Audit Vault | Hash-linked local receipts | VERIFIED LOCALLY | Does not prove immutable storage | Signed checkpoints and tamper-recovery test |
| Organichain manifest | Exports local receipt manifest | VERIFIED LOCALLY | Does not prove global ledger consensus | Local provenance verification contract |
| Swarm Simulator | Displays deterministic quorum rounds | SIMULATED | Does not model physical nanosystems | Fixed BFT test-vector corpus and TLA+ model |
| Enclosure Lab | Displays modeled thermal and EMC state | SIMULATED | Does not prove enclosure compliance | Manual laboratory measurement protocol |
| CyberRank profile | Applies private governance preferences | LOCAL POLICY | Does not score people or determine eligibility | Governance-card conformance tests |
| Revoke control | Ends simulated session state | VERIFIED LOCALLY | Does not control any external hardware | Keyboard, pointer, and screen-reader E2E tests |
| Human fallback | Displays user-configured local options | LOCAL POLICY | Does not guarantee third-party response | Offline accessibility and workflow testing |
| Browser persistence | Saves prototype state locally | VERIFIED LOCALLY | Does not provide encrypted storage | Native encrypted local-store design |
| Offline mode | UI works without remote backend | VERIFIED LOCALLY | Does not prove all browser APIs are offline | Network-blocked E2E test |
