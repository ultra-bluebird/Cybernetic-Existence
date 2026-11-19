# Red-Team Finding Traceability

Matrix version: 1
Scope: supplied completion implementations and their scaffolding.
Verification: Kotlin compilation and integration tests not executed here.

This is a scoped baseline, not an exhaustive closure of every red-team statement.

## Dispositions

A = ADDRESSED in supplied code or contract.
D = DEFERRED pending implementation or verification.
L = ACCEPTED_AS_LIMITATION of the explicitly stated component boundary.

A does not mean compiled, tested, independently verified, or deployment-approved.

## Finding groups

- Evidence: declarations separated from independently verified facts.
- Bounds: public data structures and processing inputs have declared limits.
- Diagnostics: content-bearing diagnostic representation is redacted.
- Authority: findings are not credentials, commands, or external-action grants.
- Lifecycle: restart, retention, copies, and durable protection boundaries.
- Accessibility: actual platform/assistive-technology task completion.

The matrix is transposed for readability: each row is a topic and each
column is a red-team finding group.

| Topic | Evidence | Bounds | Diagnostics | Authority | Lifecycle | Accessibility |
|---|---|---|---|---|---|---|
| Research trace | A | A | A | A | D | D |
| Gaze alternatives | A | A | A | A | D | D |
| Local processing boundary | A | A | A | A | D | D |
| Wayfinding minimization | A | A | A | A | D | D |
| Profile portability | A | A | A | A | D | D |
| Terminology continuity | A | A | A | A | D | D |
| Interface continuity preferences | A | A | A | A | D | D |
| Companion discretion | A | A | A | A | D | D |
| Non-interference | A | A | A | A | D | D |
| Research adapter | A | A | A | A | D | D |
| Material-change review | A | A | A | A | D | D |
| Continuity envelope | A | A | A | A | D | D |
| Age-neutral pacing | A | A | A | A | D | D |
| Emergency access | A | A | A | A | D | D |
| Runtime negotiation | A | A | A | A | D | D |
| Spatial portability | A | A | A | A | D | D |
| Offline continuity | A | A | A | A | D | D |
| Tracking degradation | A | A | A | A | D | D |
| Repair configuration | A | A | A | A | D | D |
| Energy per task | A | A | A | A | D | D |
| Adaptive sampling | A | A | A | A | D | D |
| Device thermal policy | A | A | A | A | D | D |
| Environmental presentation | A | A | A | A | D | D |
| Social-duty acceptance audit | A | A | A | A | D | D |

## Interpretation and evidence scope

The A cells refer to the supplied design mechanisms, including:
- shared ResultState and CommonResult;
- declared/reported evidence terminology;
- common Bounds and domain constraints;
- RedactedContent and diagnostic review conventions;
- fixed false external-action fields and non-executing interfaces.

These shared mitigations must still be integrated into each owning module.
A shared utility existing in the conversation does not prove every call site
uses it correctly.

The D lifecycle cells include topic-specific work:
- store retention, processing copies, and backup inspection;
- persistent review bindings;
- atomic baseline comparison and installation;
- process restart and latch recovery;
- cache eviction and recovery;
- adapter stop/placement acknowledgment;
- trusted date context;
- policy invalidation after material changes.

The D accessibility cells require integrated, representative testing.
Text output or an interface contract is not an implemented screen-reader,
switch, braille, speech, or non-digital service pathway.

## Accepted component limitations

| Finding | Disposition | Boundary and consequence |
|---|---|---|
| Hostile code within the same JVM | L | These leaf modules are not process-isolation or reflection-security mechanisms. Deployment isolation remains required. |
| Copies outside component ownership | L | Local clearing cannot erase caller, renderer, OS, backup, or screenshot copies. Copy governance remains a deployment obligation. |
| Arbitrary prose classification | L | Typed classifications and explicit review records do not independently determine prompt meaning. |
| Evidence authenticity | L | References and declared reviewer status are not authenticated by these validators. Trust resolution is separate. |
| Physical truth from signed receipts | L | A signature binds bytes to a key; it does not by itself verify sensor or actuator behavior. |
| Universal privacy or accessibility certification | L | No such certification is produced. |
| Actual hardware/network enforcement | L | Local validators do not replace operating-system controls or commissioned equipment safeguards. |

An L entry is not a system-wide waiver. It states where another accountable
component must supply the missing protection.

## Specific unresolved findings

| Finding | Disposition | Required next action |
|---|---|---|
| Original capture restart can clear opt-out | D | Patch the owning controller and test scope-bound, reviewed reconsideration; no silent restart clearing. |
| Indicator failure recovery | D | Add and test a separate fault latch with reviewed recovery. |
| Repeated stop receipt invalidation | D | Make the owning stop path idempotent and test repeated requests. |
| Durable latch survival | D | Implement and test an actual persistence/restart protocol. |
| Untracked map copies | D | Define bounded copy/lease inventory and test retention across consumers. |
| Adapter report versus physical shutdown | D | Add a separately reviewed verification path and retain distinct evidence states. |
| Actual AT support | D | Test supported configurations on the actual platform. |
| Hidden SDK/diagnostic collection | D | Inspect dependencies and platform diagnostic behavior. |
| Domain schema registration | D | Register transported/persisted schemas and vocabulary versions. |
| Kotlin compilation | D | Compile exact assembled files and record results, including integration corrections. |
| Production artifact exclusion of test fixtures | D | Inspect the build and packaged artifact. |

## Update protocol

Every disposition record contains:
- topic;
- finding;
- disposition;
- rationale;
- implementation/evidence reference;
- test or review reference where applicable;
- verification state;
- next action or accepted boundary.

Never delete an unresolved finding merely because a successor document exists.
Retain prior disposition history and record the new assessment separately.

## Privacy

Use descriptive topics and system findings.
Do not include participant identities, private profiles, companion inventories,
raw scene data, or sensitive test payloads.
