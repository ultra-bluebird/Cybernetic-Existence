# Cross-Module Vocabulary Consistency

Checklist version: 1

## Shared vocabulary

Review uses of:
- ResultState;
- CommonResult;
- MonotonicClock;
- GuardedMonotonicClock;
- TimeMark;
- RedactedContent;
- Bounds;
- evidence-basis markers;
- registered schema and vocabulary versions.

## Required review

- Shared symbols use the shared package.
- Common result states retain their established meanings.
- Domain phases are separate from common result states.
- "Declared" does not become "verified" through a rename.
- "Reported" output is not described as independently measured.
- A passing Notice is not used as a credential.
- A time mark is not persisted or reused across guards.
- A schema version is distinguished from a vocabulary version.
- Protected terminology is not normalized or paraphrased.
- Numeric units and clock bases remain explicit.
- Similar enum labels are not assumed semantically equivalent.
- Unknown and conflicting records remain distinct from failures.
- CLOSED refers to component/session lifecycle, not physical shutdown proof.

## Automated support

BatchCoordination.reviewVocabulary compares submitted symbol references.
It does not inspect source code or determine semantic equivalence.

## Findings

Record:
- qualified symbol;
- owning contract;
- conflicting usage;
- proposed correction;
- affected consumers;
- review state.

Do not silently resolve collisions by changing one field name.
Review the underlying meaning and migration impact.
