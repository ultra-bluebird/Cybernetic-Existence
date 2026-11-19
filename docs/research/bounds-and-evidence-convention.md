# Bounds and Evidence Convention

Version: 1

## Default bounds

- Text: 4096 UTF-16 code units per String or CharArray.
- Collections: 256 elements or map entries.
- Byte arrays: 16 MiB per array.
- Nesting: root depth zero; maximum depth eight.
- Aggregate traversal: 4096 visited nodes.
- Aggregate text: 65536 UTF-16 code units.
- Aggregate encoded text plus byte arrays: 16 MiB.

These are input-profile limits, not total memory or CPU guarantees.

## Validation placement

Validate before allocation-heavy operations, copying, encoding, sorting,
or recursive traversal.

Network readers, parsers, decompressors, and storage adapters must impose
their own preallocation and expansion limits. Validation of an already
allocated payload cannot undo upstream resource consumption.

Use ordinary stable local containers. Do not mutate during validation.
Unknown custom model types require an explicit validation projection.

Do not truncate protected terminology or silently drop required fields
to make a payload fit.

## Exceptions

A larger bound requires a reviewed profile stating:
- task purpose;
- affected data classes;
- size and duration limits;
- aggregate resource budget;
- error and accessible fallback behavior;
- review status and version;
- tests for the proposed limits.

Increasing a constant alone is not a reviewed exception.

## Unicode

Text limits count UTF-16 code units, not visible characters.
UTF-8 content length is counted separately.
Malformed surrogate sequences are rejected.
Valid writing-system characters are not normalized or stripped.

Rendering, bidirectional text, structural-key validation, and escaping
remain distinct concerns.

## Evidence fields

Stored Boolean claims require an explicit evidence marker.
Declaration Boolean names end in Declared.
Declaration ratio names start with declared.
Reported ratio names start with reported.
Measurement names start with measured.
Observation names start with observed.
Independent-verification names start with verified.

A marker does not authenticate evidence or run a verification procedure.

Policy constants and computed authorization getters are not review claims.
Their invariants require separate source and behavioral tests.

## Diagnostic handling

Bounds and naming findings must not echo payload values.
Content-bearing results use the common redaction foundation.

## Remaining enforcement

Metadata review does not inspect getters, serialization, external services,
or hidden data flows. Batch review must cover those boundaries explicitly.
