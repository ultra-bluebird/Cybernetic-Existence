# CyberRank AI-Chat Task Board

## Purpose

This task board defines repository work that can be completed through AI-chat-assisted design, specification, code generation, review, test generation, and documentation.

No task requires fieldwork, hardware access, external identity verification, municipal coordination, chain deployment, clinical data collection, or external service access.

## Immediate Tasks

| Priority | Task | Deliverable | Completion Evidence |
|---|---|---|---|
| High | Validate TLA+ syntax and action completeness | Updated TLA+ module and model configuration | Type invariant, safety invariants, and liveness properties declared |
| High | Define shared cross-layer fixtures | Rights decision vector file | Every vector contains input, expected outcome, reason code, and invariant mapping |
| High | Add Rust fixture loader | Rust conformance test module | Every fixture is accepted or rejected exactly as specified |
| High | Add Rego fixture conformance | Rego test module | Every fixture yields the expected policy outcome |
| High | Define local policy profile schema | JSON Schema | Schema rejects profiles that weaken core invariant attestations |
| High | Write Phoenix profile template | Local policy profile instance | Template validates against schema and contains no personal or live operational data |
| Medium | Expand Research Object Cards | Research card examples | Each core invariant has claim, status, evidence path, limitation, and next objective |
| Medium | Add policy mutation catalog | Mutation test plan | Every core gate has at least one weakening mutation and expected detection test |
| Medium | Create AI-chat response contract | Prompt and response JSON Schema | Agents distinguish proof, test, proposal, limitation, and local policy detail |
| Medium | Create adversarial prompt corpus | Markdown and JSON corpus | Agents refuse to convert wealth, telemetry, identity, or integration status into essential-service eligibility |
| Medium | Add policy-version non-regression model | TLA+ extension and conformance cases | Core invariants remain required across policy versions |
| Medium | Define offline continuity semantics | TLA+ actions and Rust test cases | Offline requests, appeals, corrections, and revocations remain retained |
| Low | Generate documentation graph | Markdown dependency map | Every research object identifies upstream assumptions and downstream artifacts |
| Low | Create release-readiness checklist | Markdown checklist | Specified, tested, model-checked, reviewed, and deployment-ready remain distinct |

## Acceptance Rules

A task is complete only when:

- the artifact has a repository-relative path
- the artifact contains no source citation markers
- all referenced repository paths are present in the task map
- the artifact distinguishes assumptions from verified results
- sensitive data is not required for examples or tests
- essential-service access remains independent from optional telemetry, wealth, device ownership, connectivity, and integration state
- output includes accessibility, correction, appeal, and review requirements where relevant
- generated test data is explicitly synthetic
- implementation claims are limited to the evidence present in the repository

## Suggested AI-Chat Prompts

- Generate a TLA+ action for consent revocation that preserves correction and appeal records.
- Produce a Rust test loader for cross-layer rights-decision fixtures.
- Convert the rights invariants into a Rego adversarial regression suite.
- Generate a JSON Schema validation test matrix for local policy profiles.
- Produce a policy mutation catalog for wealth dependency, ranking, consent laundering, rest-based demotion, and accessibility-path removal.
- Create Research Object Cards for Recognition at Rest, Essential Service Independence, Consent Revocation Integrity, and Review Progress.
- Compare Rust and Rego output vocabularies and report only semantic mismatches.
- Generate accessible decision explanations from a stable reason-code vocabulary without collecting additional personal data.
- Create a documentation traceability matrix from each invariant to specification, implementation, tests, audit requirements, and profile conformance.
