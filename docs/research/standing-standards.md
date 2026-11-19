# Standing Implementation Standards

Checklist version: 1

## Delivery requirements

- Kotlin primary; PowerShell, Lua, and Java permitted.
- Complete artifacts directly in the response.
- No file-generation tools.
- Required repository, filename, and destination declarations.
- Descriptive filenames without numbered topic identifiers.
- Target only mk-bluebird/Augmented-Hub and mk-bluebird/Skynet.
- Explicit dependencies, source roots, and compile/run instructions.

## Shared contracts

- Use the shared ResultState vocabulary.
- Domain phases do not redefine common result meanings.
- Use CommonResult or an explicitly registered compatible result contract.
- Apply common bounds plus documented domain constraints.
- Maintain schema/vocabulary registry entries for transported or persisted data.
- Unknown versions do not silently migrate.

## Evidence

- Label declarations, reports, observations, and measurements distinctly.
- Do not promote reference presence to authenticity.
- Do not promote synthetic replay to empirical reproduction.
- Preserve conflicts and adverse evidence.
- Missing evidence remains NOT_ESTABLISHED.
- State what was executed and what was only supplied.

## Time

- Inject MonotonicClock for local elapsed-time behavior.
- Use the guarded clock for contract checks.
- Do not accept wall-clock timestamps as elapsed time.
- Keep persisted/cross-device expiry in a separately reviewed time contract.
- Unknown timing preserves protective defaults and accessible recovery.

## Mutable state and lifecycle

- Enforce serialization using synchronization, an actor, or another reviewed mechanism.
- Do not rely on a threading comment alone.
- Protective latches do not clear through ordinary transitions.
- Repeated stop requests must not invalidate outstanding stop evidence.
- Durable restart claims require actual persistent-state tests.
- Define close/dispose behavior and post-close results.
- Do not claim system-wide erasure from owned-buffer clearing.

## Privacy and diagnostics

- Content-bearing types use enforced redacted diagnostics or reviewed equivalents.
- Do not log drafts, prompts, transcripts, private profiles, or raw scenes.
- Separate display text from audit output.
- Do not normalize protected terminology to satisfy structural validation.
- Minimize before collection where feasible.
- Review SDK, IPC, diagnostics, accessibility-cache, and renderer paths.
- Do not require private-system disclosure for ordinary assistance.

## Authority

- Findings are not credentials.
- Review declarations are not authenticated permissions.
- No automatic external action.
- A module with no actuation interface does not certify the whole deployment.
- Actual executors enforce their own exact current scope.
- Emergency access does not depend on privacy-audit completion.
- No person ranking, identity verification, diagnosis, or public CyberRank status.

## Accessibility

- Preserve essential task outcomes outside spatial rendering.
- Provide actual platform controls, not only text describing controls.
- Retain cancellation, correction, assistance, and paced recovery.
- Do not infer age, competence, fatigue, or disability from interaction.
- Test declared assistive-technology combinations.
- Do not remove human or non-digital services based on declared coverage.

## Tests

- Negative, boundary, stale/error, conflict, and duplicate cases.
- Latch and restart cases where state exists.
- Adapter success, failure, silence, and stale receipts.
- Typed public failures; unexpected exceptions are test failures.
- Explicit non-applicable rationale for unused categories.
- Synthetic labels and no fixture-to-policy promotion.
- No live emergency or equipment tests without a separate authorized procedure.

## Completion levels

Delivery complete:
Artifacts and limitations supplied.

Local validation complete:
Exact assembled source compiled and declared tests executed.

Integration qualified:
Platform, adapter, storage, accessibility, and trust boundaries evaluated.

Deployment approved:
A separate accountable process approves the specific deployment.

Never substitute one level for another.

## Metrics

Report privacy, accessibility, rights, and ecological measurements with their
method and scope. Editorial estimates remain labeled as such.

A high score cannot compensate for a failed protected requirement.
