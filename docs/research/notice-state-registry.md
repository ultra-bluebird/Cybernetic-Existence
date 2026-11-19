# Notice and State Version Registry

Registry format version: 1
Recorded date: 2026-10-13

## Evidence boundary

Entries below reflect code supplied in the conversation.
Repository source files, Git history, and compilation have not been inspected.

"Recorded date" is the registry-entry date.
"Last source change" must come from a separate source review.
Do not substitute the recorded date for an unverified source-change date.

## Shared registrations

| Schema | Kind | Version | Source | Last source change | Evidence |
|---|---|---|---|---|---|
| common-result | Notice/result | 1 | kotlin/common/ResultState.kt | Not established | Declared in conversation |
| common-result-state | State vocabulary | 1 | kotlin/common/ResultState.kt | Not established | Declared in conversation |

## Domain registrations

Domain schemas are not automatically registered by inheriting CommonResult.
Every domain payload transported or persisted needs its own reviewed entry.

A registration records:
- schema name;
- schema kind;
- version;
- source path;
- recorded date;
- last source-change date, when established;
- evidence basis;
- compatibility or migration decision;
- affected consumers;
- relevant test references.

Earlier domain snippets have not been silently assigned registrations here.

## Version-change protocol

Before approving a schema change:

1. Identify affected payload fields and state meanings.
2. Preserve the prior version definition and compatibility tests.
3. Classify the change as:
   - compatible representation change;
   - incompatible representation change;
   - state-meaning change;
   - migration-only change.
4. Update the owning source version.
5. Update this registry and the Kotlin registry.
6. Identify every affected importer, serializer, and consumer.
7. Provide an explicit adapter or reject unsupported versions.
8. Test old, new, malformed, and unknown versions.
9. Review privacy, accessibility, consent, and authority implications.
10. Record the source-review evidence and review outcome.

A passing registry check does not authorize deployment or external action.

## State semantics

The six common ResultState meanings remain fixed.
Domain phases belong in separate domain enums.

Adding, removing, or changing a common state's meaning requires a state
vocabulary version review. Do not reinterpret an existing value silently.

## Import behavior

Known schema/version:
Validate through the matching payload contract.

Unknown schema/version:
Return NOT_ESTABLISHED and preserve ordinary accessible service.

Malformed schema/version:
Return INVALID_INPUT.

Do not automatically reinterpret old state labels or discard unknown fields.

## Source parity

Report separately:
- matching source observations;
- missing observations;
- conflicting or duplicate observations;
- observations without registry entries.

Count only records supported by the declared source-review process.
The runtime registry is not a source scanner.

## Integration status

Existing CommonResult.schemaVersion remains the previously supplied literal.
No earlier file is modified by this artifact.

A separately reviewed integration change can replace that literal with
NoticeStateRegistry.COMMON_RESULT_VERSION and add parity tests.

## Privacy

Registry records contain schema metadata, not participant identities.
Do not place profile content, drafts, protected terminology values,
private-system inventories, or credentials in registry entries.
