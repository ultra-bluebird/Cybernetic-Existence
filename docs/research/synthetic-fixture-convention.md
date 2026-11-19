# Synthetic Fixture Convention

Version: 1

## Naming

Test labels, references, scenario names, and test contexts start with synthetic-.

Use lowercase ASCII words separated by hyphens.
Maximum fixture-label length: 128 characters.

Do not apply this rule to source-code symbol names or protected user vocabulary.

## Numeric values

Each numeric threshold fixture states:
- synthetic label;
- value and unit;
- test purpose;
- expected result;
- explanation;
- non-deployment status.

Synthetic values are never policy defaults merely because a test passed.

NaN and infinity are permitted only in explicitly negative fixtures.

## Encodings and exact text

Cryptographic encodings retain their required syntax.
Bind them to a synthetic fixture label in the test description.

Protected terminology and localization examples retain their exact spelling.
Label the surrounding scenario instead of editing the content.

## Source isolation

SyntheticFixtures.kt belongs in test sources only.
Production packaging must exclude it.

Annotations and wrappers do not independently enforce build separation.
Review production dependency graphs and packaged artifacts.

## Evidence

A synthetic test result establishes behavior for the tested fixture.
It does not establish measured field performance, accessibility conformance,
legal compliance, source truth, privacy guarantees, or device safety.

## Review

Audit submitted fixture labels and numeric-fixture metadata.
Source-wide scans and production-default promotion checks remain separate
build/review tasks.
