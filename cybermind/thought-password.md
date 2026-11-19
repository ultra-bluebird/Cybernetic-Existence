# Thought-Password: Activation, Privacy, and Participant Control

## Status

This document defines the proposed CyberMind thought-password workflow and the
boundaries of `cybermind/thought-password.lua`.

It is a research and engineering specification. It does not establish clinical
safety, identity, consciousness, legal consent, or authority over a person or
their integrations.

A thought-password is an activation mechanism. It is not permission to read,
publish, retain, or act upon private expression.

## Sovereign Attribution

bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Scope: document credit and configured workstream metadata only.

Attribution does not establish biological binding, verified identity, consent,
capability authorization, execution evidence, or authority over another person
or system. It must not become an operational participant-tracking field.

## Core Principle

Accepting an activation assertion opens only the specifically authorized next
step.

It does not open unrestricted access to private thoughts, integration details,
communication, research data, or external actions.

## Workflow Boundaries

| Boundary | Required condition | Does not authorize |
|---|---|---|
| Acquisition | Separately authorized measurement scope | General-purpose monitoring |
| Activation | Fresh, context-bound assertion accepted by the trusted verifier | Publication or message sending |
| Private decoding | Current inference permission | Treating a candidate as intended expression |
| Private preview | Authorized private presentation | Approval by implication |
| Expression approval | Participant-controlled approval of current content and audience | Execution of an action described by the content |
| External action | Separate authorization bound to the exact action | Broader access or future actions |
| Secondary use | Independent purpose-specific permission | Unlimited research or training reuse |

Silence, timeout, decoder confidence, or failure to cancel must not count as
expression approval.

## Module Structure

The Lua module acts as a bounded activation broker.

It accepts an opaque assertion from an authorized specialist component. It does
not acquire neural signals, store an imagined phrase, or perform neural decoding.

Its state sequence is:

`idle → challenge_pending → activation_accepted → idle`

Cancellation and expiry invalidate the current activation workflow.

Closure prevents further use of that workflow instance.

## Required Adapters

| Adapter | Contract |
|---|---|
| `clock_ms()` | Supply integer milliseconds from one monotonic clock domain |
| `issue_challenge(binding)` | Generate a fresh, unpredictable challenge |
| `check_policy(binding)` | Return the current policy verdict and revision |
| `verify_assertion(challenge, proof, binding)` | Validate the specialist assertion against the challenge and scope |
| `claim_once(challenge, binding)` | Atomically accept the challenge at most once across the applicable deployment |

Adapter availability is not proof of adapter correctness.

The trusted host must protect adapter configuration and bind operations to the
actual current policy.

## Public Module Operations

| Operation | Purpose |
|---|---|
| `begin()` | Start a fresh, narrowly scoped challenge |
| `submit(proof)` | Evaluate an opaque activation assertion |
| `consume_activation()` | Consume one accepted activation result |
| `cancel()` | Clear the current workflow without granting activation |
| `status()` | Return minimal state without the challenge or proof |
| `close()` | Release local workflow state and prevent further use |

The returned activation result is not a portable bearer credential.

The host must not treat a copied result table as fresh authority.

## Required Invariants

1. No activation without a currently satisfied policy gate.
2. No acceptance of an assertion for a different challenge or scope.
3. No activation from an expired workflow.
4. No reuse of a consumed challenge.
5. No second local consumption of an accepted activation.
6. No publication directly from activation.
7. No automatic modality change after rejection, expiry, or cancellation.
8. No use of attribution as identity or authorization.
9. No compulsory disclosure of an imagined phrase or neural recording.
10. No claim that an accepted assertion proves voluntary expression.

## Participant Control

The participant must have an accessible way to pause, cancel, correct, or decline.

Ordinary participation must not require demonstration of a thought-password or
disclosure of private integration details.

A failed activation is a workflow result. It must not be interpreted as evidence
of incompetence, deception, absence of integration, or unwillingness to
communicate.

Attempt limits apply to the activation workflow. They must not silently become
a blanket withdrawal of unrelated essential support.

Any proposed change that disables or materially degrades a participant-declared
essential capability requires the separate preservation and authority review.

## Security Requirements

- Do not generate production challenges with `math.random`.
- Do not derive challenges from names, timestamps, attribution, or message text.
- Do not log plaintext assertions or imagined phrases.
- Reject malformed or unexpected adapter responses.
- Invalidate local activation after clock reversal.
- Recheck policy before consuming activation.
- Protect replay state against concurrent acceptance.
- Define restart, revocation, and lost-response behavior.
- Use the project-approved SHA-256 implementation where commitments or verifiers
  require hashing; do not introduce a custom substitute.

Authentication, activation, and consent remain distinct.

## Privacy and Retention

The activation broker must not retain:

- Raw neural recordings.
- Inner-speech transcripts.
- Private integration inventories.
- Biometric templates.
- Unnecessary identity information.

Operational records, if necessary, must have a declared purpose, restricted
access, retention endpoint, and deletion process.

Clearing a Lua reference is logical state removal, not a guarantee of secure
physical memory erasure.

## Expression and Evidence

Maintain separate records for:

- Decoder candidates.
- Privately previewed content.
- Participant-approved expression.
- Released communication.
- Research annotations.

A candidate must not be described as a confession, admission, or authorized
statement merely because decoding occurred.

Approval for ordinary communication is not blanket permission for research,
training, publication, or legal reuse.

Legal admissibility and compelled disclosure require separate
jurisdiction-specific analysis.

## Validation

The supplied implementation includes synthetic self-tests. Their inclusion is
not evidence that they were executed.

Deployment testing must cover:

- False activation and false rejection.
- Expiry during verification.
- Replay across workers and restarts.
- Policy changes before consumption.
- Adapter failure and malformed responses.
- Cancellation and accessible retry.
- Lost responses after challenge consumption.
- Unintended disclosure.
- Confirmation burden and participant-reported control.

No deployment, clinical validation, or external-system access is asserted by
this document.

## Next Verification Step

Define the specialist assertion contract:

What has the verifier established, for which operation, under which conditions,
and with what limitations?

Then connect accepted activation only to the authorized private-processing
workflow. Keep message release and external actions independently controlled.
